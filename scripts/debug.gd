extends Control

const TOGGLE_ACTION: StringName = &"debug_toggle"

@onready var debug_label: Label = $MarginContainer/VBoxContainer/Rect/Label
@onready var exit_button: Button = %Exit
@onready var show_perf_check: CheckBox = %ShowPerf
@onready var show_position_check: CheckBox = %ShowPosition
@onready var show_velocity_check: CheckBox = %ShowVelocity
@onready var show_state_check: CheckBox = %ShowState
@onready var pause_game_check: CheckBox = %PauseGame
@onready var speed_x2_check: CheckBox = %SpeedX2
@onready var no_gravity_check: CheckBox = %NoGravity
@onready var noclip_check: CheckBox = %Noclip
@onready var space_velocity_check: CheckBox = %SpaceVelocity

var is_open: bool = false
var player: CharacterBody3D
var player_default_collision_layer: int = 0
var player_default_collision_mask: int = 0
var has_player_defaults: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_ensure_debug_input_action()
	exit_button.pressed.connect(_close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION):
		if is_open:
			_close()
		else:
			_open()


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = _find_player()
		_cache_player_defaults()

	_apply_debug_actions()

	if not is_open:
		return

	if get_tree().paused != pause_game_check.button_pressed:
		get_tree().paused = pause_game_check.button_pressed

	debug_label.text = _build_debug_text()


func _open() -> void:
	is_open = true
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = pause_game_check.button_pressed


func _close() -> void:
	is_open = false
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false


func _find_player() -> CharacterBody3D:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.find_child("CharacterBody3D", true, false) as CharacterBody3D


func _build_debug_text() -> String:
	var fps: int = Engine.get_frames_per_second()
	var frame_ms: float = 1000.0 / max(float(fps), 1.0)

	var lines: PackedStringArray = [
		"DEBUG MODE [F3]"
	]

	if show_perf_check.button_pressed:
		lines.append("FPS: %d" % fps)
		lines.append("Frame Time: %.2f ms" % frame_ms)

	if is_instance_valid(player):
		var pos: Vector3 = player.global_position
		var vel: Vector3 = player.velocity
		var is_sliding_value: Variant = _read_property(player, "is_sliding")

		if show_position_check.button_pressed:
			lines.append("Position: (%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z])

		if show_velocity_check.button_pressed:
			lines.append("Velocity: (%.2f, %.2f, %.2f)" % [vel.x, vel.y, vel.z])

		if show_state_check.button_pressed:
			lines.append("On Floor: %s" % str(player.is_on_floor()))

			if is_sliding_value != null:
				lines.append("Sliding: %s" % str(is_sliding_value))
	else:
		lines.append("Player: not found")

	lines.append("\nESC: release mouse")
	lines.append("EXIT button: close debug")
	lines.append("Speed x2: %s" % _on_off(speed_x2_check.button_pressed))
	lines.append("No gravity: %s" % _on_off(no_gravity_check.button_pressed))
	lines.append("Noclip: %s" % _on_off(noclip_check.button_pressed))
	lines.append("Space velocity: %s" % _on_off(space_velocity_check.button_pressed))

	return "\n".join(lines)


func _apply_debug_actions() -> void:
	if not is_instance_valid(player):
		return

	_set_property_if_exists(player, "debug_speed_multiplier", 2.0 if speed_x2_check.button_pressed else 1.0)

	var disable_gravity: bool = no_gravity_check.button_pressed or noclip_check.button_pressed
	_set_property_if_exists(player, "debug_disable_gravity", disable_gravity)
	_set_property_if_exists(player, "debug_noclip", noclip_check.button_pressed)
	_set_property_if_exists(player, "debug_space_velocity", space_velocity_check.button_pressed)

	if noclip_check.button_pressed:
		player.collision_layer = 0
		player.collision_mask = 0
	else:
		_cache_player_defaults()
		player.collision_layer = player_default_collision_layer
		player.collision_mask = player_default_collision_mask


func _set_property_if_exists(target: Object, property_name: String, value: Variant) -> void:
	for property_data: Dictionary in target.get_property_list():
		if property_data.get("name", "") == property_name:
			target.set(property_name, value)
			return


func _cache_player_defaults() -> void:
	if not is_instance_valid(player):
		return

	if has_player_defaults:
		return

	player_default_collision_layer = player.collision_layer
	player_default_collision_mask = player.collision_mask
	has_player_defaults = true


func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"


func _read_property(target: Object, property_name: String) -> Variant:
	for property_data: Dictionary in target.get_property_list():
		if property_data.get("name", "") == property_name:
			return target.get(property_name)
	return null


func _ensure_debug_input_action() -> void:
	if not InputMap.has_action(TOGGLE_ACTION):
		InputMap.add_action(TOGGLE_ACTION)

	var has_f3_binding: bool = false
	for event: InputEvent in InputMap.action_get_events(TOGGLE_ACTION):
		if event is InputEventKey and event.physical_keycode == KEY_F3:
			has_f3_binding = true
			break

	if not has_f3_binding:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_F3
		InputMap.action_add_event(TOGGLE_ACTION, key_event)

