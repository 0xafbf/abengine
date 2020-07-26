package ab

import "core:fmt"
import vk "shared:odin-vulkan"

//context.user_ptr = new(Context);
Context :: struct {
	device: vk.VkDevice,
	physical_device: vk.VkPhysicalDevice,
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

