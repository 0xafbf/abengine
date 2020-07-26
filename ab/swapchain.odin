package ab
import vk "shared:odin-vulkan"


MAX_SWAPCHAIN_IMAGES :: 4;

Swapchain :: struct {
	width       :u32,
	height      :u32,
	handle   :vk.VkSwapchainKHR,
	image_count :u32,
	create_info: vk.VkSwapchainCreateInfoKHR,
	images:    [MAX_SWAPCHAIN_IMAGES]vk.VkImage,
	image_views:    [MAX_SWAPCHAIN_IMAGES]vk.VkImageView,
};



create_swapchain :: proc(
	surface: vk.VkSurfaceKHR,
	extent: vk.VkExtent2D,
	image_count: u32,
	format: vk.VkFormat,
	color_space: vk.VkColorSpaceKHR,
	queue_family_indices: []u32,
	present_mode: vk.VkPresentModeKHR,
) -> Swapchain {

	swapchain := Swapchain{};
	swapchain.width = extent.width;
	swapchain.height = extent.height;
	// swapchain.image_count = swapchain.image_count; // reset on recreate_swapchain

	swapchain_info := &swapchain.create_info;
	swapchain_info.sType = .VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
	swapchain_info.surface = surface;
	// VkSwapchainCreateFlagsKHR          flags;
	swapchain_info.minImageCount = image_count;
	swapchain_info.imageFormat = format;
	swapchain_info.imageColorSpace = color_space;
	swapchain_info.imageExtent = {swapchain.width, swapchain.height};
	swapchain_info.imageArrayLayers = 1;
	swapchain_info.imageUsage = .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

	swapchain_info.queueFamilyIndexCount = u32(len(queue_family_indices));
	swapchain_info.pQueueFamilyIndices = raw_data(queue_family_indices);

	if swapchain_info.queueFamilyIndexCount == 0 {
		swapchain_info.imageSharingMode = .VK_SHARING_MODE_EXCLUSIVE;
	} else {
		swapchain_info.imageSharingMode = .VK_SHARING_MODE_CONCURRENT;
	}

	swapchain_info.preTransform = .VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
	swapchain_info.compositeAlpha = .VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
	swapchain_info.presentMode = present_mode;
	swapchain_info.clipped = true;
	swapchain_info.oldSwapchain = nil;


	recreate_swapchain(&swapchain, {swapchain.width, swapchain.height});

	return swapchain;
}


recreate_swapchain :: proc(swapchain: ^Swapchain, extent: vk.VkExtent2D) {
	swapchain.width = extent.width;
	swapchain.height = extent.height;
	swapchain.create_info.imageExtent = {swapchain.width, swapchain.height};
	ctx := get_context();
	vk.CHECK(vk.vkCreateSwapchainKHR(ctx.device, &swapchain.create_info, nil, &swapchain.handle));

	// swapchain.image_count = swapchain.image_count; // reset on recreate_swapchain
	vk.vkGetSwapchainImagesKHR(ctx.device, swapchain.handle, &swapchain.image_count, nil);
	assert(swapchain.image_count < MAX_SWAPCHAIN_IMAGES);
	vk.vkGetSwapchainImagesKHR(ctx.device, swapchain.handle, &swapchain.image_count, &swapchain.images[0]);


	for idx in 0..<swapchain.image_count {
		swapchain.image_views[idx] = create_image_view(swapchain.images[idx], swapchain.create_info.imageFormat);
	}
}

create_render_pass :: proc (
	format: vk.VkFormat,
) -> vk.VkRenderPass {
	attachment_description := vk.VkAttachmentDescription {};
	attachment_description.format = format;
	attachment_description.samples = .VK_SAMPLE_COUNT_1_BIT;
	attachment_description.loadOp = .VK_ATTACHMENT_LOAD_OP_CLEAR;
	attachment_description.storeOp = .VK_ATTACHMENT_STORE_OP_STORE;
	attachment_description.stencilLoadOp = .VK_ATTACHMENT_LOAD_OP_DONT_CARE;
	attachment_description.stencilStoreOp = .VK_ATTACHMENT_STORE_OP_DONT_CARE;
	attachment_description.initialLayout = .VK_IMAGE_LAYOUT_UNDEFINED;
	attachment_description.finalLayout = .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;


	attachment_ref := vk.VkAttachmentReference {};
	attachment_ref.attachment = 0;
	attachment_ref.layout = .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

	subpass := vk.VkSubpassDescription {};
	subpass.pipelineBindPoint = .VK_PIPELINE_BIND_POINT_GRAPHICS;
	subpass.colorAttachmentCount = 1;
	subpass.pColorAttachments = &attachment_ref;

	subpass_dependency := vk.VkSubpassDependency {};
	subpass_dependency.srcSubpass = u32(vk.VK_SUBPASS_EXTERNAL);
	subpass_dependency.dstSubpass = 0;
	subpass_dependency.srcStageMask = .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
	subpass_dependency.dstStageMask = .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
	subpass_dependency.srcAccessMask = {};
	subpass_dependency.dstAccessMask = .VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
	// subpass_dependency.dependencyFlags;

	render_pass_info := vk.VkRenderPassCreateInfo {};
	render_pass_info.sType = .VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
	render_pass_info.attachmentCount = 1;
	render_pass_info.pAttachments = &attachment_description;
	render_pass_info.subpassCount = 1;
	render_pass_info.pSubpasses = &subpass;
	render_pass_info.dependencyCount = 1;
	render_pass_info.pDependencies = &subpass_dependency;

	render_pass :vk.VkRenderPass = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreateRenderPass(ctx.device, &render_pass_info, nil, &render_pass));
	return render_pass;
}
