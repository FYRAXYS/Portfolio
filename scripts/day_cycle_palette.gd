@tool
class_name DayCyclePalette
extends Resource
## Look of a full day, shared by the exterior and the interior so both worlds
## stay consistent. Gradients are sampled with the normalized time of day
## (0.0 = midnight, 0.5 = noon): their first and their last key must hold the
## same color, otherwise the sky jumps at midnight. Scalars are interpolated
## between their night and their day value, see [method get_day_factor].

@export_group("Day length")
## Hour at which the sun is considered up, in the visitor's local time.
@export_range(0.0, 24.0, 0.25) var sunrise_hour: float = 7.0
## Hour at which the sun is considered down.
@export_range(0.0, 24.0, 0.25) var sunset_hour: float = 19.0
## Length of the dawn and dusk blends, in hours.
@export_range(0.25, 6.0, 0.25) var transition_hours: float = 1.5
## How far sunrise and sunset move between winter and summer, in hours.
@export_range(0.0, 3.0, 0.05) var season_amplitude_hours: float = 1.25

@export_group("Sky")
@export var zenith_color: Gradient
## Also used as the ambient color of the exterior: close to the ground, most of
## the ambient light comes from the sky near the horizon.
@export var horizon_color: Gradient
@export var fog_color: Gradient
## Lower half of the sky dome, almost always hidden by the mountains.
@export var ground_color_day: Color = Color(0.09, 0.55, 0.72)
@export var ground_color_night: Color = Color(0.05, 0.07, 0.13)
## Brightness of the sky gradient. First knob to turn if the sky looks flat or blown out.
@export_range(0.0, 8.0, 0.05) var sky_energy_day: float = 1.3
@export_range(0.0, 8.0, 0.05) var sky_energy_night: float = 0.9
@export_range(0.0, 4.0, 0.05) var ambient_energy_day: float = 1.0
@export_range(0.0, 4.0, 0.05) var ambient_energy_night: float = 0.6

@export_group("Sun")
## Color of the sunlight, and of the sun disc drawn in the sky.
@export var sun_color: Gradient
## Elevation at dawn and at dusk, in degrees.
@export_range(-10.0, 90.0, 0.5) var elevation_horizon: float = 3.0
## Elevation at midday, in degrees.
@export_range(-10.0, 90.0, 0.5) var elevation_noon: float = 57.0
## Elevation kept during the night. The light never goes under the horizon: a
## moonlight coming from below would only light the underside of the landscape.
@export_range(0.0, 90.0, 0.5) var elevation_night: float = 18.0
## Azimuth at dawn, in degrees. Both azimuths stay on the camera side so the
## cabin is never backlit.
@export_range(-180.0, 180.0, 1.0) var azimuth_dawn: float = -130.0
## Azimuth at dusk, in degrees.
@export_range(-180.0, 180.0, 1.0) var azimuth_dusk: float = -45.0
@export var sun_lux_day: float = 30000.0
@export var sun_lux_night: float = 1200.0
## Brightness of the sun disc in the sky, faded out during the night.
@export_range(0.0, 40.0, 0.1) var sun_disc_energy: float = 12.0

@export_group("Cabin glow")
## Warm light spilling out of the cabin windows onto the grass once the sun
## is down. The tint is authored on the lights themselves. Not to be confused
## with window_lux_*, which lights the inside of the cabin.
@export var cabin_glow_lumens_day: float = 0.0
@export var cabin_glow_lumens_night: float = 60000.0

@export_group("Stars")
@export_range(0.0, 10.0, 0.05) var star_energy: float = 3.0
## Higher means more stars, but also smaller ones.
@export_range(10.0, 300.0, 1.0) var star_density: float = 80.0
## Share of the sky left empty. 0.96 keeps roughly one cell out of twenty five.
@export_range(0.5, 0.999, 0.001) var star_threshold: float = 0.958

@export_group("Interior")
@export var interior_ambient_day: Color = Color(0.52, 0.48, 0.43)
@export var interior_ambient_night: Color = Color(0.24, 0.21, 0.26)
@export_range(0.0, 4.0, 0.05) var interior_ambient_energy_day: float = 1.2
@export_range(0.0, 4.0, 0.05) var interior_ambient_energy_night: float = 0.8
@export var window_lux_day: float = 6000.0
@export var window_lux_night: float = 250.0
## The lamps are what keeps the content readable at 3 in the morning, so they
## are the one value that goes up when everything else goes down.
@export var lamp_lumens_day: float = 350.0
@export var lamp_lumens_night: float = 1800.0

#region Day factor

## 1.0 in broad daylight, 0.0 in the middle of the night, blended at dawn and dusk.
func get_day_factor(day_time: float, season_factor: float = 0.0) -> float:
	var hours: float = fposmod(day_time, 1.0) * 24.0
	var bounds: Vector2 = get_day_bounds(season_factor)
	var half: float = maxf(transition_hours, 0.01) * 0.5
	var rising: float = smoothstep(bounds.x - half, bounds.x + half, hours)
	var falling: float = smoothstep(bounds.y - half, bounds.y + half, hours)
	return clampf(rising - falling, 0.0, 1.0)


## Opposite of [method get_day_factor]: drives the stars and the lamps.
func get_night_factor(day_time: float, season_factor: float = 0.0) -> float:
	return 1.0 - get_day_factor(day_time, season_factor)


## Sunrise and sunset hours once the season has been taken into account.
func get_day_bounds(season_factor: float = 0.0) -> Vector2:
	var shift: float = season_factor * season_amplitude_hours
	return Vector2(sunrise_hour - shift, sunset_hour + shift)

#endregion
#region Sun

## Euler rotation to give to the sun: it rises, crosses the sky, then stays
## slightly above the horizon during the night. Everything is driven by a single
## phase so the direction never jumps, not even at midnight.
func get_sun_rotation(day_time: float, season_factor: float = 0.0) -> Vector3:
	var hours: float = fposmod(day_time, 1.0) * 24.0
	var bounds: Vector2 = get_day_bounds(season_factor)
	# 0 at sunrise, PI twelve hours later, 2 PI one day later
	var phase: float = TAU * (hours - bounds.x) / 24.0

	var daylight_elevation: float = lerpf(elevation_horizon, elevation_noon, maxf(sin(phase), 0.0))
	var elevation: float = lerpf(elevation_night, daylight_elevation, get_day_factor(day_time, season_factor))
	var azimuth: float = lerpf(azimuth_dawn, azimuth_dusk, 0.5 - 0.5 * cos(phase))
	return Vector3(deg_to_rad(-elevation), deg_to_rad(azimuth), 0.0)


func get_sun_lux(day_time: float, season_factor: float = 0.0) -> float:
	return lerpf(sun_lux_night, sun_lux_day, get_day_factor(day_time, season_factor))


func get_cabin_glow_lumens(day_time: float, season_factor: float = 0.0) -> float:
	return lerpf(cabin_glow_lumens_night, cabin_glow_lumens_day, get_day_factor(day_time, season_factor))


func get_sun_color(day_time: float) -> Color:
	return _sample(sun_color, day_time, Color(1.0, 0.97, 0.94))

#endregion
#region Sky

func get_zenith_color(day_time: float) -> Color:
	return _sample(zenith_color, day_time, Color(0.2, 0.5, 0.88))


func get_horizon_color(day_time: float) -> Color:
	return _sample(horizon_color, day_time, Color(0.58, 0.84, 0.95))


func get_fog_color(day_time: float) -> Color:
	return _sample(fog_color, day_time, Color(0.1, 0.6, 0.95))


func get_ground_color(day_time: float, season_factor: float = 0.0) -> Color:
	return ground_color_night.lerp(ground_color_day, get_day_factor(day_time, season_factor))


func get_sky_energy(day_time: float, season_factor: float = 0.0) -> float:
	return lerpf(sky_energy_night, sky_energy_day, get_day_factor(day_time, season_factor))


func get_ambient_energy(day_time: float, season_factor: float = 0.0) -> float:
	return lerpf(ambient_energy_night, ambient_energy_day, get_day_factor(day_time, season_factor))

#endregion
#region Interior

func get_interior_ambient_color(day_time: float, season_factor: float = 0.0) -> Color:
	return interior_ambient_night.lerp(interior_ambient_day, get_day_factor(day_time, season_factor))


func get_interior_ambient_energy(day_time: float, season_factor: float = 0.0) -> float:
	return lerpf(interior_ambient_energy_night, interior_ambient_energy_day, get_day_factor(day_time, season_factor))


func get_window_lux(day_time: float, season_factor: float = 0.0) -> float:
	return lerpf(window_lux_night, window_lux_day, get_day_factor(day_time, season_factor))


func get_lamp_lumens(day_time: float, season_factor: float = 0.0) -> float:
	return lerpf(lamp_lumens_night, lamp_lumens_day, get_day_factor(day_time, season_factor))


#endregion
#region Internal

## A palette created from scratch starts with empty gradients: fall back on a
## neutral color instead of bringing the whole world down.
func _sample(gradient: Gradient, day_time: float, fallback: Color) -> Color:
	if gradient == null or gradient.get_point_count() == 0:
		return fallback
	return gradient.sample(clampf(day_time, 0.0, 1.0))

#endregion
