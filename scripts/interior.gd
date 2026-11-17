extends Node3D
## Handle the interior logic (with an isometric view).

@onready var exit_zone: Area3D = $ExitZone
@onready var exit_button: Button = $UI/ExitButton

var _is_leaving: bool = false


func _ready() -> void:
	# let the mouse be detected inside the exit zone
	get_viewport().physics_object_picking = true

	## signals connection for exit logic
	exit_button.pressed.connect(leave_house)
	exit_zone.input_event.connect(_on_exit_zone_input_event)
	exit_zone.mouse_entered.connect(_on_exit_mouse_entered)
	exit_zone.mouse_exited.connect(_on_exit_mouse_exited)

## Called when an input is detected in the zone (e.g. mouse click)
func _on_exit_zone_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		leave_house()

## Change the mouse cursor into a pointing hand (if the user isn't already leaving).
func _on_exit_mouse_entered() -> void:
	if not _is_leaving:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

## Turn back the mouse cursor into the default arrow.
func _on_exit_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

## Leave the house and go back to the exterior.
func leave_house() -> void:
	if _is_leaving:
		return # prevent from leaving multiple times in a row
	_is_leaving = true
	exit_button.disabled = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	await Game.fade_to_black(0.5)
	Game.change_world(Game.EXTERIOR_SCENE, 1.0)
