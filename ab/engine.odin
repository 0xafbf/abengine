package ab

import "core:fmt"
import "core:mem"
import "core:strings"
import vk "shared:odin-vulkan"
import glfw "shared:odin-glfw"
import glfw_bindings "shared:odin-glfw/bindings"

//context.user_ptr = new(Context);
Context :: struct {
	instance: vk.VkInstance,
	device: vk.VkDevice,
	physical_device: vk.VkPhysicalDevice,
	queue_family_count: u32,
	graphics_queue_family_idx: u32,
	present_queue_family_idx: u32,

	graphics_queue: vk.VkQueue,
	present_queue: vk.VkQueue,
	present_queue_found: bool,
};

ab_context: Context;

get_context :: inline proc() -> ^Context {
	return &ab_context;
}

debugCallback :: proc (
	messageSeverity: vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
	messageTypes: vk.VkDebugUtilsMessageTypeFlagsEXT,
	pCallbackData: ^vk.VkDebugUtilsMessengerCallbackDataEXT,
	pUserData: rawptr,
) -> vk.VkBool32 {
	fmt.println(pCallbackData.pMessage, "\n");
	return false;
};

engine_init :: proc() {
	glfw.init();

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

	fmt.println("STAGE 2");

	messenger_info := vk.VkDebugUtilsMessengerCreateInfoEXT{};
	messenger_info.sType = .VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;

	messenger_info.messageSeverity = .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT;

	messenger_info.messageType = .VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |  .VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |  .VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;

	messenger_info.pfnUserCallback = debugCallback;

	instance_info.pNext = &messenger_info;


	instance: vk.VkInstance = ---;

	vk.CHECK(vk.vkCreateInstance(&instance_info, nil, &instance));
	get_context().instance = instance;

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

	physical_device := physical_devices[selected_device];

	ab_context.physical_device = physical_device;




	ctx := &ab_context;
	num_extension_properties :u32 = 0;
	vk.vkEnumerateDeviceExtensionProperties(ctx.physical_device, nil, &num_extension_properties, nil);

	extension_properties := make([]vk.VkExtensionProperties, num_extension_properties);

	vk.vkEnumerateDeviceExtensionProperties(ctx.physical_device, nil, &num_extension_properties, &extension_properties[0]);


	device_extensions := []cstring{
		vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
	};

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




	queue_family_count: u32 = ---;
	vk.vkGetPhysicalDeviceQueueFamilyProperties(ctx.physical_device, &queue_family_count, nil);

	ab_context.queue_family_count = queue_family_count;

	queue_family_props := make([]vk.VkQueueFamilyProperties, queue_family_count);
	vk.vkGetPhysicalDeviceQueueFamilyProperties(ctx.physical_device, &queue_family_count, raw_data(queue_family_props));


	queue_infos := make([]vk.VkDeviceQueueCreateInfo, queue_family_count);

	priorities: [10]f32 = {1,1,1,1,1,1,1,1,1,1};

	for idx in 0..<queue_family_count {

		family_props := queue_family_props[idx];

		assert(len(priorities) > family_props.queueCount);

		queue_infos[idx] = {
			sType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = idx,
			queueCount = family_props.queueCount,
			pQueuePriorities = &priorities[0],
		};
	}


	// create device =====================================

	device_features := vk.VkPhysicalDeviceFeatures {};
	device := create_device(queue_infos[:], device_extensions[:], &device_features);
	ab_context.device = device;
	fmt.println("Created vulkan device");





	graphics_queue_family_idx :u32;
	graphics_queue_found := false;

	for idx in 0..<queue_family_count {
		family_props := queue_family_props[idx];
		if (family_props.queueFlags & .VK_QUEUE_GRAPHICS_BIT != auto_cast 0) {
			graphics_queue_family_idx = idx;
			graphics_queue_found = true;
		}
	}

	assert(graphics_queue_found);


	graphics_queue := &ctx.graphics_queue;
	vk.vkGetDeviceQueue(ctx.device, ctx.graphics_queue_family_idx, 0, graphics_queue);

}



create_device :: proc (
	queue_infos: []vk.VkDeviceQueueCreateInfo,
	device_extensions: []cstring,
	device_features: ^vk.VkPhysicalDeviceFeatures,
) -> vk.VkDevice {
	device_info := vk.VkDeviceCreateInfo {};
	device_info.sType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
	device_info.pQueueCreateInfos = raw_data(queue_infos);
	device_info.queueCreateInfoCount = u32(len(queue_infos));

	device_info.pEnabledFeatures = device_features;
	device_info.enabledExtensionCount = u32(len(device_extensions));
	device_info.ppEnabledExtensionNames = raw_data(device_extensions);

	device :vk.VkDevice = ---;

	ctx := get_context();
	vk.CHECK(vk.vkCreateDevice(ctx.physical_device, &device_info, nil, &device));


	return device;
}

