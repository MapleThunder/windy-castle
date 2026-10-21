// Terrain: per-tile brightness variation plus a fine grain, so flat palette tiles read as material.
shader_type canvas_item;

uniform float tile_variation = 0.025;
uniform float grain = 0.05;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;  // already the texture sample times modulate
	float t = hash(floor(world_pos / 32.0)) - 0.5;
	float g = hash(floor(world_pos / 2.0)) - 0.5;
	c.rgb *= 1.0 + t * 2.0 * tile_variation + g * 2.0 * grain;
	COLOR = c;
}
