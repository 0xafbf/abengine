package main

import "core:os"
import "core:math/bits"

import "core:fmt"
import "core:mem"
import "core:strings"
import glfw "odin-glfw"
import glfw_bindings "odin-glfw/bindings"
import vk "vk_bindings"


debugCallback :: proc (
	messageSeverity: vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
	messageTypes: vk.VkDebugUtilsMessageTypeFlagsEXT,
	pCallbackData: ^vk.VkDebugUtilsMessengerCallbackDataEXT,
	pUserData: rawptr,
) -> vk.VkBool32 {
	fmt.println(pCallbackData.pMessage);
	return false;
};


main :: proc() {

	fmt.println("START");

	glfw.init();
	glfw.window_hint(.CLIENT_API, int(glfw.NO_API));

	win := glfw.create_window(800, 600, "Window", nil, nil);


	app_info := vk.VkApplicationInfo {};
	app_info.sType = .VK_STRUCTURE_TYPE_APPLICATION_INFO;
	app_info.pApplicationName = "My Game";
	app_info.applicationVersion = vk.VK_MAKE_VERSION(0, 1, 0);
	app_info.pEngineName = "Botero";
	app_info.engineVersion = vk.VK_MAKE_VERSION(0, 1, 0);
	app_info.apiVersion = vk.VK_MAKE_VERSION(1, 1, 0);

	instance_info := vk.VkInstanceCreateInfo {};
	instance_info.sType = .VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
	instance_info.pApplicationInfo = &app_info;


	all_extensions: [dynamic]cstring;

	glfw_extension_count :u32;
	glfw_extensions :^cstring = glfw_bindings.GetRequiredInstanceExtensions(&glfw_extension_count);

	glfw_slice := mem.slice_ptr(glfw_extensions, int(glfw_extension_count));

	for elem in glfw_slice {
		append(&all_extensions, elem);
	}

	append(&all_extensions, vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);

	instance_info.enabledExtensionCount = u32(len(all_extensions));
	instance_info.ppEnabledExtensionNames = &all_extensions[0];


	layers := []cstring {
		"VK_LAYER_KHRONOS_validation"
	};

	fmt.println(layers);

	instance_info.ppEnabledLayerNames = &layers[0];
	instance_info.enabledLayerCount = u32 (len(layers));


	messenger_info := vk.VkDebugUtilsMessengerCreateInfoEXT{};
	messenger_info.sType = .VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;

	messenger_info.messageSeverity = .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT;

	messenger_info.messageType = .VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |  .VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |  .VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;

	messenger_info.pfnUserCallback = debugCallback;

	instance_info.pNext = &messenger_info;


	instance: vk.VkInstance = ---;

	r := vk.vkCreateInstance(&instance_info, nil, &instance);
	assert(r == .VK_SUCCESS);

	messenger_type :: type_of(vk.vkCreateDebugUtilsMessengerEXT);
	create_messenger := cast(messenger_type) vk.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
	// assert(create_messenger != nil);
	messenger :vk.VkDebugUtilsMessengerEXT = ---;
	create_messenger(instance, &messenger_info, nil, &messenger);

	physical_devices := [4]vk.VkPhysicalDevice {};
	current_device_count :u32 = len(physical_devices);

	vk.vkEnumeratePhysicalDevices(instance, &current_device_count, &physical_devices[0]);

	selected_device :u32 = 0;
	for idx in 0..<current_device_count {
		device_features :vk.VkPhysicalDeviceFeatures = ---;
		vk.vkGetPhysicalDeviceFeatures(physical_devices[idx], &device_features);
		if (!device_features.geometryShader) {
			continue;
		}

		device_properties :vk.VkPhysicalDeviceProperties = ---;
		vk.vkGetPhysicalDeviceProperties(physical_devices[idx], &device_properties);

		fmt.println("phisical device:", cast(cstring)&device_properties.deviceName[0]);
		selected_device = idx;
		break;
	}


	// surface stuff
	surface :vk.VkSurfaceKHR = ---;
	r2 := glfw_bindings.CreateWindowSurface(auto_cast instance, win, nil, auto_cast &surface);
	r = auto_cast r2;

	assert(r == .VK_SUCCESS);
	// this needs to be done first, as we need to get a present queue that can
	// present to this surface


	physical_device := physical_devices[selected_device];

	queue_family_props :[10]vk.VkQueueFamilyProperties = ---;
	queue_family_count :u32 = len(queue_family_props);
	vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, &queue_family_props[0]);

	graphics_queue_family_idx :u32;
	present_queue_family_idx :u32;
	graphics_queue_found := false;
	present_queue_found := false;
	for idx in 0..<queue_family_count {
		if (queue_family_props[idx].queueFlags & .VK_QUEUE_GRAPHICS_BIT != auto_cast 0) {
			graphics_queue_family_idx = idx;
			graphics_queue_found = true;
		}

		present_support :vk.VkBool32 = false;
		vk.vkGetPhysicalDeviceSurfaceSupportKHR(physical_device, idx, surface, &present_support);
		if present_support {
			present_queue_family_idx = idx;
			present_queue_found = true;
		}
	}

	assert(graphics_queue_found);
	assert(present_queue_found);

	queue_infos := [2]vk.VkDeviceQueueCreateInfo {};

	graphics_queue_info := &queue_infos[0];
	graphics_queue_info.sType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
	graphics_queue_info.queueFamilyIndex = graphics_queue_family_idx;
	graphics_queue_info.queueCount = 1;
	graphics_queue_priority :f32 = 1.;
	graphics_queue_info.pQueuePriorities = &graphics_queue_priority;

	present_queue_info := &queue_infos[1];
	present_queue_info.sType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
	present_queue_info.queueFamilyIndex = present_queue_family_idx;
	present_queue_info.queueCount = 1;
	present_queue_priority :f32 = 1.;
	present_queue_info.pQueuePriorities = &present_queue_priority;


	num_extension_properties :u32 = 0;
	vk.vkEnumerateDeviceExtensionProperties(physical_device, nil, &num_extension_properties, nil);

	extension_properties := make([]vk.VkExtensionProperties, num_extension_properties);

	vk.vkEnumerateDeviceExtensionProperties(physical_device, nil, &num_extension_properties, &extension_properties[0]);


	device_extensions := [dynamic]cstring{};
	append(&device_extensions, vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME);

	all_extensions_found := true;
	for idx in 0..< len(device_extensions) {
		extension_found := false;
		device_extension := device_extensions[idx];
		for jdx in 0..< num_extension_properties {
			available_extension := string(cast(cstring) &extension_properties[jdx].extensionName[0]);
			device_extension_str := string(device_extension);
			if (strings.compare(available_extension, device_extension_str) == 0) {
				extension_found = true;
				break;
			}
		}
		if (!extension_found) {
			all_extensions_found = false;
			break;
		}
	}
	assert(all_extensions_found);
	delete(extension_properties);



	format_count :u32 = 0;
	vk.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, nil);

	formats := make([]vk.VkSurfaceFormatKHR, format_count);
	vk.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, &formats[0]);
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
	vk.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_modes_count, nil);

	present_modes := make([]vk.VkPresentModeKHR, present_modes_count);
	vk.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_modes_count, &present_modes[0]);
	assert(present_modes_count > 0);


	present_mode := vk.VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
	for idx in 0..<present_modes_count {
		if (present_modes[idx] == .VK_PRESENT_MODE_MAILBOX_KHR) {
			present_mode = .VK_PRESENT_MODE_MAILBOX_KHR;
		}
	}

	delete(present_modes);


	WIDTH:: 800;
	HEIGHT:: 600;

	capabilities :vk.VkSurfaceCapabilitiesKHR = ---;
	vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &capabilities);

	surface_extents := vk.VkExtent2D{WIDTH, HEIGHT};
	assert(surface_extents.width >= capabilities.minImageExtent.width);
	assert(surface_extents.width <= capabilities.maxImageExtent.width);
	assert(surface_extents.height >= capabilities.minImageExtent.height);
	assert(surface_extents.height <= capabilities.maxImageExtent.height);

	image_count :u32 = capabilities.minImageCount + 1;
	if (capabilities.maxImageCount != 0) {
		assert(image_count <= capabilities.maxImageCount);
	}

	swapchain_info := vk.VkSwapchainCreateInfoKHR {};
	swapchain_info.sType = .VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
	swapchain_info.surface = surface;
	// VkSwapchainCreateFlagsKHR          flags;
	swapchain_info.minImageCount = image_count;
	swapchain_info.imageFormat = desired_format.format;
	swapchain_info.imageColorSpace = desired_format.colorSpace;
	swapchain_info.imageExtent = surface_extents;
	swapchain_info.imageArrayLayers = 1;
	swapchain_info.imageUsage = .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

	queue_indices := []u32 {graphics_queue_family_idx, present_queue_family_idx};
	if (graphics_queue_family_idx != present_queue_family_idx) {
		swapchain_info.imageSharingMode = .VK_SHARING_MODE_CONCURRENT;
		swapchain_info.queueFamilyIndexCount = 2;
		swapchain_info.pQueueFamilyIndices = &queue_indices[0];
	} else {
		swapchain_info.imageSharingMode = .VK_SHARING_MODE_EXCLUSIVE;
		swapchain_info.queueFamilyIndexCount = 0;
		swapchain_info.pQueueFamilyIndices = nil;
	}

	swapchain_info.preTransform = capabilities.currentTransform;
	swapchain_info.compositeAlpha = .VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
	swapchain_info.presentMode = present_mode;
	swapchain_info.clipped = true;
	swapchain_info.oldSwapchain = nil;


	device_features := vk.VkPhysicalDeviceFeatures {};


	device_info := vk.VkDeviceCreateInfo {};
	device_info.sType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
	device_info.pQueueCreateInfos = &queue_infos[0];
	device_info.queueCreateInfoCount = len(queue_infos);

	device_info.pEnabledFeatures = &device_features;
	device_info.enabledExtensionCount = u32(len(device_extensions));
	device_info.ppEnabledExtensionNames = &device_extensions[0];

	device :vk.VkDevice = ---;

	r = vk.vkCreateDevice(physical_device, &device_info, nil, &device);
	assert(r == .VK_SUCCESS);
	fmt.println("Created vulkan device");

	swapchain :vk.VkSwapchainKHR = ---;
	r = vk.vkCreateSwapchainKHR(device, &swapchain_info, nil, &swapchain);

	swapchain_image_count :u32 = 0;
	vk.vkGetSwapchainImagesKHR(device, swapchain, &swapchain_image_count, nil);

	swapchain_images := make([]vk.VkImage, swapchain_image_count);

	vk.vkGetSwapchainImagesKHR(device, swapchain, &swapchain_image_count, &swapchain_images[0]);

	swapchain_image_views := make([]vk.VkImageView, swapchain_image_count);

	image_view_info := vk.VkImageViewCreateInfo {};
	image_view_info.sType = .VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
	image_view_info.viewType = .VK_IMAGE_VIEW_TYPE_2D;
	image_view_info.format = desired_format.format;
	image_view_info.components.r = .VK_COMPONENT_SWIZZLE_IDENTITY;
	image_view_info.components.g = .VK_COMPONENT_SWIZZLE_IDENTITY;
	image_view_info.components.b = .VK_COMPONENT_SWIZZLE_IDENTITY;
	image_view_info.components.a = .VK_COMPONENT_SWIZZLE_IDENTITY;
	image_view_info.subresourceRange.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
	image_view_info.subresourceRange.baseMipLevel = 0;
	image_view_info.subresourceRange.levelCount = 1;
	image_view_info.subresourceRange.baseArrayLayer = 0;
	image_view_info.subresourceRange.layerCount = 1;

	for idx in 0..<swapchain_image_count {
		image_view_info.image = swapchain_images[idx];
		r = vk.vkCreateImageView(device, &image_view_info, nil, &swapchain_image_views[idx]);
		assert(r == .VK_SUCCESS);
	}

	graphics_queue :vk.VkQueue = ---;
	vk.vkGetDeviceQueue(device, graphics_queue_family_idx, 0, &graphics_queue);

	present_queue :vk.VkQueue = ---;
	vk.vkGetDeviceQueue(device, present_queue_family_idx, 0, &present_queue);



	vertex_spv, success := os.read_entire_file("content/vert.spv");
	assert(success);

	fragment_spv, success2 := os.read_entire_file("content/frag.spv");
	assert(success2);

	vertex_shader_info := vk.VkShaderModuleCreateInfo {};
	vertex_shader_info.sType = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
	vertex_shader_info.codeSize = u64(len(vertex_spv));
	vertex_shader_info.pCode = (^u32) (&vertex_spv[0]);


	fragment_shader_info := vk.VkShaderModuleCreateInfo {};
	fragment_shader_info.sType = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
	fragment_shader_info.codeSize = u64(len(fragment_spv));
	fragment_shader_info.pCode = (^u32)( &fragment_spv[0] );


	VK_CHECK :: proc(res: vk.VkResult) {
		assert(res == .VK_SUCCESS);
	}

	vertex_shader_module :vk.VkShaderModule = ---;
	fragment_shader_module :vk.VkShaderModule = ---;
	VK_CHECK(vk.vkCreateShaderModule(device, &vertex_shader_info, nil, &vertex_shader_module));
	VK_CHECK(vk.vkCreateShaderModule(device, &fragment_shader_info, nil, &fragment_shader_module));

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

	shader_stages := []vk.VkPipelineShaderStageCreateInfo{ vertex_stage_info, fragment_stage_info };

	vertex_info := vk.VkPipelineVertexInputStateCreateInfo {};
	vertex_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
	vertex_info.vertexBindingDescriptionCount = 0;
	vertex_info.pVertexBindingDescriptions = nil;
	vertex_info.vertexAttributeDescriptionCount = 0;
	vertex_info.pVertexAttributeDescriptions = nil;



	assembly_info := vk.VkPipelineInputAssemblyStateCreateInfo {};
	assembly_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
	assembly_info.topology = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
	assembly_info.primitiveRestartEnable = false;

	viewport := vk.VkViewport {};
	viewport.x = 0;
	viewport.y = 0;
	viewport.width = f32(surface_extents.width);
	viewport.height = f32(surface_extents.height);
	viewport.minDepth = 0;
	viewport.maxDepth = 1;

	scissor := vk.VkRect2D {};
	scissor.extent = surface_extents;

	viewport_state := vk.VkPipelineViewportStateCreateInfo {};
	viewport_state.sType = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
	viewport_state.viewportCount = 1;
	viewport_state.pViewports = &viewport;
	viewport_state.scissorCount = 1;
	viewport_state.pScissors = &scissor;

	rasterization_state := vk.VkPipelineRasterizationStateCreateInfo{};
	rasterization_state.sType = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
	rasterization_state.depthClampEnable = false;
	rasterization_state.rasterizerDiscardEnable = false;
	rasterization_state.polygonMode = .VK_POLYGON_MODE_FILL;
	rasterization_state.cullMode = .VK_CULL_MODE_BACK_BIT;
	rasterization_state.frontFace = .VK_FRONT_FACE_COUNTER_CLOCKWISE;
	rasterization_state.depthBiasEnable = false;
	// rasterization_state.depthBiasConstantFactor;
	// rasterization_state.depthBiasClamp;
	// rasterization_state.depthBiasSlopeFactor;
	rasterization_state.lineWidth = 1;


	multisample_info := vk.VkPipelineMultisampleStateCreateInfo {};
	multisample_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
	multisample_info.rasterizationSamples = .VK_SAMPLE_COUNT_1_BIT;
	multisample_info.sampleShadingEnable = false;
	// float                    minSampleShading;
	// const  VkSampleMask *     pSampleMask;
	// multisample_info.alphaToCoverageEnable;
	// multisample_info.alphaToOneEnable;

	color_blend_attachment := vk.VkPipelineColorBlendAttachmentState {};
	color_blend_attachment.blendEnable = false;
	// VkBlendFactor            srcColorBlendFactor;
	// VkBlendFactor            dstColorBlendFactor;
	// VkBlendOp                colorBlendOp;
	// VkBlendFactor            srcAlphaBlendFactor;
	// VkBlendFactor            dstAlphaBlendFactor;
	// VkBlendOp                alphaBlendOp;
	color_blend_attachment.colorWriteMask = (
		.VK_COLOR_COMPONENT_R_BIT |
		.VK_COLOR_COMPONENT_G_BIT |
		.VK_COLOR_COMPONENT_B_BIT |
		.VK_COLOR_COMPONENT_A_BIT
	);

	color_blend_info := vk.VkPipelineColorBlendStateCreateInfo {};
	color_blend_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
	color_blend_info.logicOpEnable = false;
	// VkLogicOp                logicOp;
	color_blend_info.attachmentCount = 1;
	color_blend_info.pAttachments = &color_blend_attachment;
	// float                    blendConstants [4];

	dynamic_states := []vk.VkDynamicState {
	    .VK_DYNAMIC_STATE_VIEWPORT,
	    .VK_DYNAMIC_STATE_SCISSOR,
	};

	dynamic_state_info := vk.VkPipelineDynamicStateCreateInfo {};
	dynamic_state_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
 	dynamic_state_info.dynamicStateCount = u32(len(dynamic_states));
	dynamic_state_info.pDynamicStates = &dynamic_states[0];

	pipeline_layout_info := vk.VkPipelineLayoutCreateInfo {};
	pipeline_layout_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
	pipeline_layout_info.setLayoutCount = 0;
	pipeline_layout_info.pSetLayouts = nil;
	pipeline_layout_info.pushConstantRangeCount = 0;
	pipeline_layout_info.pPushConstantRanges = nil;

	pipeline_layout :vk.VkPipelineLayout = ---;
	VK_CHECK(vk.vkCreatePipelineLayout(device, &pipeline_layout_info, nil, &pipeline_layout));

	attachment_description := vk.VkAttachmentDescription {};
	attachment_description.format = desired_format.format;
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
	VK_CHECK(vk.vkCreateRenderPass(device, &render_pass_info, nil, &render_pass));

	graphics_pipeline_info := vk.VkGraphicsPipelineCreateInfo {};
	graphics_pipeline_info.sType = .VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
	graphics_pipeline_info.stageCount = u32(len(shader_stages));
	graphics_pipeline_info.pStages = &shader_stages[0];
	graphics_pipeline_info.pVertexInputState = &vertex_info;
	graphics_pipeline_info.pInputAssemblyState = &assembly_info;
	// const  VkPipelineTessellationStateCreateInfo *  pTessellationState;
	graphics_pipeline_info.pViewportState = &viewport_state;
	graphics_pipeline_info.pRasterizationState = &rasterization_state;
	graphics_pipeline_info.pMultisampleState = &multisample_info;
	// const  VkPipelineDepthStencilStateCreateInfo *  pDepthStencilState;
	graphics_pipeline_info.pColorBlendState = &color_blend_info;
	graphics_pipeline_info.pDynamicState = &dynamic_state_info;
	graphics_pipeline_info.layout = pipeline_layout;
	graphics_pipeline_info.renderPass = render_pass;
	graphics_pipeline_info.subpass = 0;
	graphics_pipeline_info.basePipelineHandle = nil;
	graphics_pipeline_info.basePipelineIndex = -1;

	pipeline_cache_info := vk.VkPipelineCacheCreateInfo {};
	pipeline_cache_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO;
	pipeline_cache_info.initialDataSize = 0;
	pipeline_cache_info.pInitialData = nil;

	pipeline_cache :vk.VkPipelineCache = ---;
	VK_CHECK(vk.vkCreatePipelineCache(device, &pipeline_cache_info, nil, &pipeline_cache));

	pipeline :vk.VkPipeline = ---;
	VK_CHECK(vk.vkCreateGraphicsPipelines(device, pipeline_cache, 1, &graphics_pipeline_info, nil, &pipeline));



	framebuffers := make([]vk.VkFramebuffer, swapchain_image_count);

	framebuffer_info := vk.VkFramebufferCreateInfo {};
	framebuffer_info.sType = .VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
	framebuffer_info.renderPass = render_pass;
	framebuffer_info.attachmentCount = 1;
	framebuffer_info.layers = 1;
	for idx in 0..< swapchain_image_count {
		framebuffer_info.pAttachments = &swapchain_image_views[idx];
		framebuffer_info.width = surface_extents.width;
		framebuffer_info.height = surface_extents.height;
		VK_CHECK(vk.vkCreateFramebuffer(device, &framebuffer_info, nil, &framebuffers[idx]));
	}


	graphics_command_pool_info := vk.VkCommandPoolCreateInfo {};
	graphics_command_pool_info.sType = .VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
	graphics_command_pool_info.queueFamilyIndex = graphics_queue_family_idx;
	graphics_command_pool_info.flags = .VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;

	graphics_command_pool :vk.VkCommandPool = ---;
	vk.vkCreateCommandPool(device, &graphics_command_pool_info, nil, &graphics_command_pool);

	// VkCommandPoolCreateInfo present_command_pool_info {};
	// present_command_pool_info.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
	// present_command_pool_info.queueFamilyIndex = present_queue_family_idx;
	// VkCommandPool present_command_pool;
	// vkCreateCommandPool(device, &present_command_pool_info, nil, &present_command_pool);

	command_buffer_info := vk.VkCommandBufferAllocateInfo {};
	command_buffer_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
	command_buffer_info.commandPool = graphics_command_pool;
	command_buffer_info.level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY;
	command_buffer_info.commandBufferCount = swapchain_image_count;

	command_buffers := make([]vk.VkCommandBuffer, swapchain_image_count);

	vk.vkAllocateCommandBuffers(device, &command_buffer_info, &command_buffers[0]);


	command_buffer_begin_info := vk.VkCommandBufferBeginInfo {};
	command_buffer_begin_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

	render_pass_begin_info := vk.VkRenderPassBeginInfo {};
	render_pass_begin_info.sType = .VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
	render_pass_begin_info.renderPass = render_pass;
	clear_color := vk.VkClearValue {};
	clear_color.color.float32 = [4]f32 {0., 0., 0., 1.};
	render_pass_begin_info.clearValueCount = 1;
	render_pass_begin_info.pClearValues = &clear_color;

	for idx in 0..< swapchain_image_count {
		command_buffer := command_buffers[idx];

		VK_CHECK(vk.vkBeginCommandBuffer(command_buffer, &command_buffer_begin_info));

		render_pass_begin_info.framebuffer = framebuffers[idx];
		render_pass_begin_info.renderArea.extent = surface_extents;

		vk.vkCmdBeginRenderPass(command_buffer, &render_pass_begin_info, .VK_SUBPASS_CONTENTS_INLINE);

		vk.vkCmdSetViewport(command_buffer, 0, 1, &viewport);
		vk.vkCmdSetScissor(command_buffer, 0, 1, &scissor);
		vk.vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
		vk.vkCmdDraw(command_buffer, 3, 1, 0, 0);

		vk.vkCmdEndRenderPass(command_buffer);
		VK_CHECK(vk.vkEndCommandBuffer(command_buffer));
	}

	MAX_FRAMES_IN_FLIGHT :: 2;

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
		VK_CHECK(vk.vkCreateSemaphore(device, &semaphore_info, nil, &image_available_semaphore[idx]));
		VK_CHECK(vk.vkCreateSemaphore(device, &semaphore_info, nil, &render_finished_semaphore[idx]));

		VK_CHECK(vk.vkCreateFence(device, &fence_info, nil, &in_flight_fences[idx]));
	}

	current_frame := 0;


	for !glfw.window_should_close(win) {
		glfw.poll_events();

		vk.vkWaitForFences(device, 1, &in_flight_fences[current_frame], true, bits.U64_MAX);

		image_index :u32 = ---;
		vk.vkAcquireNextImageKHR(device, swapchain, bits.U64_MAX, image_available_semaphore[current_frame], nil, &image_index);


		if (image_fences[image_index] != nil) {
			vk.vkWaitForFences(device, 1, &image_fences[image_index], true, bits.U64_MAX);
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

		vk.vkResetFences(device, 1, &in_flight_fences[current_frame]);
		VK_CHECK(vk.vkQueueSubmit(graphics_queue, 1, &submit_info, in_flight_fences[current_frame]));

		present_info := vk.VkPresentInfoKHR{};
		present_info.sType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
		present_info.waitSemaphoreCount = 1;
		present_info.pWaitSemaphores = &render_finished_semaphore[current_frame];
		present_info.swapchainCount = 1;
		present_info.pSwapchains = &swapchain;
		present_info.pImageIndices = &image_index;
		present_info.pResults = nil;

		present_result := vk.vkQueuePresentKHR(present_queue, &present_info);

		if (present_result != .VK_SUCCESS) {
			fmt.println("present result is:", present_result);

			vk.vkDeviceWaitIdle(device);

			// recreate_swapchain();

			width, height := glfw.get_framebuffer_size(win);
			// glfwWaitEvents();
			// vkFreeCommandBuffers(device, graphics_command_pool, swapchain_image_count, command_buffers);

			for idx in 0..< swapchain_image_count {
				vk.vkDestroyFramebuffer(device, framebuffers[idx], nil);
				vk.vkDestroyImageView(device, swapchain_image_views[idx], nil);
			}

			vk.vkDestroySwapchainKHR(device, swapchain, nil);

			surface_extents.width = u32(width);
			surface_extents.height = u32(height);
			swapchain_info.imageExtent = surface_extents;
			VK_CHECK(vk.vkCreateSwapchainKHR(device, &swapchain_info, nil, &swapchain));

			vk.vkGetSwapchainImagesKHR(device, swapchain, &swapchain_image_count, nil);
			vk.vkGetSwapchainImagesKHR(device, swapchain, &swapchain_image_count, &swapchain_images[0]);

			for idx in 0..< swapchain_image_count {
				image_view_info.image = swapchain_images[idx];
				VK_CHECK(vk.vkCreateImageView(device, &image_view_info, nil, &swapchain_image_views[idx]));
			}

			for idx in 0..< swapchain_image_count {
				framebuffer_info.pAttachments = &swapchain_image_views[idx];
				framebuffer_info.width = surface_extents.width;
				framebuffer_info.height = surface_extents.height;
				VK_CHECK(vk.vkCreateFramebuffer(device, &framebuffer_info, nil, &framebuffers[idx]));
			}

			// vkAllocateCommandBuffers(device, &command_buffer_info, command_buffers);

			for idx in 0..< swapchain_image_count {
				command_buffer := command_buffers[idx];

				VK_CHECK(vk.vkBeginCommandBuffer(command_buffer, &command_buffer_begin_info));

				render_pass_begin_info.framebuffer = framebuffers[idx];
				render_pass_begin_info.renderArea.extent = surface_extents;

				vk.vkCmdBeginRenderPass(command_buffer, &render_pass_begin_info, .VK_SUBPASS_CONTENTS_INLINE);

				viewport.width = f32(surface_extents.width);
				viewport.height = f32(surface_extents.height);
				scissor.extent = surface_extents;

				vk.vkCmdSetViewport(command_buffer, 0, 1, &viewport);
				vk.vkCmdSetScissor(command_buffer, 0, 1, &scissor);
				vk.vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);

				// test if setting viewpor here is different

				vk.vkCmdDraw(command_buffer, 3, 1, 0, 0);

				vk.vkCmdEndRenderPass(command_buffer);
				VK_CHECK(vk.vkEndCommandBuffer(command_buffer));
			}

		}

		current_frame = (current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
	}
}


