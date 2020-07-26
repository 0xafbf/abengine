package ab
import vk "shared:odin-vulkan"



begin_single_use_command_buffer :: proc(pool: vk.VkCommandPool) -> vk.VkCommandBuffer {

	cmd_buffer_info := vk.VkCommandBufferAllocateInfo {};
	cmd_buffer_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
	// cmd_buffer_info.pNext = //: rawptr,
	cmd_buffer_info.commandPool = pool;
	cmd_buffer_info.level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY;
	cmd_buffer_info.commandBufferCount = 1;

	cmd_buffer :vk.VkCommandBuffer = ---;
	ctx := get_context();
	vk.vkAllocateCommandBuffers(ctx.device, &cmd_buffer_info, &cmd_buffer);

	begin_info := vk.VkCommandBufferBeginInfo {};
	begin_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
	begin_info.flags = .VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
	vk.vkBeginCommandBuffer(cmd_buffer, &begin_info);
	return cmd_buffer;
}



end_single_use_command_buffer :: proc(command_buffer: vk.VkCommandBuffer, queue: vk.VkQueue, pool: vk.VkCommandPool
) {
	vk.vkEndCommandBuffer(command_buffer);
	img_submit_info := vk.VkSubmitInfo {};
	img_submit_info.sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO;
	img_submit_info.commandBufferCount = 1;
	cmd_buf := command_buffer;
	img_submit_info.pCommandBuffers = &cmd_buf;

	vk.vkQueueSubmit(queue, 1, &img_submit_info, nil);
	vk.vkQueueWaitIdle(queue);
	ctx := get_context();
	vk.vkFreeCommandBuffers(ctx.device, pool, 1, &cmd_buf);
}



update_command_buffers :: proc (
	swapchain: ^Swapchain,
	command_buffers: []vk.VkCommandBuffer,
	framebuffers: []vk.VkFramebuffer,
	mesh_draw_infos: []Mesh_Draw_Info,
	render_pass: vk.VkRenderPass,
	ui_draw_commands: ^UI_Draw_Commands,
) {

	buffer_sync(ui_draw_commands.text_data.buffer);

	for idx in 0..< swapchain.image_count {
		command_buffer := command_buffers[idx];
		framebuffer := framebuffers[idx];
		begin_command_buffer(command_buffer, render_pass, framebuffer, swapchain);

		last_mesh_geom :^Buffer;

		for mesh_draw_info in mesh_draw_infos {
			last_mesh_geom = mesh_draw_info.mesh.vertex_buffer;
			// draw each thing . . .
			vk.vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, mesh_draw_info.pipeline.pipeline);

			b_offset :vk.VkDeviceSize = 0;
			mesh_info := mesh_draw_info.mesh;
			vk.vkCmdBindVertexBuffers(command_buffer, 0, 1, &mesh_info.vertex_buffer.handle, &b_offset);
			vk.vkCmdBindIndexBuffer(command_buffer, mesh_info.index_buffer.handle, 0, .VK_INDEX_TYPE_UINT32);

			my_descriptor_set := mesh_draw_info.descriptor_set;
			vk.vkCmdBindDescriptorSets(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, mesh_draw_info.pipeline.layout, 0, 1, &my_descriptor_set, 0, nil);

			vk.vkCmdDrawIndexed(command_buffer, mesh_info.index_count, 1, 0, 0, 0);
		}

		ui_collect_commands(command_buffer, ui_draw_commands);

		end_command_buffer(command_buffer);
	}
}
begin_command_buffer :: proc(
	command_buffer :vk.VkCommandBuffer,
	render_pass :vk.VkRenderPass,
	framebuffer :vk.VkFramebuffer,
	swapchain: ^Swapchain,
) {

	command_buffer_begin_info := vk.VkCommandBufferBeginInfo {};
	command_buffer_begin_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

	vk.CHECK(vk.vkBeginCommandBuffer(command_buffer, &command_buffer_begin_info));

	render_pass_begin_info := vk.VkRenderPassBeginInfo {};
	render_pass_begin_info.sType = .VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
	render_pass_begin_info.renderPass = render_pass;
	clear_color := vk.VkClearValue {};
	clear_color.color.float32 = [4]f32 {0., 0., 0.2, 1.};
	render_pass_begin_info.clearValueCount = 1;
	render_pass_begin_info.pClearValues = &clear_color;


	scissor := vk.VkRect2D {};
	scissor.extent = {swapchain.width, swapchain.height};

	render_pass_begin_info.framebuffer = framebuffer;
	render_pass_begin_info.renderArea.extent = scissor.extent;


	vk.vkCmdBeginRenderPass(command_buffer, &render_pass_begin_info, .VK_SUBPASS_CONTENTS_INLINE);

	viewport := vk.VkViewport {};
	viewport.x = 0;
	viewport.y = 0;
	viewport.width = f32(swapchain.width);
	viewport.height = f32(swapchain.height);
	viewport.minDepth = 0;
	viewport.maxDepth = 1;

	vk.vkCmdSetViewport(command_buffer, 0, 1, &viewport);
	vk.vkCmdSetScissor(command_buffer, 0, 1, &scissor);

}
end_command_buffer :: proc(command_buffer: vk.VkCommandBuffer) {


	vk.vkCmdEndRenderPass(command_buffer);
	vk.CHECK(vk.vkEndCommandBuffer(command_buffer));
}

