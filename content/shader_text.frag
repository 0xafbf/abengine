#version 450
#extension GL_ARB_separate_shader_objects : enable


layout(set=1, binding = 0) uniform sampler2D tex_sampler;
layout(location = 0) in vec2 uv;

layout(push_constant) uniform Push_Constants {
    vec4 color;
} push_constants;

layout(location = 0) out vec4 out_color;

void main() {
	vec4 r = texture(tex_sampler, uv);
	vec3 color = r.xxx;
	out_color = vec4(color, r.x) * push_constants.color;
}
