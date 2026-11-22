shader_type sky;

// Stylized day/night sky: a vertical gradient, a sun disc with its halo and a
// procedural star field. Every value is pushed by sky_cycle.gd from the
// DayCyclePalette, so the look is tuned from the inspector and not from here.
//
// TIME, the radiance passes and the half/quarter res passes are deliberately
// left out: the sky then only has to be redrawn when a uniform changes, which
// happens once per clock poll instead of every frame. It also keeps the shader
// portable to the Compatibility renderer used by the web export.

group_uniforms gradient;
uniform vec3 zenith_color : source_color = vec3(0.2, 0.5, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.58, 0.84, 0.95);
uniform vec3 ground_color : source_color = vec3(0.09, 0.55, 0.72);
uniform float horizon_falloff : hint_range(0.2, 4.0) = 1.6;
uniform float sky_energy : hint_range(0.0, 8.0) = 2.4;

group_uniforms sun;
// Direction of the sun seen from the ground, not the direction it shines at.
uniform vec3 sun_direction = vec3(-0.54, 0.84, 0.03);
uniform vec3 sun_color : source_color = vec3(1.0, 0.98, 0.94);
uniform float sun_energy : hint_range(0.0, 40.0) = 12.0;
uniform float sun_size_deg : hint_range(0.2, 20.0) = 3.0;
uniform float halo_energy : hint_range(0.0, 4.0) = 0.5;
uniform float halo_spread : hint_range(1.0, 200.0) = 32.0;

group_uniforms stars;
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;
uniform float star_density : hint_range(10.0, 300.0) = 80.0;
uniform float star_threshold : hint_range(0.5, 0.999) = 0.958;
uniform float star_energy : hint_range(0.0, 10.0) = 3.0;
// Stars start above the tree line, where nothing in the scene hides them.
uniform float star_min_height : hint_range(0.0, 0.6) = 0.05;

group_uniforms;


float hash12(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

// Round stars on a jittered longitude/latitude grid: cheap, stable from one
// frame to the next, and closer to the stylized reference than a realistic sky.
float star_field(vec3 direction) {
	vec2 cell_space = vec2(atan(direction.z, direction.x), asin(clamp(direction.y, -1.0, 1.0))) * star_density;
	vec2 cell = floor(cell_space);

	float seed = hash12(cell);
	if (seed < star_threshold) {
		return 0.0;
	}

	vec2 jitter = vec2(hash12(cell + 11.3), hash12(cell + 37.7)) - 0.5;
	float distance_to_star = length(fract(cell_space) - 0.5 - jitter * 0.6);
	float radius = 0.16 + 0.24 * fract(seed * 97.0);
	return 1.0 - smoothstep(0.0, radius, distance_to_star);
}

void sky() {
	float height = EYEDIR.y;

	vec3 color = mix(horizon_color, zenith_color, pow(clamp(height, 0.0, 1.0), 1.0 / horizon_falloff));
	color = mix(color, ground_color, 1.0 - smoothstep(-0.1, 0.0, height));
	color *= sky_energy;

	if (star_amount > 0.001 && height > star_min_height) {
		float fade = smoothstep(star_min_height, star_min_height + 0.18, height);
		color += vec3(star_field(EYEDIR)) * star_energy * star_amount * fade;
	}

	float sun_dot = clamp(dot(EYEDIR, normalize(sun_direction)), -1.0, 1.0);
	if (sun_energy > 0.001) {
		float radius = radians(sun_size_deg);
		float disc = 1.0 - smoothstep(radius * 0.55, radius, acos(sun_dot));
		color += sun_color * disc * sun_energy;
	}
	color += sun_color * pow(max(sun_dot, 0.0), halo_spread) * halo_energy;

	// A wide smooth gradient bands quickly, and the Compatibility renderer has
	// no HDR buffer to hide it: a pixel of noise is enough to break it up.
	color += (hash12(SCREEN_UV * 1024.0) - 0.5) / 255.0;

	COLOR = color;
}
