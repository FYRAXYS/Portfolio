// Blurs, desaturates and darkens whatever is already on screen.
// Used full screen behind the detail viewer, so the interior stays readable
// as a background without competing with the document in the foreground.
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Transition: 0 keeps the screen untouched, 1 applies the full effect.
uniform float amount : hint_range(0.0, 1.0) = 1.0;
// Radius of the sampling rings, in pixels.
uniform float radius : hint_range(0.0, 32.0) = 9.0;
// Mip level sampled on top of the rings, for a wider blur at no extra cost.
// Kept at 0 by default: the Compatibility renderer used for the web export
// does not always provide mipmaps for the screen texture.
uniform float mip_level : hint_range(0.0, 4.0) = 0.0;
// Remaining color saturation of the background.
uniform float saturation : hint_range(0.0, 1.0) = 0.7;
// Color mixed into the background, its alpha being the mix factor.
uniform vec4 tint : source_color = vec4(0.05, 0.04, 0.07, 0.42);

// Samples per ring, and the angle between two of them (TAU / STEPS).
const int STEPS = 8;
const float ANGLE_STEP = 0.78539816;

void fragment() {
	vec3 original = texture(screen_texture, SCREEN_UV).rgb;

	// Two rings of samples around the pixel, which is enough for a background
	// and keeps a single pass.
	vec2 step_size = SCREEN_PIXEL_SIZE * radius * amount;
	float level = mip_level * amount;
	vec3 sum = textureLod(screen_texture, SCREEN_UV, level).rgb;
	float weight = 1.0;

	for (int i = 0; i < STEPS; i++) {
		float angle = float(i) * ANGLE_STEP;
		vec2 direction = vec2(cos(angle), sin(angle));
		sum += textureLod(screen_texture, SCREEN_UV + direction * step_size, level).rgb;
		sum += textureLod(screen_texture, SCREEN_UV + direction * step_size * 0.55, level).rgb;
		weight += 2.0;
	}

	vec3 blurred = sum / weight;
	float luminance = dot(blurred, vec3(0.2126, 0.7152, 0.0722));
	blurred = mix(vec3(luminance), blurred, saturation);
	blurred = mix(blurred, tint.rgb, tint.a);

	COLOR = vec4(mix(original, blurred, amount), 1.0);
}
