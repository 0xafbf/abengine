
package vulkan_bindings

import "core:fmt"


CHECK :: proc(res: VkResult) {
	// TODO: make this with conditional compilation?
	if (res != .VK_SUCCESS) {
		fmt.println("failed with error code:", res, int(res));
	}
	assert(res == .VK_SUCCESS);
}
