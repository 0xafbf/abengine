package ab
import "core:math/linalg"
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
	buffer :^Buffer,
	pipeline: Pipeline,
	font_size: [2]int,
	font_descriptor: vk.VkDescriptorSet, // to keep texture
	font_first_idx: int,
	char_data: []stbtt.Baked_Char,
	viewport_descriptor: vk.VkDescriptorSet,
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

UI_Draw_Commands :: struct {
	draw_commands: []UI_Draw_Info,
	text_data: ^Char_Draw_Data,
	num_commands: uint,
	rect_pipeline: ^Pipeline,
};

create_draw_commands :: proc (count: uint, text_data: ^Char_Draw_Data, rect_pipeline: ^Pipeline) -> UI_Draw_Commands {
	draw_commands := UI_Draw_Commands{};
	draw_commands.draw_commands = make([]UI_Draw_Info, count);
	draw_commands.num_commands = 0;
	draw_commands.text_data = text_data;
	draw_commands.rect_pipeline = rect_pipeline;
	return draw_commands;
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


ui_collect_commands :: proc (command_buffer: vk.VkCommandBuffer, ui_commands: ^UI_Draw_Commands) {

	using ui_commands;

	b_offset: vk.VkDeviceSize = 0;
	vk.vkCmdBindVertexBuffers(command_buffer, 0, 1, &text_data.buffer.handle, &b_offset);

	descriptors := []vk.VkDescriptorSet {
		text_data.viewport_descriptor,
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
