package ab

import "core:mem"
import vk "shared:odin-vulkan"


Buffer :: struct {
	handle :vk.VkBuffer,
	memory :vk.VkDeviceMemory,
	size :u64,
	data :rawptr
};

make_buffer :: proc( in_data: rawptr,  size: int, usage: vk.VkBufferUsageFlags) -> Buffer {

	my_buffer := Buffer {
		size = u64(size),
		data = in_data,
	};

	buffer_info := vk.VkBufferCreateInfo {};
	buffer_info.sType = .VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
	buffer_info.pNext = nil;
	buffer_info.size = my_buffer.size;
	buffer_info.usage = usage;
	buffer_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;

	buffer :vk.VkBuffer = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreateBuffer(ctx.device, &buffer_info, nil, &buffer));
	my_buffer.handle = buffer;
	mem_requirements :vk.VkMemoryRequirements = ---;
	vk.vkGetBufferMemoryRequirements(ctx.device, buffer, &mem_requirements);


	mem_properties :vk.VkPhysicalDeviceMemoryProperties = ---;
	vk.vkGetPhysicalDeviceMemoryProperties(ctx.physical_device, &mem_properties);

	type_index :u32 = ---;
	found := false;
	for idx in 0..<mem_properties.memoryTypeCount {
		mem_type := mem_properties.memoryTypes[idx];
		mask := (vk.VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
		if (mem_type.propertyFlags & mask) == mask{
			type_index = idx;
			found = true;
			break;
		}
	}
	assert(found);


	alloc_info := vk.VkMemoryAllocateInfo {};
	alloc_info.sType = .VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
	alloc_info.allocationSize = mem_requirements.size;
	alloc_info.memoryTypeIndex = u32(type_index);

	device_memory :vk.VkDeviceMemory = ---;
	vk.CHECK(vk.vkAllocateMemory(ctx.device, &alloc_info, nil, &device_memory));

	my_buffer.memory = device_memory;

	vk.vkBindBufferMemory(ctx.device, buffer, device_memory, 0);
	buffer_sync(&my_buffer);
	return my_buffer;
}

buffer_sync :: proc(buffer :^Buffer){
	data :rawptr = ---;
	ctx := get_context();
	vk.vkMapMemory(ctx.device, buffer.memory, 0, buffer.size, 0, &data);
	mem.copy(data, buffer.data, int(buffer.size));
	vk.vkUnmapMemory(ctx.device, buffer.memory);
}



fill_image_with_buffer :: proc(
	image:^Image, buffer:^Buffer,
	pool:vk.VkCommandPool, queue:vk.VkQueue,
) {

	transition_image_layout(
		image.handle,
		image.format,
		.VK_IMAGE_LAYOUT_UNDEFINED,
		.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		pool,
		queue,
	);

	copy_buffer_to_image(
		buffer.handle,
		image.handle,
		image.width,
		image.height,
		pool,
		queue,
	);

	transition_image_layout(
		image.handle,
		image.format,
		.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
		pool,
		queue,
	);
}





copy_buffer :: proc(from, to: vk.VkBuffer, size: vk.VkDeviceSize, pool: vk.VkCommandPool, queue: vk.VkQueue) {
	img_command_buffer := begin_single_use_command_buffer(pool);
	copy_region := vk.VkBufferCopy {};
	copy_region.size = size;
	vk.vkCmdCopyBuffer(img_command_buffer, from, to, 1, &copy_region);

	end_single_use_command_buffer(img_command_buffer, queue, pool);
}
