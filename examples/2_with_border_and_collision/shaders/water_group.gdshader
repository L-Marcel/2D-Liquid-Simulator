shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 water_color : source_color;
uniform vec4 border_color : source_color;
uniform float border_mask_alpha : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

void fragment() {
	COLOR = texture(screen_texture, SCREEN_UV);

	if (COLOR.a > 0.0) {
		if (COLOR.a >= border_mask_alpha) {
			COLOR = water_color;
		} else {
			COLOR = border_color;
		}
	}
}