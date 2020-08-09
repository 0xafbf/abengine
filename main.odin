package main

import "core:os"
import "core:math"
import "core:math/bits"
import "core:math/linalg"

import "core:fmt"
import "core:mem"
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
	win := create_window({800, 600}, "Window");
	glfw.set_window_pos(win.handle, 200 - 1920, 200);

	my_swapchain := &win.swapchain;

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
	pipeline := create_graphic_pipeline(pipeline_cache, my_swapchain.render_pass, &vertex_info, pipeline_layout, shader_stages[:], &color_blend_info);

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

	aspect := f32(my_swapchain.size.x) / f32(my_swapchain.size.y);
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



	// UI rect setup


	ui_draw_commands := create_draw_commands(1000, my_swapchain.render_pass);

	ui_state := UI_State {
		draw_commands = &ui_draw_commands,
	};

	MAX_FRAMES_IN_FLIGHT :: 2;
	command_buffers := alloc_command_buffers(graphics_command_pool, .VK_COMMAND_BUFFER_LEVEL_PRIMARY, MAX_FRAMES_IN_FLIGHT);


	image_available_semaphore := [MAX_FRAMES_IN_FLIGHT]vk.VkSemaphore {};
	render_finished_semaphore := [MAX_FRAMES_IN_FLIGHT]vk.VkSemaphore {};
	in_flight_fences := [MAX_FRAMES_IN_FLIGHT]vk.VkFence {};

	image_fences := [10]vk.VkFence { };

	semaphore_info := vk.VkSemaphoreCreateInfo {};
	semaphore_info.sType = .VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

	fence_info := vk.VkFenceCreateInfo {};
	fence_info.sType = .VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
	fence_info.flags = .VK_FENCE_CREATE_SIGNALED_BIT;

	for idx in 0..< MAX_FRAMES_IN_FLIGHT {
		vk.CHECK(vk.vkCreateSemaphore(ctx.device, &semaphore_info, nil, &image_available_semaphore[idx]));
		vk.CHECK(vk.vkCreateSemaphore(ctx.device, &semaphore_info, nil, &render_finished_semaphore[idx]));

		vk.CHECK(vk.vkCreateFence(ctx.device, &fence_info, nil, &in_flight_fences[idx]));
	}

	current_frame := 0;

	rot := f32(0);
	frame_number := 0;


	fps_builder := strings.make_builder(40);

	// update loop
	for !glfw.window_should_close(win.handle) {
		glfw.poll_events();
		cursor_x, cursor_y := glfw.get_cursor_pos(win.handle);
		ui_state.mouse = {f32(cursor_x), f32(cursor_y)};

	////////////////////////////////////////
	// 3D Quad update
	/////////////////////////////////////////


		rot += 0.05;
		ubo.model = linalg.matrix4_rotate(rot/10, {0, 0, 1});
		buffer_sync(&uniform_buffer);

		ubo2.model = linalg.matrix4_rotate(-rot/3.5, {0, 1, 1});
		buffer_sync(&uniform_buffer2);

	/// end 3d quad


		reset_draw_commands(&ui_draw_commands);
		frame_number += 1;

		strings.reset_builder(&fps_builder);
		fps_string := fmt.sbprintf(&fps_builder, "{0} frames passed", frame_number);

		draw_button(fps_string, {0, 0, 200, 50}, &ui_state);



		vk.vkWaitForFences(ctx.device, 1, &in_flight_fences[current_frame], true, bits.U64_MAX);
		update_command_buffers(&my_swapchain.viewport, command_buffers[current_frame:current_frame+1], my_swapchain.framebuffers[current_frame:current_frame+1], to_draw, my_swapchain.render_pass, &ui_draw_commands);


		image_index :u32 = ---;
		vk.vkAcquireNextImageKHR(ctx.device, my_swapchain.handle, bits.U64_MAX, image_available_semaphore[current_frame], nil, &image_index);

		if (image_fences[image_index] != nil) {
			vk.vkWaitForFences(ctx.device, 1, &image_fences[image_index], true, bits.U64_MAX);
		}
		image_fences[image_index] = in_flight_fences[current_frame];

		wait_stages :vk.VkPipelineStageFlags = .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
		submit_info := vk.VkSubmitInfo{};
		submit_info.sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO;
		submit_info.waitSemaphoreCount = 1;
		submit_info.pWaitSemaphores = &image_available_semaphore[current_frame];
		submit_info.pWaitDstStageMask = &wait_stages;
		submit_info.commandBufferCount = 1;
		submit_info.pCommandBuffers = &command_buffers[image_index];
		submit_info.signalSemaphoreCount = 1;
		submit_info.pSignalSemaphores = &render_finished_semaphore[current_frame];

		vk.vkResetFences(ctx.device, 1, &in_flight_fences[current_frame]);
		vk.CHECK(vk.vkQueueSubmit(ctx.graphics_queue, 1, &submit_info, in_flight_fences[current_frame]));

		present_info := vk.VkPresentInfoKHR{};
		present_info.sType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
		present_info.waitSemaphoreCount = 1;
		present_info.pWaitSemaphores = &render_finished_semaphore[current_frame];
		present_info.swapchainCount = 1;
		present_info.pSwapchains = &my_swapchain.handle;
		present_info.pImageIndices = &image_index;
		present_info.pResults = nil;

		present_result := vk.vkQueuePresentKHR(ctx.present_queue, &present_info);

		if (present_result != .VK_SUCCESS) {
			fmt.println("present result is:", present_result);

			vk.vkDeviceWaitIdle(ctx.device);

			width, height := glfw.get_framebuffer_size(win.handle);
			recreate_swapchain(my_swapchain, {u32(width), u32(height)});


			aspect := f32(my_swapchain.size.x) / f32(my_swapchain.size.y);
			ubo.proj = linalg.matrix4_perspective(1.2, aspect, 0.1, 100);
			ubo2.proj = ubo.proj;
			buffer_sync(&uniform_buffer);
			buffer_sync(&uniform_buffer2);
		}

		current_frame = (current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
	}
}


