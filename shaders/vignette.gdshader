shader_type canvas_item;
// Darkens the screen edges. Drawn on the HUD layer, under the HUD itself.

uniform float strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.4, 1.0));
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.42, 0.85, d) * strength);
}
