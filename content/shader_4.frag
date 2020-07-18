#version 450
#extension GL_ARB_separate_shader_objects : enable


layout(binding = 1) uniform sampler2D tex_sampler;


layout(location = 0) in vec2 uv;

layout(location = 0) out vec4 out_color;

void main() {
	out_color = texture(tex_sampler, uv);
}
