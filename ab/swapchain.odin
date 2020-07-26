package ab
import vk "shared:odin-vulkan"



Swapchain :: struct {
	width       :u32,
	height      :u32,
	swapchain   :vk.VkSwapchainKHR,
	image_count :u32,
};





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
