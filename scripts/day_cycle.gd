extends Node
## Singleton exposing the visitor's local time of day to every world.
## [member day_time] is normalized: 0.0 = midnight, 0.25 = 6:00, 0.5 = noon.
## The clock is only read here, the look that goes with it lives in [DayCyclePalette].

signal time_changed(day_time: float)

## How often the system clock is polled, in seconds.
const POLL_INTERVAL := 30.0
## Query parameter used to force a time on web exports (e.g. "index.html?time=21.5").
const WEB_TIME_PARAM := "time"
## Day of the year used as the summer solstice by the seasonal correction.
const SUMMER_SOLSTICE_DAY := 172.0

## Normalized time of day currently applied to the worlds.
var day_time: float = 0.5
## -1.0 at the winter solstice, 1.0 at the summer one. Used to move sunrise and
## sunset with the seasons instead of keeping them at a fixed hour all year.
var season_factor: float = 0.0
## When >= 0.0, replaces the system clock (day/night toggle, "?time=" parameter, debug key).
var forced_time: float = -1.0

var _elapsed: float = 0.0


func _ready() -> void:
	# the clock keeps running during the transitions, like Game
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh()
	_read_web_override()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < POLL_INTERVAL:
		return
	_elapsed = 0.0
	_refresh()


## Debug shortcut: [kbd]N[/kbd] jumps between noon and midnight. Editor and debug
## builds only, the exported portfolio keeps following the visitor's clock.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_N:
		toggle_night()

#region Public API

## Force a time of day, in hours (0.0 -> 24.0).
func set_forced_hours(hours: float) -> void:
	forced_time = fposmod(hours, 24.0) / 24.0
	_apply(forced_time)


## Give the control back to the visitor's system clock.
func clear_forced_time() -> void:
	forced_time = -1.0
	_elapsed = 0.0
	_refresh()


## Switch between a forced midnight and a forced noon. Meant to be connected to
## a sun/moon button: a visitor coming at 14:00 would never see the night sky.
func toggle_night() -> void:
	set_forced_hours(12.0 if is_night() else 0.0)


## Rough test used by the UI, the exact blending is done by [DayCyclePalette].
func is_night() -> bool:
	return day_time < 0.27 or day_time > 0.81


## Current time as hours (0.0 -> 24.0).
func get_hours() -> float:
	return day_time * 24.0

#endregion
#region Internal

## Read the system clock, unless a time is currently forced.
func _refresh() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	season_factor = _compute_season_factor(int(now.month), int(now.day))
	if forced_time >= 0.0:
		return
	_apply((float(now.hour) + float(now.minute) / 60.0) / 24.0)


func _apply(value: float) -> void:
	if is_equal_approx(value, day_time):
		return
	day_time = value
	time_changed.emit(day_time)


## Days are longer in summer than in winter. This is a cosine over the year, not
## an astronomical computation: the goal is only to avoid a sunset at 19:00 in December.
func _compute_season_factor(month: int, day: int) -> float:
	var day_of_year: float = (float(month) - 1.0) * 30.44 + float(day)
	return cos(TAU * (day_of_year - SUMMER_SOLSTICE_DAY) / 365.0)


## Read "?time=21.5" from the page URL on web exports, so a given hour can be
## shared or captured without waiting for it.
func _read_web_override() -> void:
	if not OS.has_feature("web"):
		return

	var search: Variant = JavaScriptBridge.eval("window.location.search", true)
	if typeof(search) != TYPE_STRING or (search as String).is_empty():
		return

	for pair: String in (search as String).trim_prefix("?").split("&", false):
		var key_value: PackedStringArray = pair.split("=")
		if key_value.size() == 2 and key_value[0] == WEB_TIME_PARAM and key_value[1].is_valid_float():
			set_forced_hours(key_value[1].to_float())
			return

#endregion
