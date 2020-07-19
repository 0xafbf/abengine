#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec4 x0;

layout(location = 1) in vec4 x1;

vec2 positions[6] = vec2[](
    vec2(0,0),
    vec2(0,1),
    vec2(1,1),
    vec2(0,0),
    vec2(1,1),
    vec2(1,0)
);


layout(location = 0) out vec2 uv;

void main() {
	vec2 position = positions[gl_VertexIndex];

	vec4 dx = mix(x0, x1, position.x);
	vec4 dy = mix(x0, x1, position.y);

	vec2 pos = position;
	pos.x *= 0.15;
	pos.x += (0.15 * gl_InstanceIndex);
    // gl_Position = vec4(pos * 0.1, 0, 1);
    gl_Position = vec4(pos, 0, 1);

    uv = vec2(0,0);
    uv.x = dx.z;
    uv.y = dy.w;
    // uv = vec2(position);
}
