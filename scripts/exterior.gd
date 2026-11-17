extends Node3D
## Handle the exterior logic (with panoramic view).

@export_group("Travelling")
## Duration of camera movement to the cabin.
@export var travel_duration: float = 2.2
## At what point of the movement the fade-out should start (0 = at beginning / 1 = at end).
@export_range(0.0, 0.95, 0.05) var fade_start_ratio: float = 0.55

@export_group("Parallax")
## If the parallax effect is active or not.
@export var parallax_enabled: bool = true
## How much the camera is moving away from it's initial point.
@export var parallax_strength: float = 0.012
## How much the camera should keep up with the mouse.
@export var parallax_smoothing: float = 3.0

@onready var camera: Camera3D = $Camera3D
@onready var arrival: Marker3D = $CameraArrival
@onready var house_zone: Area3D = $HouseClickZone
@onready var enter_button: Button = $UI/EnterButton

var _is_entering: bool = false
var _rest_transform: Transform3D
var _travel_from: Transform3D
var _travel_to: Transform3D
var _quat_from: Quaternion
var _quat_to: Quaternion


func _ready() -> void:
	# let the mouse be detected inside any area3D
	get_viewport().physics_object_picking = true

	_rest_transform = camera.transform

	## signals connection for exit logic
	enter_button.pressed.connect(enter_house)
	house_zone.input_event.connect(_on_house_input_event)
	house_zone.mouse_entered.connect(_on_house_mouse_entered)
	house_zone.mouse_exited.connect(_on_house_mouse_exited)


#region Parallax
## Handle the parallax logic, if enabled.
func _process(delta: float) -> void:
	if _is_entering or not parallax_enabled:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	# Mouse position is bringed back to [-1, 1] from the center of the screen.
	var raw: Vector2 = (get_viewport().get_mouse_position() / viewport_size) * 2.0 - Vector2.ONE
	var centered := Vector2(clampf(raw.x, -1.0, 1.0), clampf(raw.y, -1.0, 1.0))

	## offset of camera axis
	var offset := Vector3(-centered.x, centered.y, 0.0) * parallax_strength
	var desired: Transform3D = _rest_transform.translated_local(offset)
	camera.transform = camera.transform.interpolate_with(
		desired, clampf(parallax_smoothing * delta, 0.0, 1.0)
	)

#endregion
#region Cabin entrance

## Called when an input is detected on the cabin mesh (e.g. mouse click).
func _on_house_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		enter_house()

## Change the mouse cursor into a pointing hand (if the user isn't already entering).
func _on_house_mouse_entered() -> void:
	if not _is_entering:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

## Turn back the mouse cursor into the default arrow.
func _on_house_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

## Enter the house.
func enter_house() -> void:
	if _is_entering:
		return # prevent from entering multiple times in a row
	_is_entering = true
	enter_button.disabled = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	_travel_from = camera.global_transform
	_travel_to = arrival.global_transform
	_quat_from = _travel_from.basis.get_rotation_quaternion()
	_quat_to = _travel_to.basis.get_rotation_quaternion()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_apply_travel, 0.0, 1.0, travel_duration)

	## the fade effect start before the camera reach the end of the tween
	var fade_delay: float = travel_duration * fade_start_ratio
	var fade_duration: float = maxf(travel_duration - fade_delay, 0.2)

	await get_tree().create_timer(fade_delay).timeout
	
	await Game.fade_to_black(fade_duration)
	Game.change_world(Game.INTERIOR_SCENE)


## Interpolate position and orientation separately: a linear interpolation
## of the complete matrix would distort the basis during rotation.
func _apply_travel(t: float) -> void:
	var rotation_basis := Basis(_quat_from.slerp(_quat_to, t))
	camera.global_transform = Transform3D(rotation_basis, _travel_from.origin.lerp(_travel_to.origin, t))

#endregion
