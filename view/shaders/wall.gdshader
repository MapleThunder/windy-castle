// Rock walls: chunky stone grain with a bevel (lit top-left, shaded bottom-right) so walls read as raised.
shader_type canvas_item;

uniform float grain = 0.12;
uniform float bevel = 0.12;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;
	vec2 local = fract(world_pos / 32.0);
	float stone = hash(floor(world_pos / 4.0)) - 0.5;
	float shade = 1.0 + stone * 2.0 * grain;
	if (local.x < bevel || local.y < bevel) shade *= 1.18;
	if (local.x > 1.0 - bevel || local.y > 1.0 - bevel) shade *= 0.72;
	c.rgb *= shade * 0.8;
	COLOR = c;
}
