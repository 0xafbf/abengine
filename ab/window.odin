package ab
import vk "shared:odin-vulkan"
import glfw "shared:odin-glfw"
import glfw_bindings "shared:odin-glfw/bindings"


Window :: struct {
	size: [2]u32,
	handle: glfw.Window_Handle,
	surface: vk.VkSurfaceKHR,
	swapchain: Swapchain,
};

create_window :: proc(in_size: [2]u32, name: string) -> Window {
	using window := Window {
		size = in_size,
	};
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



	return window;
}

