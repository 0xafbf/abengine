package main

import "core:os"
import "core:math"
import "core:math/bits"
import "core:math/linalg"

import "core:fmt"
import "core:mem"
import "core:path"
import "core:strings"
import glfw "shared:odin-glfw"
import glfw_bindings "shared:odin-glfw/bindings"
import vk "shared:odin-vulkan"

import "shared:odin-stb/stbi"
import "ab"


main :: proc() {
	using ab;

	engine_init();
	ctx := get_context();

	//create window
	win := create_window({1600, 900}, "Window");
	glfw.set_window_pos(win.handle, 100 - 1920, 100);
	
	////////////////////////////////////////
	// 3D Quad setup
	/////////////////////////////////////////
	Vertex :: struct {
		position :[3]f32,
		uv :[2]f32,
	};


	triangle := [4]Vertex {
	    {{-0.5, -0.5, 0.5},  {0.0, 0.0}},
	    {{-0.5,  0.5, 0.5},  {0.0, 1.0}},
	    {{ 0.5,  0.5, 0.5},  {1.0, 1.0}},
	    {{ 0.5, -0.5, 0.5},  {1.0, 0.0}},
	};

	triangle_indices := [6]u32 {
		0, 1, 2,  0, 2, 3
	};

	binding_description := vk.VkVertexInputBindingDescription {};
	binding_description.binding = 0;
	binding_description.stride = size_of(Vertex);
	binding_description.inputRate = .VK_VERTEX_INPUT_RATE_VERTEX;

	attrib_position_description := vk.VkVertexInputAttributeDescription {};
	attrib_position_description.binding = 0;
	attrib_position_description.location = 0;
	attrib_position_description.format = .VK_FORMAT_R32G32B32_SFLOAT;
	attrib_position_description.offset = u32(offset_of(Vertex, position));

	attrib_uv_description := vk.VkVertexInputAttributeDescription {};
	attrib_uv_description.binding = 0;
	attrib_uv_description.location = 1;
	attrib_uv_description.format = .VK_FORMAT_R32G32_SFLOAT;
	attrib_uv_description.offset = u32(offset_of(Vertex, uv));

	attrib_descriptions := []vk.VkVertexInputAttributeDescription {
		attrib_position_description,
		attrib_uv_description,
	};


	vertex_info := vk.VkPipelineVertexInputStateCreateInfo {};
	vertex_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
	vertex_info.vertexBindingDescriptionCount = 1;
	vertex_info.pVertexBindingDescriptions = &binding_description;
	vertex_info.vertexAttributeDescriptionCount = u32(len(attrib_descriptions));
	vertex_info.pVertexAttributeDescriptions = &attrib_descriptions[0];

	descriptor_set_layout := create_mvp_descriptor_set_layout();
	pipeline_layout := create_pipeline_layout({descriptor_set_layout}, {});


	color_blend_info :PipelineBlendState = ---;
	opaque_blend_info(&color_blend_info);
	shader_stages := create_shader_stages("content/shader_4.vert.spv", "content/shader_4.frag.spv");
	pipeline := create_graphic_pipeline(pipeline_cache, win.swapchain.render_pass, &vertex_info, pipeline_layout, shader_stages[:], &color_blend_info);

	descriptor_sets := ab.alloc_descriptor_sets(descriptor_pool, descriptor_set_layout, 2);




	UniformBufferObject :: struct {
		model :linalg.Matrix4,
		view :linalg.Matrix4,
		proj :linalg.Matrix4,
	};

	Transform :: struct {
		translation: linalg.Vector3,
		rotation: linalg.Quaternion,
		scale: linalg.Vector3,
	};


	ubo := UniformBufferObject {};
	ubo2 := UniformBufferObject {};

	ubo.model = linalg.MATRIX4_IDENTITY;
	ubo2.model = linalg.MATRIX4_IDENTITY;

	t := Transform{
		translation = {0, 0.5, -2},
		scale = {1,1,1},
		rotation = linalg.quaternion_angle_axis(math.TAU / 15, {1, 0, 0}),
	};

	ubo.view = linalg.matrix4_from_trs(t.translation, t.rotation, t.scale);
	ubo2.view = ubo.view;

	size := win.swapchain.size;
	aspect := f32(size.x) / f32(size.y);
	ubo.proj = linalg.matrix4_perspective(1.2, aspect, 0.1, 100);
	ubo2.proj = ubo.proj;
	// ubo2.proj = linalg.matrix4_scale({1/aspect, -1, 1});

	uniform_buffer := make_buffer(&ubo,   size_of(ubo), .VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
	uniform_buffer2 := make_buffer(&ubo2, size_of(ubo2), .VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);


	update_binding(descriptor_sets[0], 0, &uniform_buffer);
	update_binding(descriptor_sets[1], 0, &uniform_buffer2);




	img_x, img_y, img_channels : i32;
	image_data := stbi.load("content/texture.jpg", &img_x, &img_y, &img_channels, 4);

	img_size := img_x * img_y * 4;
	img_buffer := make_buffer(image_data, int(img_size), .VK_BUFFER_USAGE_TRANSFER_SRC_BIT);
	stbi.image_free(image_data);



	my_image := create_image(u32 (img_x), u32 (img_y), .VK_FORMAT_R8G8B8A8_SRGB);
	image := my_image.handle;


	fill_image_with_buffer(&my_image, &img_buffer, graphics_command_pool, ctx.graphics_queue);


	my_image_view := create_image_view(my_image.handle, my_image.format);

	sampler := create_sampler();

	usage :vk.VkImageLayout = .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
	update_binding(descriptor_sets[0], 1, sampler, my_image_view, usage);
	update_binding(descriptor_sets[1], 1, sampler, my_image_view, usage);



	index_buffer := make_buffer(&triangle_indices[0], size_of(triangle_indices), .VK_BUFFER_USAGE_INDEX_BUFFER_BIT);
	vertex_buffer := make_buffer(&triangle[0], size_of(triangle), .VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);

	my_mesh := Mesh_Info {
		vertex_buffer = &vertex_buffer,
		index_buffer = &index_buffer,
		index_count = len(triangle_indices),
	};

	my_mesh_draw := Mesh_Draw_Info {
		pipeline = {pipeline, pipeline_layout},
		mesh = &my_mesh,
		descriptor_set = descriptor_sets[0],
	};

	my_mesh_draw2 := Mesh_Draw_Info {
		pipeline = {pipeline, pipeline_layout},
		mesh = &my_mesh,
		descriptor_set = descriptor_sets[1],
	};

	to_draw := []Mesh_Draw_Info {
		my_mesh_draw,
		my_mesh_draw2,
	};

	/// end 3d quad






	rot := f32(0);
	frame_number := 0;

	fps_builder := strings.make_builder(40);


	Browser_State :: struct {
		visible: bool,
		base_name: string,
		full_path: string,
		disk_entries: []ab.DiskEntry,
		child_states: [dynamic]^Browser_State,
	};
	retrieve_browser_state :: proc(dir: string, name: string) -> ^Browser_State {
		state := new(Browser_State);
		state.base_name = name;
		state.full_path = fmt.aprintf("{0}{1}/", dir, name);
		state.disk_entries = get_all_entries_in_directory(state.full_path);
		state.child_states = make([dynamic]^Browser_State, 0, 6);
		fmt.println("retrieving state {0} {1}", state.full_path, len(state.disk_entries));
		return state;
	}

	current_dir := os.get_current_directory();
	fmt.println("current_dir:", current_dir);
	dir := fmt.aprintf("{0}/", current_dir);

	browser_state := retrieve_browser_state(dir, "content");

	
	// update loop
	for loop_windows() {

		// 3D Quad update
		rot += 0.05;
		ubo.model = linalg.matrix4_rotate(rot/10, {0, 0, 1});
		buffer_sync(&uniform_buffer);

		ubo2.model = linalg.matrix4_rotate(-rot/3.5, {0, 1, 1});
		buffer_sync(&uniform_buffer2);
		/// end 3d quad

		strings.reset_builder(&fps_builder);
		fps_string := fmt.sbprintf(&fps_builder, "{0} times clicked", frame_number);
		ui_state := &win.swapchain.ui_state;
		if (draw_button(ui_state, fps_string, {{0, 0}, {200, 50}})) {
			frame_number += 1;
		}

		using linalg;

		show_folder_contents :: proc (ui_state: ^UI_State, state: ^Browser_State) {
			entries := state.disk_entries;

			for idx in 0..<len(entries) {
				entry := &entries[idx];
				VERTICAL_SIZE :: 24.;
				start_position := ui_state.cursor;
				// draw_quad(&ui_draw_commands, start_position, {600, VERTICAL_SIZE}, {0.2, 0.2, 0.2, 1.0});
				// draw_string2(&ui_draw_commands, entry.name, start_position + {20, 20});
				
				toggle_draw := draw_button(
					ui_state, entry.name,
					{ {start_position.x, start_position.y}, {300, VERTICAL_SIZE} }
				);
				draws := false;
				child_draw: ^Browser_State = nil;
				for child in state.child_states {
					if (strings.compare(child.base_name, entry.name) == 0) {
						if toggle_draw do child.visible = !child.visible;
						draws = child.visible;
						child_draw = child;
					}
				}
				if toggle_draw {
					draws = !draws;
				}
				
			
				if (entry.dir) {
					color: linalg.Vector4 = draws ? {1, 0, 0, 1} : {0, 1, 0, 1};
					draw_quad(ui_state, start_position + {4,4}, {16, 16}, color);
				}
				ui_state.cursor.y += VERTICAL_SIZE;
				ui_state.cursor.x += 24;
				if draws {
					if (child_draw == nil) {
						child_draw = retrieve_browser_state(state.full_path, entry.name);
						child_draw.visible = true;
						append(&state.child_states, child_draw);
					}

					show_folder_contents(ui_state, child_draw);
				}
				ui_state.cursor.x -= 24;
			}
		}
		ui_state.cursor = {0,0};
		show_folder_contents(ui_state, browser_state);

		end_frame(win, to_draw);
	}
}


Graph :: struct {
	
}
