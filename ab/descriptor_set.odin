package ab

import "core:fmt"

import vk "shared:odin-vulkan"




alloc_descriptor_sets :: proc(
	descriptor_pool :vk.VkDescriptorPool,
	descriptor_set_layout: vk.VkDescriptorSetLayout,
	count :u32,
) -> []vk.VkDescriptorSet {

	layouts := make([]vk.VkDescriptorSetLayout, count);
	defer delete(layouts);

	for idx in 0..<count {
		layouts[idx] = descriptor_set_layout;
	}

	descriptor_set_alloc_info := vk.VkDescriptorSetAllocateInfo {};
	descriptor_set_alloc_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
	// descriptor_set_alloc_info.pNext = ;//: rawptr,
	descriptor_set_alloc_info.descriptorPool = descriptor_pool;//: VkDescriptorPool,
	descriptor_set_alloc_info.descriptorSetCount = count;//: u32,
	descriptor_set_alloc_info.pSetLayouts = &layouts[0];//: ^VkDescriptorSetLayout,

	descriptor_sets := make([]vk.VkDescriptorSet, count);

	ctx := get_context();
	vk.CHECK(vk.vkAllocateDescriptorSets(ctx.device, &descriptor_set_alloc_info, &descriptor_sets[0]));

	return descriptor_sets;
}



create_viewport_descriptor_set_layout :: proc(binding: u32) -> vk.VkDescriptorSetLayout {

	layout_binding := vk.VkDescriptorSetLayoutBinding {};
	layout_binding.binding = binding;
	layout_binding.descriptorType = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
	layout_binding.descriptorCount = 1;//: u32,
	layout_binding.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT;//: VkShaderStageFlags,
	layout_binding.pImmutableSamplers = nil;//: ^VkSampler,

	layout_bindings := []vk.VkDescriptorSetLayoutBinding {
		layout_binding,
	};

	layout_create_info := vk.VkDescriptorSetLayoutCreateInfo {};
	layout_create_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
	// layout_create_info.pNext = //: rawptr,
	// layout_create_info.flags = //: VkDescriptorSetLayoutCreateFlags,
	layout_create_info.bindingCount = u32(len(layout_bindings));
	layout_create_info.pBindings = raw_data(layout_bindings);//: ^VkDescriptorSetLayoutBinding,

	descriptor_set_layout :vk.VkDescriptorSetLayout = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreateDescriptorSetLayout(ctx.device, &layout_create_info, nil, &descriptor_set_layout));
	return descriptor_set_layout;
}


create_font_descriptor_set_layout :: proc(binding: u32) -> vk.VkDescriptorSetLayout {

	layout_binding := vk.VkDescriptorSetLayoutBinding {};
	layout_binding.binding = binding;
	layout_binding.descriptorType = .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
	layout_binding.descriptorCount = 1;//: u32,
	layout_binding.stageFlags = .VK_SHADER_STAGE_FRAGMENT_BIT;//: VkShaderStageFlags,
	layout_binding.pImmutableSamplers = nil;//: ^VkSampler,

	layout_bindings := []vk.VkDescriptorSetLayoutBinding {
		layout_binding,
	};

	layout_create_info := vk.VkDescriptorSetLayoutCreateInfo {};
	layout_create_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
	// layout_create_info.pNext = //: rawptr,
	// layout_create_info.flags = //: VkDescriptorSetLayoutCreateFlags,
	layout_create_info.bindingCount = u32(len(layout_bindings));
	layout_create_info.pBindings = raw_data(layout_bindings);//: ^VkDescriptorSetLayoutBinding,

	descriptor_set_layout :vk.VkDescriptorSetLayout = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreateDescriptorSetLayout(ctx.device, &layout_create_info, nil, &descriptor_set_layout));
	return descriptor_set_layout;
}


create_mvp_descriptor_set_layout :: proc() -> vk.VkDescriptorSetLayout {

	layout_binding := vk.VkDescriptorSetLayoutBinding {};
	layout_binding.binding = 0;
	layout_binding.descriptorType = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
	layout_binding.descriptorCount = 1;//: u32,
	layout_binding.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT;//: VkShaderStageFlags,
	layout_binding.pImmutableSamplers = nil;//: ^VkSampler,

	layout_binding_img := vk.VkDescriptorSetLayoutBinding {};
	layout_binding_img.binding = 1;
	layout_binding_img.descriptorType = .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
	layout_binding_img.descriptorCount = 1;//: u32,
	layout_binding_img.stageFlags = .VK_SHADER_STAGE_FRAGMENT_BIT;//: VkShaderStageFlags,
	layout_binding_img.pImmutableSamplers = nil;//: ^VkSampler,

	layout_bindings := []vk.VkDescriptorSetLayoutBinding {
		layout_binding,
		layout_binding_img,
	};


	layout_create_info := vk.VkDescriptorSetLayoutCreateInfo {};
	layout_create_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
	// layout_create_info.pNext = //: rawptr,
	// layout_create_info.flags = //: VkDescriptorSetLayoutCreateFlags,
	layout_create_info.bindingCount = u32(len(layout_bindings));
	layout_create_info.pBindings = raw_data(layout_bindings);//: ^VkDescriptorSetLayoutBinding,

	descriptor_set_layout :vk.VkDescriptorSetLayout = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreateDescriptorSetLayout(ctx.device, &layout_create_info, nil, &descriptor_set_layout));
	return descriptor_set_layout;
}


update_binding :: proc {
	update_binding_buffer, update_binding_img
};

update_binding_buffer :: proc (
	descriptor_set :vk.VkDescriptorSet,
	binding        :u32,
	buffer         :^Buffer,
) {

	descriptor_buffer_info := vk.VkDescriptorBufferInfo {};
	descriptor_buffer_info.buffer = buffer.handle;
	descriptor_buffer_info.offset = 0;
	descriptor_buffer_info.range = buffer.size;

	descriptor_write := vk.VkWriteDescriptorSet {};
	descriptor_write.sType = .VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
	descriptor_write.dstSet = descriptor_set;
	descriptor_write.dstBinding = binding;
	descriptor_write.dstArrayElement = 0;
	descriptor_write.descriptorCount = 1;
	descriptor_write.descriptorType = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
	descriptor_write.pBufferInfo = &descriptor_buffer_info;

	ctx := get_context();
	vk.vkUpdateDescriptorSets(ctx.device, 1, &descriptor_write, 0, nil);
}


update_binding_img :: proc (
	descriptor_set :vk.VkDescriptorSet,
	binding        :u32,
	sampler        :vk.VkSampler,
	image_view     :vk.VkImageView,
	image_layout   :vk.VkImageLayout,
) {

	descriptor_image_info := vk.VkDescriptorImageInfo {};
	descriptor_image_info.sampler = sampler;//: VkSampler,
	descriptor_image_info.imageView = image_view;//: VkImageView,
	descriptor_image_info.imageLayout = image_layout;//: VkImageLayout,

	descriptor_write := vk.VkWriteDescriptorSet {};
	descriptor_write.sType = .VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
	descriptor_write.dstSet = descriptor_set;
	descriptor_write.dstBinding = binding;
	descriptor_write.dstArrayElement = 0;
	descriptor_write.descriptorCount = 1;
	descriptor_write.descriptorType = .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
	descriptor_write.pImageInfo = &descriptor_image_info;

	ctx := get_context();
	vk.vkUpdateDescriptorSets(ctx.device, 1, &descriptor_write, 0, nil);
}


viewport_descriptor_layout: vk.VkDescriptorSetLayout;
font_descriptor_layout :vk.VkDescriptorSetLayout;
descriptor_pool: vk.VkDescriptorPool;
pipeline_cache: vk.VkPipelineCache;
graphics_command_pool: vk.VkCommandPool;

init_generic_descriptor_set_layouts :: proc() {
	viewport_descriptor_layout = create_viewport_descriptor_set_layout(binding=0);
	font_descriptor_layout = create_font_descriptor_set_layout(binding=0);



	descriptor_pool_size := vk.VkDescriptorPoolSize {};
	descriptor_pool_size.type = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
	descriptor_pool_size.descriptorCount = 100;

	descriptor_pool_size2 := vk.VkDescriptorPoolSize {};
	descriptor_pool_size2.type = .VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
	descriptor_pool_size2.descriptorCount = 100;

	descriptor_pool_sizes := []vk.VkDescriptorPoolSize {
		descriptor_pool_size,
		descriptor_pool_size2,
	};

	descriptor_pool_info := vk.VkDescriptorPoolCreateInfo {};
	descriptor_pool_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
	// descriptor_pool_info.pNext = //: rawptr,
	// descriptor_pool_info.flags = //: VkDescriptorPoolCreateFlags,
	descriptor_pool_info.maxSets = 100;
	descriptor_pool_info.poolSizeCount = u32(len(descriptor_pool_sizes));
	descriptor_pool_info.pPoolSizes = &descriptor_pool_sizes[0];

	ctx := get_context();
	vk.CHECK(vk.vkCreateDescriptorPool(ctx.device, &descriptor_pool_info, nil, &descriptor_pool));


	pipeline_cache_info := vk.VkPipelineCacheCreateInfo {};
	pipeline_cache_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO;
	pipeline_cache_info.initialDataSize = 0;
	pipeline_cache_info.pInitialData = nil;

	vk.CHECK(vk.vkCreatePipelineCache(ctx.device, &pipeline_cache_info, nil, &pipeline_cache));


	graphics_command_pool_info := vk.VkCommandPoolCreateInfo {};
	graphics_command_pool_info.sType = .VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
	graphics_command_pool_info.queueFamilyIndex = ctx.graphics_queue_family_idx;
	graphics_command_pool_info.flags = .VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;

	vk.vkCreateCommandPool(ctx.device, &graphics_command_pool_info, nil, &graphics_command_pool);
}

