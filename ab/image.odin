package ab

import "core:fmt"
import vk "shared:odin-vulkan"
// import "shared:odin-stb/stbtt"




Image :: struct {
	handle :vk.VkImage,
	width: u32,
	height: u32,
	format: vk.VkFormat,
}

create_image :: proc(width, height :u32, format: vk.VkFormat) -> Image {

	img_info := vk.VkImageCreateInfo {};
	img_info.sType = .VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;//: VkStructureType,
	// img_info.pNext = //: rawptr,
	// img_info.flags = //: VkImageCreateFlags,
	img_info.imageType = .VK_IMAGE_TYPE_2D;//: VkImageType,
	img_info.format = format;//: VkFormat,
	img_info.extent = {width, height, 1};//: VkExtent3D,
	img_info.mipLevels = 1;//: u32,
	img_info.arrayLayers = 1;//: u32,
	img_info.samples = .VK_SAMPLE_COUNT_1_BIT;//: VkSampleCountFlagBits,
	img_info.tiling = .VK_IMAGE_TILING_OPTIMAL;//: VkImageTiling,
	img_info.usage = .VK_IMAGE_USAGE_TRANSFER_DST_BIT | .VK_IMAGE_USAGE_SAMPLED_BIT;
	img_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;//: VkSharingMode,
	// img_info.queueFamilyIndexCount = //: u32,
	// img_info.pQueueFamilyIndices = //: ^u32,
	img_info.initialLayout = .VK_IMAGE_LAYOUT_UNDEFINED;//: VkImageLayout,

	image :vk.VkImage = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreateImage(ctx.device, &img_info, nil, &image));



	img_mem_requirements :vk.VkMemoryRequirements = ---;
	vk.vkGetImageMemoryRequirements(ctx.device, image, &img_mem_requirements);

	alloc_info := vk.VkMemoryAllocateInfo {};
	alloc_info.sType = .VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
	alloc_info.allocationSize = img_mem_requirements.size;

	mem_properties :vk.VkPhysicalDeviceMemoryProperties = ---;
	vk.vkGetPhysicalDeviceMemoryProperties(ctx.physical_device, &mem_properties);

	properties :vk.VkMemoryPropertyFlags = .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
	memory_type_idx :u32 = ---;
	for idx in 0..<mem_properties.memoryTypeCount {
		if img_mem_requirements.memoryTypeBits & 1<<idx != 0 {
			memory_type := mem_properties.memoryTypes[idx];
			if (memory_type.propertyFlags & properties) == properties {
				memory_type_idx = idx;
				break;
			}
		}
	}

	alloc_info.memoryTypeIndex = memory_type_idx;

	image_memory :vk.VkDeviceMemory = ---;
	vk.CHECK(vk.vkAllocateMemory(ctx.device, &alloc_info, nil, &image_memory) );
	vk.vkBindImageMemory(ctx.device, image, image_memory, 0);


	retval := Image {
		handle=image,
		width=width,
		height=height,
		format=format,
	};


	return retval;
}



transition_image_layout :: proc(
	image: vk.VkImage,
	format: vk.VkFormat,
	old_layout: vk.VkImageLayout,
	new_layout: vk.VkImageLayout,
	pool: vk.VkCommandPool,
	queue: vk.VkQueue,
) {
	cmd_buffer := begin_single_use_command_buffer(pool);

	barrier := vk.VkImageMemoryBarrier {};
	barrier.sType = .VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
	barrier.oldLayout = old_layout;
	barrier.newLayout = new_layout;
	barrier.srcQueueFamilyIndex = 0;
	barrier.dstQueueFamilyIndex = 0;

	barrier.image = image;
	barrier.subresourceRange.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
	barrier.subresourceRange.baseMipLevel = 0;
	barrier.subresourceRange.levelCount = 1;
	barrier.subresourceRange.baseArrayLayer = 0;
	barrier.subresourceRange.layerCount = 1;

	source_stage, destination_stage :vk.VkPipelineStageFlags;

	if (old_layout == .VK_IMAGE_LAYOUT_UNDEFINED
		&& new_layout == .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
	) {
		barrier.srcAccessMask = auto_cast 0;
		barrier.dstAccessMask = .VK_ACCESS_TRANSFER_WRITE_BIT;
		source_stage = .VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
		destination_stage = .VK_PIPELINE_STAGE_TRANSFER_BIT;
	} else if (old_layout == .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
		&& new_layout == .VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
	) {
		barrier.srcAccessMask = .VK_ACCESS_TRANSFER_WRITE_BIT;
		barrier.dstAccessMask = .VK_ACCESS_SHADER_READ_BIT;
		source_stage = .VK_PIPELINE_STAGE_TRANSFER_BIT;
		destination_stage = .VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
	} else {
		fmt.println("ERROR");
	}

	vk.vkCmdPipelineBarrier(cmd_buffer,
		source_stage, destination_stage,
		auto_cast 0,
		0, nil,
		0, nil,
		1, &barrier
	);

	end_single_use_command_buffer(cmd_buffer, queue, pool);
}

copy_buffer_to_image :: proc(
	buffer: vk.VkBuffer,
	image: vk.VkImage,
	width, height: u32,
	pool: vk.VkCommandPool,
	queue: vk.VkQueue,
) {
	cmd_buffer := begin_single_use_command_buffer(pool);

	region := vk.VkBufferImageCopy {};
	region.bufferOffset = 0;
	region.bufferRowLength = 0;
	region.bufferImageHeight = 0;

	region.imageSubresource.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
	region.imageSubresource.mipLevel = 0;
	region.imageSubresource.baseArrayLayer = 0;
	region.imageSubresource.layerCount = 1;

	region.imageOffset = {0,0,0};
	region.imageExtent = {width, height, 1};

	vk.vkCmdCopyBufferToImage(cmd_buffer, buffer, image, .VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);

	end_single_use_command_buffer(cmd_buffer, queue, pool);
}


create_image_view :: proc(image :vk.VkImage, format: vk.VkFormat) -> vk.VkImageView {

	image_view_info := vk.VkImageViewCreateInfo {};
	image_view_info.sType = .VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;// VkStructureType,
	// image_view_info.pNext = // rawptr,
	// image_view_info.flags = // VkImageViewCreateFlags,
	image_view_info.image = image;// VkImage,
	image_view_info.viewType = .VK_IMAGE_VIEW_TYPE_2D;// VkImageViewType,
	image_view_info.format = format;// VkFormat,
	// image_view_info.components = {} // VkComponentMapping,
	// image_view_info.subresourceRange = // VkImageSubresourceRange,
	image_view_info.subresourceRange.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
	image_view_info.subresourceRange.baseMipLevel = 0;
	image_view_info.subresourceRange.levelCount = 1;
	image_view_info.subresourceRange.baseArrayLayer = 0;
	image_view_info.subresourceRange.layerCount = 1;

	img_view :vk.VkImageView = ---;
	ctx := get_context();
	vk.CHECK(vk.vkCreateImageView(ctx.device, &image_view_info, nil, &img_view));
	return img_view;
}
