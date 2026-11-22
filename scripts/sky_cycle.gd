@tool
extends Node
## Pushes the current time of day on the exterior sky, sun and fog.
## Attached to the "Environnement" node, right next to the nodes it drives.

## Shared look of the day, also used by the interior.
@export var palette: DayCyclePalette
@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D
## Parent of the lights placed in front of the cabin windows. Every
## OmniLight3D under it is driven, so windows can be added without code.
@export var cabin_glows: Node3D

@export_group("Editor preview")
## Applies [member preview_hours] in the editor viewport. The exported game
## always follows the visitor's clock, whatever is set here.
@export var preview_in_editor: bool = true:
	set(value):
		preview_in_editor = value
		_refresh_preview()
## Hour shown in the editor, so the palette can be tuned without running the game.
@export_range(0.0, 24.0, 0.25) var preview_hours: float = 13.0:
	set(value):
		preview_hours = value
		_refresh_preview()

var _environment: Environment
var _sky_material: ShaderMaterial


func _ready() -> void:
	if not _resolve():
		return

	if Engine.is_editor_hint():
		_refresh_preview()
		return

	# The ambient light is driven from here instead of being read from the sky:
	# a sampled color costs no radiance cubemap, and above all it keeps a
	# readable floor of light once the sun is down.
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	DayCycle.time_changed.connect(_on_time_changed)
	_on_time_changed(DayCycle.day_time)


## Collect the nodes and resources the cycle writes to.
func _resolve() -> bool:
	if world_environment == null:
		world_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if sun == null:
		sun = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if cabin_glows == null:
		cabin_glows = get_node_or_null("../CabinGlows") as Node3D

	if palette == null or world_environment == null or sun == null:
		push_warning("SkyCycle : palette or nodes missing, the day/night cycle stays off.")
		return false

	_environment = world_environment.environment
	if _environment == null or _environment.sky == null:
		push_warning("SkyCycle : the environment has no sky, the day/night cycle stays off.")
		return false

	_sky_material = _environment.sky.sky_material as ShaderMaterial
	if _sky_material == null:
		push_warning("SkyCycle : the sky material is not the ShaderMaterial expected by sky_cycle.gdshader.")
	return true


func _on_time_changed(day_time: float) -> void:
	_apply(day_time, DayCycle.season_factor)


## The season is ignored in the editor: a preview hour is an absolute hour.
func _refresh_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready() or not preview_in_editor:
		return
	if _resolve():
		_apply(fposmod(preview_hours, 24.0) / 24.0, 0.0)


## Light the cabin windows from the outside. The lights are hidden rather than
## left at zero during the day, so they cost nothing when the sun is up.
func _apply_cabin_glow(lumens: float) -> void:
	if cabin_glows == null:
		return
	for child: Node in cabin_glows.get_children():
		var light := child as OmniLight3D
		if light == null:
			continue
		light.visible = lumens > 1.0
		light.light_intensity_lumens = lumens


## Apply a normalized time of day (0.0 = midnight, 0.5 = noon) to the scene.
func _apply(day_time: float, season: float) -> void:
	var day: float = palette.get_day_factor(day_time, season)
	var sun_tint: Color = palette.get_sun_color(day_time)

	sun.rotation = palette.get_sun_rotation(day_time, season)
	sun.light_color = sun_tint
	sun.light_intensity_lux = palette.get_sun_lux(day_time, season)

	_apply_cabin_glow(palette.get_cabin_glow_lumens(day_time, season))

	_environment.ambient_light_color = palette.get_horizon_color(day_time)
	_environment.ambient_light_energy = palette.get_ambient_energy(day_time, season)
	_environment.fog_light_color = palette.get_fog_color(day_time)

	if _sky_material == null:
		return

	_sky_material.set_shader_parameter("zenith_color", palette.get_zenith_color(day_time))
	_sky_material.set_shader_parameter("horizon_color", palette.get_horizon_color(day_time))
	_sky_material.set_shader_parameter("ground_color", palette.get_ground_color(day_time, season))
	_sky_material.set_shader_parameter("sky_energy", palette.get_sky_energy(day_time, season))
	_sky_material.set_shader_parameter("sun_color", sun_tint)
	# The sun node points at the ground, the sky needs the opposite direction.
	_sky_material.set_shader_parameter("sun_direction", sun.global_transform.basis.z)
	_sky_material.set_shader_parameter("sun_energy", palette.sun_disc_energy * day)
	_sky_material.set_shader_parameter("star_amount", 1.0 - day)
	_sky_material.set_shader_parameter("star_energy", palette.star_energy)
	_sky_material.set_shader_parameter("star_density", palette.star_density)
	_sky_material.set_shader_parameter("star_threshold", palette.star_threshold)
