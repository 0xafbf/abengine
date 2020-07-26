#version 450
#extension GL_ARB_separate_shader_objects : enable


layout(binding=0) uniform ViewportData {
    float left;
    float right;
    float top;
    float bottom;
};

layout(push_constant) uniform Push_Constants {
    vec2 position;
    vec2 size;
} push_constants;


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
	uv = positions[gl_VertexIndex];

	vec2 pos = push_constants.position + push_constants.size * uv;

    // apply viewport coordinates
    pos.x = -1 + 2 * pos.x /(right-left);
    pos.y = -1 + 2 * pos.y /(bottom-top);
    gl_Position = vec4(pos, 0, 1);
}
