#version 450
#extension GL_ARB_separate_shader_objects : enable


layout(binding = 1) uniform sampler2D tex_sampler;
layout(location = 0) in vec2 uv;

layout(location = 0) out vec4 out_color;

void main() {
	vec4 r = texture(tex_sampler, uv);
	vec3 color = r.xxx;
	out_color = vec4(color, r.x);
}
