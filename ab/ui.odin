package ab
import "core:math/linalg"
import "core:os"
import vk "shared:odin-vulkan"
import "shared:odin-stb/stbtt"




Char_Substring :: struct {
	string_start: u32,
	string_size: u32,
	// start: linalg.Vector2,
};

Char_Draw_Data_GEN :: struct(max_char_count: u32, max_string_count: u32) {
	char_quads: [max_char_count]stbtt.Aligned_Quad,
	substrings: [max_string_count] Char_Substring,
	char_count: u32,
	substring_count: uint,
	buffer :Buffer,
	image: Image,
	pipeline: Pipeline,
	font_size: [2]int,
	font_descriptor: vk.VkDescriptorSet, // to keep texture
	font_first_idx: int,
	char_data: []stbtt.Baked_Char,
};

MAX_NUM_CHARS :: 16 * 1024; // I don't think I'll get over this soon
MAX_NUM_STRINGS :: 16 * 1024; // I don't think I'll get over this soon
Char_Draw_Data :: Char_Draw_Data_GEN(MAX_NUM_CHARS, MAX_NUM_STRINGS);


Quad_Draw_Info :: struct {
	position: linalg.Vector2,
	size: linalg.Vector2,
	color: linalg.Vector4,
};
String_Draw_Info :: struct {
	substring_idx: uint,
	color: linalg.Vector4,
};

UI_Draw_Info :: union {
	Quad_Draw_Info,
	String_Draw_Info,
};



Viewport_Data :: struct {
	left: f32,
	right: f32,
	top: f32,
	bottom: f32,
};

UI_Draw_Commands :: struct {
	draw_commands: []UI_Draw_Info,
	text_data: ^Char_Draw_Data,
	num_commands: uint,
	rect_pipeline: Pipeline,
};


rect_pipeline_layout: vk.VkPipelineLayout;

init_ui :: proc() {


	vert_push_constant_range := vk.VkPushConstantRange{};
	vert_push_constant_range.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT;//: VkShaderStageFlags,
	vert_push_constant_range.offset = 0;//: u32,
	vert_push_constant_range.size = 16;//: u32,

	frag_push_constant_range := vk.VkPushConstantRange{};
	frag_push_constant_range.stageFlags = .VK_SHADER_STAGE_FRAGMENT_BIT;//: VkShaderStageFlags,
	frag_push_constant_range.offset = 16;//: u32,
	frag_push_constant_range.size = 16;//: u32,

	rect_pipeline_layout = create_pipeline_layout({viewport_descriptor_layout, font_descriptor_layout}, {vert_push_constant_range, frag_push_constant_range});

}



create_draw_commands :: proc (count: uint, render_pass: vk.VkRenderPass) -> UI_Draw_Commands {
	draw_commands := UI_Draw_Commands{};
	draw_commands.draw_commands = make([]UI_Draw_Info, count);
	draw_commands.num_commands = 0;

	draw_commands.text_data = create_char_draw_data(render_pass);

	mix_color_blend_info :PipelineBlendState = ---;
	mix_blend_info(&mix_color_blend_info);


	rect_vertex_info := vk.VkPipelineVertexInputStateCreateInfo {};
	rect_vertex_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
	rect_vertex_info.vertexBindingDescriptionCount = 0;
	rect_vertex_info.vertexAttributeDescriptionCount = 0;
	rect_shader_stages := create_shader_stages("content/shader_rect.vert.spv", "content/shader_rect.frag.spv");

	draw_commands.rect_pipeline = create_graphic_pipeline2(pipeline_cache, render_pass, &rect_vertex_info, rect_pipeline_layout, rect_shader_stages[:], &mix_color_blend_info);

	return draw_commands;
}

reset_draw_commands :: proc(draw_commands: ^UI_Draw_Commands) {
	draw_commands.num_commands = 0;
	draw_commands.text_data.char_count = 0;
	draw_commands.text_data.substring_count = 0;
}


Rect :: struct {
	left: f32,
	top: f32,
	right: f32,
	bottom: f32,
};

is_inside_rect :: proc(position: [2]f32, using rect: ^Rect) -> bool {
	return position.x >= left && position.x <= right && position.y >= top && position.y <= bottom;
}

draw_quad2 :: proc(cmd_list: ^UI_Draw_Commands, using rect: ^Rect, color: linalg.Vector4) {
	draw_quad(cmd_list, {left, top}, {right-left, bottom-top}, color);
}

draw_quad :: proc(cmd_list: ^UI_Draw_Commands, position, size: linalg.Vector2, color: linalg.Vector4) {
	draw_info := Quad_Draw_Info {
		position = position,
		size = size,
		color = color,
	};
	cmd_list.draw_commands[cmd_list.num_commands] = draw_info;
	cmd_list.num_commands += 1;
}
draw_string2 :: proc(cmd_list: ^UI_Draw_Commands, text: string, position: linalg.Vector2, color: linalg.Vector4) {
	substring_idx := draw_string(cmd_list.text_data, text, auto_cast position);
	draw_info := String_Draw_Info {
		substring_idx = substring_idx,
		color = color,
	};
	cmd_list.draw_commands[cmd_list.num_commands] = draw_info;
	cmd_list.num_commands += 1;
}


draw_string :: proc(text_data: ^Char_Draw_Data, in_string: string, in_pos: [2]f32 ) -> (substring_idx: uint) {

	pos := in_pos;

	substring_idx = text_data.substring_count;
	substring := &text_data.substrings[substring_idx];
	text_data.substring_count += 1;

	substring.string_start = text_data.char_count;
	substring.string_size = u32(len(in_string));

	char_data := text_data.char_data;

	text_num_chars := len(in_string);
	for idx in 0..<text_num_chars {
		array_index := text_data.char_count;
		text_data.char_count += 1;

		char_id := int(in_string[idx]) - text_data.font_first_idx;
		char_quad := &text_data.char_quads[array_index];
		// xpos, ypos, char_quad = stbtt.get_baked_quad(char_data, int(font_tex_size.x), int(font_tex_size.y), char_id, true);
		stbtt.stbtt_GetBakedQuad(&char_data[0], i32(text_data.font_size.x), i32(text_data.font_size.y), i32(char_id), &pos.x, &pos.y, char_quad, 1);
	}

	assert(text_data.char_count < len(text_data.char_quads));
	return;
}


ui_collect_commands :: proc (command_buffer: vk.VkCommandBuffer, ui_commands: ^UI_Draw_Commands, viewport: vk.VkDescriptorSet) {

	using ui_commands;

	b_offset: vk.VkDeviceSize = 0;
	vk.vkCmdBindVertexBuffers(command_buffer, 0, 1, &text_data.buffer.handle, &b_offset);

	descriptors := []vk.VkDescriptorSet {
		viewport,
		text_data.font_descriptor,
	};


	for item_idx in 0..<num_commands {
		command := draw_commands[item_idx];
		switch c in command {
		case Quad_Draw_Info:
			vk.vkCmdBindDescriptorSets(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, rect_pipeline.layout, 0, u32(len(descriptors)), raw_data(descriptors), 0, nil);
			vk.vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, rect_pipeline.pipeline);

			c_copy := c;
			vk.vkCmdPushConstants(command_buffer, rect_pipeline.layout, .VK_SHADER_STAGE_VERTEX_BIT, 0, 16, &c_copy.position);
			vk.vkCmdPushConstants(command_buffer, rect_pipeline.layout, .VK_SHADER_STAGE_FRAGMENT_BIT, 16, 16, &c_copy.color);
			vk.vkCmdDraw(command_buffer, 6, 1, 0, 0);


		case String_Draw_Info:
			vk.vkCmdBindDescriptorSets(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, text_data.pipeline.layout, 0, u32(len(descriptors)), raw_data(descriptors), 0, nil);
			vk.vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, text_data.pipeline.pipeline);
			c_copy := c;
			vk.vkCmdPushConstants(command_buffer, text_data.pipeline.layout, .VK_SHADER_STAGE_FRAGMENT_BIT, 0, 16, &c_copy.color);

			substr := &text_data.substrings[c.substring_idx];
			vk.vkCmdDraw(command_buffer, 6, u32(substr.string_size), 0, substr.string_start);
		}
	}
}


create_char_draw_data :: proc (render_pass: vk.VkRenderPass) -> ^Char_Draw_Data {
	text_data := new(Char_Draw_Data);
	text_data.char_count = 0;
	text_data.substring_count = 0;

	text_data.font_size = [2]int {512, 512};

	font_pixels := make([]u8, text_data.font_size.x * text_data.font_size.y);


	text_data.font_first_idx = 32; // space
	num_chars := 95; // from 32 to 126


	char_file, ss := os.read_entire_file("content/fonts/Roboto-Regular.ttf");
	assert(ss);

	char_data, result := stbtt.bake_font_bitmap(
		char_file, 0, // data, offset
		24, //pixel_height
		font_pixels, //storage
		int(text_data.font_size.x), int(text_data.font_size.y),
		text_data.font_first_idx, num_chars,
	);

	text_data.char_data = char_data;

	text_data.buffer = make_buffer_array(text_data.char_quads[:], .VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);


	font_buffer := make_buffer(&font_pixels[0], len(font_pixels), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT);

	text_data.image = create_image(u32(text_data.font_size.x), u32(text_data.font_size.y), .VK_FORMAT_R8_UNORM);
	ctx := get_context();
	fill_image_with_buffer(&text_data.image, &font_buffer, graphics_command_pool, ctx.graphics_queue);

	my_font_image_view := create_image_view(text_data.image.handle, text_data.image.format);


	text_font_descriptor_set := alloc_descriptor_sets(descriptor_pool, font_descriptor_layout, 1);
	text_data.font_descriptor = text_font_descriptor_set[0];

	sampler := create_sampler();
	usage :vk.VkImageLayout = .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
	update_binding(text_font_descriptor_set[0], 0, sampler, my_font_image_view, usage);


	text_instance_binding := vk.VkVertexInputBindingDescription {};
	text_instance_binding.binding = 0;
	text_instance_binding.stride = size_of(stbtt.Aligned_Quad);
	text_instance_binding.inputRate = .VK_VERTEX_INPUT_RATE_INSTANCE;

	text_attrib_desc_0 := vk.VkVertexInputAttributeDescription {};
	text_attrib_desc_0.binding = 0;
	text_attrib_desc_0.location = 0;
	text_attrib_desc_0.format = .VK_FORMAT_R32G32B32A32_SFLOAT;
	text_attrib_desc_0.offset = u32(offset_of(stbtt.Aligned_Quad, x0));

	text_attrib_desc_1 := vk.VkVertexInputAttributeDescription {};
	text_attrib_desc_1.binding = 0;
	text_attrib_desc_1.location = 1;
	text_attrib_desc_1.format = .VK_FORMAT_R32G32B32A32_SFLOAT;
	text_attrib_desc_1.offset = u32(offset_of(stbtt.Aligned_Quad, x1));

	text_attrib_descriptions := []vk.VkVertexInputAttributeDescription {
		text_attrib_desc_0,
		text_attrib_desc_1,
	};



	text_vertex_info := vk.VkPipelineVertexInputStateCreateInfo {};
	text_vertex_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
	text_vertex_info.vertexBindingDescriptionCount = 1;
	text_vertex_info.pVertexBindingDescriptions = &text_instance_binding;
	text_vertex_info.vertexAttributeDescriptionCount = u32(len(text_attrib_descriptions));
	text_vertex_info.pVertexAttributeDescriptions = &text_attrib_descriptions[0];


	text_shader_stages := create_shader_stages("content/shader_text.vert.spv", "content/shader_text.frag.spv");


	text_push_constant_range := vk.VkPushConstantRange{};
	text_push_constant_range.stageFlags = .VK_SHADER_STAGE_FRAGMENT_BIT;//: VkShaderStageFlags,
	text_push_constant_range.offset = 0;//: u32,
	text_push_constant_range.size = 16;//: u32,

	text_pipeline_layout: = create_pipeline_layout({viewport_descriptor_layout, font_descriptor_layout}, {text_push_constant_range});


	mix_color_blend_info :PipelineBlendState = ---;
	mix_blend_info(&mix_color_blend_info);


	text_pipeline := create_graphic_pipeline(pipeline_cache, render_pass, &text_vertex_info, text_pipeline_layout, text_shader_stages[:], &mix_color_blend_info);
	text_data.pipeline = {text_pipeline, text_pipeline_layout};



	return text_data;
}



UI_State :: struct {
	draw_commands: ^UI_Draw_Commands,
	mouse: [2]f32,
};
draw_button :: proc (text: string, rect: Rect, using ui_state: ^UI_State) -> bool {
	rect_copy := rect;
	color: linalg.Vector4 = {.7,.7,.7,.7};
	if (is_inside_rect(ui_state.mouse, &rect_copy)) {
		color = {1,1,1,1};
	}
	draw_quad2(draw_commands, &rect_copy, color);
	TEXT_OFFSET :: [2]f32 {20, 20};
	draw_string2(draw_commands, text, {rect.left+TEXT_OFFSET.x, rect.top + TEXT_OFFSET.y}, {0,0,0,1});
	return false;
}
