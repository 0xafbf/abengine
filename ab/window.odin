package ab

import "core:fmt"
import "core:math/bits"

import vk "shared:odin-vulkan"
import glfw "shared:odin-glfw"
import glfw_bindings "shared:odin-glfw/bindings"


MAX_FRAMES_IN_FLIGHT :: 2;

Window :: struct {
	size: [2]u32,
	handle: glfw.Window_Handle,
	surface: vk.VkSurfaceKHR,
	swapchain: ^Swapchain,
	active: bool,
	command_buffers: []vk.VkCommandBuffer,

	image_available_semaphore: [MAX_FRAMES_IN_FLIGHT]vk.VkSemaphore,
	render_finished_semaphore: [MAX_FRAMES_IN_FLIGHT]vk.VkSemaphore,
	in_flight_fences:          [MAX_FRAMES_IN_FLIGHT]vk.VkFence,

	image_fences: []vk.VkFence,
	current_frame: int,
};


windows := [20]^Window {};
num_windows: int = 0;

create_window :: proc(in_size: [2]u32, name: string) -> ^Window {
	using window := new (Window);
	window.size = in_size;
	glfw.window_hint(.CLIENT_API, int(glfw.NO_API));
	window.handle = glfw.create_window(int(size.x), int(size.y), name, nil, nil);

	ctx := get_context();
	vk.CHECK(auto_cast glfw_bindings.CreateWindowSurface(
		auto_cast ctx.instance,
		handle, nil,
		auto_cast&surface)
	);


	if !ctx.present_queue_found {
		for idx in 0..<ctx.queue_family_count {
			present_support :vk.VkBool32 = false;
			vk.vkGetPhysicalDeviceSurfaceSupportKHR(ctx.physical_device, idx, surface, &present_support);
			if present_support {
				ctx.present_queue_family_idx = idx;
				ctx.present_queue_found = true;
			}
		}
		assert(ctx.present_queue_found);

		present_queue := &ctx.present_queue;
		vk.vkGetDeviceQueue(ctx.device, ctx.present_queue_family_idx, 0, present_queue);
	}



	// pre swapchain ========================

	format_count :u32 = 0;
	vk.vkGetPhysicalDeviceSurfaceFormatsKHR(ctx.physical_device, surface, &format_count, nil);

	formats := make([]vk.VkSurfaceFormatKHR, format_count);
	vk.vkGetPhysicalDeviceSurfaceFormatsKHR(ctx.physical_device, surface, &format_count, &formats[0]);
	assert(format_count > 0);

	desired_format := vk.VkSurfaceFormatKHR {};
	desired_format.format = .VK_FORMAT_B8G8R8A8_SRGB;
	desired_format.colorSpace = .VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;

	format_available := false;
	for idx in 0..<format_count {
		format := formats[idx];
		if (format.format == desired_format.format
			&& format.colorSpace == desired_format.colorSpace
		) {
			format_available = true;
			break;
		}
	}
	assert(format_available);
	delete(formats);

	present_modes_count :u32 = 0;
	vk.vkGetPhysicalDeviceSurfacePresentModesKHR(ctx.physical_device, surface, &present_modes_count, nil);

	present_modes := make([]vk.VkPresentModeKHR, present_modes_count);
	vk.vkGetPhysicalDeviceSurfacePresentModesKHR(ctx.physical_device, surface, &present_modes_count, &present_modes[0]);
	assert(present_modes_count > 0);

	present_mode := vk.VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
	for idx in 0..<present_modes_count {
		if (present_modes[idx] == .VK_PRESENT_MODE_MAILBOX_KHR) {
			present_mode = .VK_PRESENT_MODE_MAILBOX_KHR;
		}
	}

	delete(present_modes);

// TODO: validate
	capabilities :vk.VkSurfaceCapabilitiesKHR = ---;
	vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(ctx.physical_device, surface, &capabilities);


	assert(size.x >= capabilities.minImageExtent.width);
	assert(size.x <= capabilities.maxImageExtent.width);
	assert(size.y >= capabilities.minImageExtent.height);
	assert(size.y <= capabilities.maxImageExtent.height);

	image_count :u32 = capabilities.minImageCount + 1;
	if (capabilities.maxImageCount != 0) {
		assert(image_count <= capabilities.maxImageCount);
	}
	// end pre-swapchain


	p_queue_indices := []u32 {};
	if (ctx.graphics_queue_family_idx != ctx.present_queue_family_idx) {
		p_queue_indices = {ctx.graphics_queue_family_idx, ctx.present_queue_family_idx};
	}

	window.swapchain = create_swapchain(surface, size, image_count, desired_format.format, desired_format.colorSpace, p_queue_indices, present_mode);


	window.command_buffers = alloc_command_buffers(graphics_command_pool, .VK_COMMAND_BUFFER_LEVEL_PRIMARY, MAX_FRAMES_IN_FLIGHT);



	image_fences = make([]vk.VkFence, image_count);

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


	window.current_frame = 0;
	window.active = true;
	windows[num_windows] = window;
	num_windows += 1;
	return window;
}

loop_windows :: proc() -> bool {
	glfw.poll_events();

	any_window_active := false;
	for idx in 0..<num_windows {
		win := windows[idx];
		if !win.active { continue; }
		if glfw.window_should_close(win.handle) {
			win.active = false;
			continue;
		}

		any_window_active = true;
		ui_poll(win);
		reset_draw_commands(&win.swapchain.ui_state);

	}

	return any_window_active;
}




ui_poll :: proc(window: ^Window) {

	ui_state := &window.swapchain.ui_state;
	cursor_x, cursor_y := glfw.get_cursor_pos(window.handle);
	ui_state.mouse = {f32(cursor_x), f32(cursor_y)};
	ui_state.last_mouse_pressed = ui_state.mouse_pressed;

	mouse_state := glfw.get_mouse_button(window.handle, .MOUSE_BUTTON_1);
	ui_state.mouse_pressed = (mouse_state == .PRESS);
}


end_frame :: proc(win: ^Window, to_draw: []Mesh_Draw_Info) {
	ctx := get_context();
	my_swapchain := win.swapchain;
	ui_state := win.swapchain.ui_state;
	current_frame := win.current_frame;
	vk.vkWaitForFences(ctx.device, 1, &win.in_flight_fences[current_frame], true, bits.U64_MAX);
	update_command_buffers(&my_swapchain.viewport, win.command_buffers[current_frame:current_frame+1], my_swapchain.framebuffers[current_frame:current_frame+1], to_draw, my_swapchain.render_pass, ui_state);


	image_index :u32 = ---;
	vk.vkAcquireNextImageKHR(ctx.device, my_swapchain.handle, bits.U64_MAX, win.image_available_semaphore[current_frame], nil, &image_index);

	if (win.image_fences[image_index] != nil) {
		vk.vkWaitForFences(ctx.device, 1, &win.image_fences[image_index], true, bits.U64_MAX);
	}
	win.image_fences[image_index] = win.in_flight_fences[current_frame];

	wait_stages :vk.VkPipelineStageFlags = .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
	submit_info := vk.VkSubmitInfo{};
	submit_info.sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO;
	submit_info.waitSemaphoreCount = 1;
	submit_info.pWaitSemaphores = &win.image_available_semaphore[current_frame];
	submit_info.pWaitDstStageMask = &wait_stages;
	submit_info.commandBufferCount = 1;
	submit_info.pCommandBuffers = &win.command_buffers[image_index];
	submit_info.signalSemaphoreCount = 1;
	submit_info.pSignalSemaphores = &win.render_finished_semaphore[current_frame];

	vk.vkResetFences(ctx.device, 1, &win.in_flight_fences[current_frame]);
	vk.CHECK(vk.vkQueueSubmit(ctx.graphics_queue, 1, &submit_info, win.in_flight_fences[current_frame]));

	present_info := vk.VkPresentInfoKHR{};
	present_info.sType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
	present_info.waitSemaphoreCount = 1;
	present_info.pWaitSemaphores = &win.render_finished_semaphore[current_frame];
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
	}

	win.current_frame = (current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
}
