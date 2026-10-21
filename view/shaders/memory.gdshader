// Explored but out of sight: desaturated, dimmed and cooled. Unshaded, so it stays visible in the dark.
shader_type canvas_item;
render_mode unshaded;

uniform vec3 tint = vec3(0.24, 0.26, 0.36);
uniform float desaturate = 0.75;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(lum), desaturate) * tint;
	c.rgb *= 1.0 + (hash(floor(world_pos / 32.0)) - 0.5) * 0.08;
	COLOR = c;
}
