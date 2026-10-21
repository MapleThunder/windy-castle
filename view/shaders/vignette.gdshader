shader_type canvas_item;

uniform float strength = 0.35;
uniform float inner = 0.45;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.41421;
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(inner, 1.0, d) * strength);
}
