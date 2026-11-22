@tool
extends WorldEnvironment
## Pushes the current time of day on the interior lighting. The daylight coming
## through the windows follows the sun, while the lamps do the opposite: the
## content of the portfolio has to stay readable whatever time it is outside.

## Shared look of the day, also used by the exterior.
@export var palette: DayCyclePalette
@export var window_light: DirectionalLight3D
@export var lamp: OmniLight3D

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


func _ready() -> void:
	if not _resolve():
		return

	if Engine.is_editor_hint():
		_refresh_preview()
		return

	DayCycle.time_changed.connect(_on_time_changed)
	_on_time_changed(DayCycle.day_time)


## Collect the nodes the cycle writes to.
func _resolve() -> bool:
	if window_light == null:
		window_light = get_node_or_null("../SunThroughWindow") as DirectionalLight3D
	if lamp == null:
		lamp = get_node_or_null("../Lamp") as OmniLight3D

	if palette == null or environment == null:
		push_warning("InteriorLighting : palette or environment missing, the day/night cycle stays off.")
		return false
	return true


func _on_time_changed(day_time: float) -> void:
	_apply(day_time, DayCycle.season_factor)


## The season is ignored in the editor: a preview hour is an absolute hour.
func _refresh_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready() or not preview_in_editor:
		return
	if _resolve():
		_apply(fposmod(preview_hours, 24.0) / 24.0, 0.0)


## Apply a normalized time of day (0.0 = midnight, 0.5 = noon) to the room.
func _apply(day_time: float, season: float) -> void:
	environment.ambient_light_color = palette.get_interior_ambient_color(day_time, season)
	environment.ambient_light_energy = palette.get_interior_ambient_energy(day_time, season)

	if window_light != null:
		window_light.light_color = palette.get_sun_color(day_time)
		window_light.light_intensity_lux = palette.get_window_lux(day_time, season)

	if lamp != null:
		lamp.light_intensity_lumens = palette.get_lamp_lumens(day_time, season)
