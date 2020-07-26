package ab

import "core:os" // to read shader files
import vk "shared:odin-vulkan"



Mesh_Info :: struct {
	vertex_buffer :^Buffer,
	index_buffer :^Buffer,
	index_count :u32,
};

Mesh_Draw_Info :: struct {
	pipeline       :Pipeline,
	mesh           :^Mesh_Info,
	descriptor_set :vk.VkDescriptorSet,
};

Pipeline :: struct {
	pipeline :vk.VkPipeline,
	layout   :vk.VkPipelineLayout,
};


create_shader :: proc(path: string) -> vk.VkShaderModule {
	shader_spv, success := os.read_entire_file(path);
	assert(success);

	shader_create_info := vk.VkShaderModuleCreateInfo {};
	shader_create_info.sType = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
	shader_create_info.codeSize = u64(len(shader_spv));
	shader_create_info.pCode = (^u32) (&shader_spv[0]);

	shader_module :vk.VkShaderModule = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreateShaderModule(ctx.device, &shader_create_info, nil, &shader_module));

	return shader_module;
}

create_shader_stages :: proc( vertex_shader_path , fragment_shader_path:string ) -> [2]vk.VkPipelineShaderStageCreateInfo {

	vertex_shader_module := create_shader(vertex_shader_path);
	fragment_shader_module := create_shader(fragment_shader_path);


	vertex_stage_info := vk.VkPipelineShaderStageCreateInfo {};
	vertex_stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
	vertex_stage_info.stage = .VK_SHADER_STAGE_VERTEX_BIT;
	vertex_stage_info.module = vertex_shader_module;
	vertex_stage_info.pName = cstring("main");

	fragment_stage_info := vk.VkPipelineShaderStageCreateInfo {};
	fragment_stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
	fragment_stage_info.stage = .VK_SHADER_STAGE_FRAGMENT_BIT;
	fragment_stage_info.module = fragment_shader_module;
	fragment_stage_info.pName = cstring("main");

	shader_stages := [2]vk.VkPipelineShaderStageCreateInfo{ vertex_stage_info, fragment_stage_info };
	return shader_stages;
}

PipelineBlendState :: struct {
	color_blend_info :vk.VkPipelineColorBlendStateCreateInfo,
	color_blend_attachment :vk.VkPipelineColorBlendAttachmentState,
}


opaque_blend_info :: proc(blend_state :^PipelineBlendState) {
	color_blend_attachment := &blend_state.color_blend_attachment;
	color_blend_attachment^ = {}; // zero out everything
	color_blend_attachment.blendEnable = false;

	color_blend_attachment.colorWriteMask = (
		.VK_COLOR_COMPONENT_R_BIT |
		.VK_COLOR_COMPONENT_G_BIT |
		.VK_COLOR_COMPONENT_B_BIT |
		.VK_COLOR_COMPONENT_A_BIT
	);

	color_blend_info := &blend_state.color_blend_info;
	color_blend_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
	color_blend_info.logicOpEnable = false;
	// VkLogicOp                logicOp;
	color_blend_info.attachmentCount = 1;
	color_blend_info.pAttachments = color_blend_attachment;
	// float                    blendConstants [4];
	return;
}


mix_blend_info :: proc(blend_state :^PipelineBlendState) {


	color_blend_attachment := &blend_state.color_blend_attachment;
	color_blend_attachment.blendEnable = true;
	color_blend_attachment.srcColorBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA;
	color_blend_attachment.dstColorBlendFactor = .VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
	color_blend_attachment.colorBlendOp = .VK_BLEND_OP_ADD;
	color_blend_attachment.srcAlphaBlendFactor = .VK_BLEND_FACTOR_SRC_ALPHA;
	color_blend_attachment.dstAlphaBlendFactor = .VK_BLEND_FACTOR_DST_ALPHA;
	color_blend_attachment.alphaBlendOp = .VK_BLEND_OP_MAX;


	color_blend_attachment.colorWriteMask = (
		.VK_COLOR_COMPONENT_R_BIT |
		.VK_COLOR_COMPONENT_G_BIT |
		.VK_COLOR_COMPONENT_B_BIT |
		.VK_COLOR_COMPONENT_A_BIT
	);

	color_blend_info := &blend_state.color_blend_info;
	color_blend_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
	color_blend_info.logicOpEnable = false;
	// VkLogicOp                logicOp;
	color_blend_info.attachmentCount = 1;
	color_blend_info.pAttachments = color_blend_attachment;
	// float                    blendConstants [4];
	return;
}


create_graphic_pipeline :: proc(
	pipeline_cache :vk.VkPipelineCache,
	render_pass :vk.VkRenderPass,
	vertex_info :^vk.VkPipelineVertexInputStateCreateInfo,
	pipeline_layout :vk.VkPipelineLayout,
	shader_stages :[]vk.VkPipelineShaderStageCreateInfo,
	color_blend_info :^PipelineBlendState,
) -> vk.VkPipeline {

	assembly_info := vk.VkPipelineInputAssemblyStateCreateInfo {};
	assembly_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
	assembly_info.topology = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
	assembly_info.primitiveRestartEnable = false;

	rasterization_state := vk.VkPipelineRasterizationStateCreateInfo{};
	rasterization_state.sType = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
	rasterization_state.depthClampEnable = false;
	rasterization_state.rasterizerDiscardEnable = false;
	rasterization_state.polygonMode = .VK_POLYGON_MODE_FILL;
	rasterization_state.cullMode = .VK_CULL_MODE_BACK_BIT;
	rasterization_state.frontFace = .VK_FRONT_FACE_COUNTER_CLOCKWISE;
	rasterization_state.depthBiasEnable = false;
	rasterization_state.lineWidth = 1;


	viewport_state := vk.VkPipelineViewportStateCreateInfo {};
	viewport_state.sType = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
	viewport_state.viewportCount = 1;
	// viewport_state.pViewports = &viewport; // nil as it is dynamic state
	viewport_state.scissorCount = 1;
	// viewport_state.pScissors = &scissor;


	multisample_info := vk.VkPipelineMultisampleStateCreateInfo {};
	multisample_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
	multisample_info.rasterizationSamples = .VK_SAMPLE_COUNT_1_BIT;
	multisample_info.sampleShadingEnable = false;

	dynamic_states := []vk.VkDynamicState {
	    .VK_DYNAMIC_STATE_VIEWPORT,
	    .VK_DYNAMIC_STATE_SCISSOR,
	};

	dynamic_state_info := vk.VkPipelineDynamicStateCreateInfo {};
	dynamic_state_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
 	dynamic_state_info.dynamicStateCount = u32(len(dynamic_states));
	dynamic_state_info.pDynamicStates = &dynamic_states[0];

	graphics_pipeline_info := vk.VkGraphicsPipelineCreateInfo {};
	graphics_pipeline_info.sType = .VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
	graphics_pipeline_info.stageCount = u32(len(shader_stages));
	graphics_pipeline_info.pStages = &shader_stages[0];
	graphics_pipeline_info.pVertexInputState = vertex_info;
	graphics_pipeline_info.pInputAssemblyState = &assembly_info;
	// const  VkPipelineTessellationStateCreateInfo *  pTessellationState;
	graphics_pipeline_info.pViewportState = &viewport_state;
	graphics_pipeline_info.pRasterizationState = &rasterization_state;
	graphics_pipeline_info.pMultisampleState = &multisample_info;
	// graphics_pipeline_info.pDepthStencilState = &depth_stencil_state;
	graphics_pipeline_info.pColorBlendState = &color_blend_info.color_blend_info;
	graphics_pipeline_info.pDynamicState = &dynamic_state_info;
	graphics_pipeline_info.layout = pipeline_layout;
	graphics_pipeline_info.renderPass = render_pass;
	graphics_pipeline_info.subpass = 0;
	graphics_pipeline_info.basePipelineHandle = nil;
	graphics_pipeline_info.basePipelineIndex = -1;

	pipeline :vk.VkPipeline = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreateGraphicsPipelines(ctx.device, pipeline_cache, 1, &graphics_pipeline_info, nil, &pipeline));
	return pipeline;
}



create_pipeline_layout :: proc(
	descriptor_set_layouts: []vk.VkDescriptorSetLayout,
	push_constant_ranges: []vk.VkPushConstantRange,
) -> vk.VkPipelineLayout {

	pipeline_layout_info := vk.VkPipelineLayoutCreateInfo {};
	pipeline_layout_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
	pipeline_layout_info.setLayoutCount = u32(len(descriptor_set_layouts));
	pipeline_layout_info.pSetLayouts = raw_data(descriptor_set_layouts);
	pipeline_layout_info.pushConstantRangeCount = u32(len(push_constant_ranges));
	pipeline_layout_info.pPushConstantRanges = raw_data(push_constant_ranges);

	pipeline_layout :vk.VkPipelineLayout = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreatePipelineLayout(ctx.device, &pipeline_layout_info, nil, &pipeline_layout));
	return pipeline_layout;
}
