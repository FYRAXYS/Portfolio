class_name FocusController
extends Node
## Drives the interior camera when the user clicks an [InteractiveSpot].
##
## Picking is done here, with a single ray cast against
## [constant InteractiveSpot.SPOT_LAYER], so only the spots of the active level
## can be clicked. Focused spots are stacked: a spot focused from another one
## goes back to it instead of going back to the whole room, which lets the two
## interactions chain (focus the bookshelf, then open one of its books).
##
## [constant InteractiveSpot.Mode.DETAIL] spots are not handled here: the
## controller emits [signal detail_requested] and lets the interior open the
## detail viewer.


## Emitted after each level change, with the depth (0 = whole room).
signal level_changed(depth: int, spot: InteractiveSpot)
## Emitted when a detail spot is clicked.
signal detail_requested(spot: InteractiveSpot)
## Emitted when the hovered spot changes, for the interior hint label.
signal hover_changed(spot: InteractiveSpot)

## Length of the picking ray, in meters.
const RAY_LENGTH := 200.0

## Camera moved by the controller.
@export var camera_path: NodePath
## Duration of the move towards a spot.
@export var focus_duration: float = 0.85
## Duration of the move back to the previous level.
@export var return_duration: float = 0.7

var _camera: Camera3D = null
var _spots: Array[InteractiveSpot] = []
var _root_spots: Array[InteractiveSpot] = []
var _stack: Array[InteractiveSpot] = []
var _hovered: InteractiveSpot = null

## Camera placement of the whole room view, restored when leaving every level.
var _rest_transform: Transform3D
var _rest_size: float = 0.0

var _is_moving: bool = false
var _is_locked: bool = false
var _click_pending: bool = false
var _hover_pending: bool = false

## Interpolated values of the current camera move.
var _travel_from: Transform3D
var _travel_to: Transform3D
var _quat_from: Quaternion
var _quat_to: Quaternion
var _size_from: float = 0.0
var _size_to: float = 0.0


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	if _camera == null:
		push_error("FocusController: camera_path does not point to a Camera3D (%s)." % camera_path)
		return
	set_rest_state(_camera.global_transform, _camera.size)


#region Setup

## Give the controller the spots of the interior. Runtime created spots (the
## books of the shelf) must already be in the tree when this is called.
func register_spots(spots: Array[InteractiveSpot]) -> void:
	_spots = spots

	# A spot declared as the child of another one is not part of the room level.
	var children := {}
	for spot: InteractiveSpot in _spots:
		for child: InteractiveSpot in spot.get_child_spots():
			children[child] = true

	_root_spots.clear()
	for spot: InteractiveSpot in _spots:
		if not children.has(spot):
			_root_spots.append(spot)

	_apply_level()


## Camera placement considered as "no spot focused". Call this again if the
## room view itself changes (when free navigation is added to the interior).
func set_rest_state(camera_transform: Transform3D, orthographic_size: float) -> void:
	_rest_transform = camera_transform
	_rest_size = orthographic_size


## Ignore every click, while the detail viewer is open for instance.
func set_input_locked(value: bool) -> void:
	_is_locked = value
	if value:
		_set_hovered(null)
	else:
		_hover_pending = true

#endregion
#region State

## 0 when the whole room is visible, 1 when a spot is focused, and so on.
func get_depth() -> int:
	return _stack.size()


## Spot currently focused, or [code]null[/code] at depth 0.
func get_focused_spot() -> InteractiveSpot:
	if _stack.is_empty():
		return null
	return _stack[-1]


func is_moving() -> bool:
	return _is_moving

#endregion
#region Input

func _unhandled_input(event: InputEvent) -> void:
	if _is_locked:
		return

	if event is InputEventMouseMotion:
		_hover_pending = true
		return

	if event.is_action_pressed("ui_cancel") and get_depth() > 0:
		back()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_click_pending = true


## Picking is resolved here: querying the physics space is only reliable
## during the physics step.
func _physics_process(_delta: float) -> void:
	if _is_locked or _camera == null:
		return
	if not (_click_pending or _hover_pending):
		return

	var spot: InteractiveSpot = _pick_spot()

	if _hover_pending:
		_hover_pending = false
		_set_hovered(spot)

	if _click_pending:
		_click_pending = false
		if not _is_moving:
			_handle_click(spot)


## A click on a spot activates it, a click anywhere else goes back one level.
func _handle_click(spot: InteractiveSpot) -> void:
	if spot == null:
		if get_depth() > 0:
			back()
		return

	spot.activate()
	match spot.mode:
		InteractiveSpot.Mode.FOCUS:
			focus(spot)
		InteractiveSpot.Mode.DETAIL:
			detail_requested.emit(spot)


## Closest enabled spot under the mouse, or [code]null[/code].
func _pick_spot() -> InteractiveSpot:
	var mouse_position: Vector2 = _camera.get_viewport().get_mouse_position()
	var from: Vector3 = _camera.project_ray_origin(mouse_position)
	var to: Vector3 = from + _camera.project_ray_normal(mouse_position) * RAY_LENGTH

	var query := PhysicsRayQueryParameters3D.create(from, to, InteractiveSpot.SPOT_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.get("collider") as InteractiveSpot


func _set_hovered(spot: InteractiveSpot) -> void:
	if _hovered == spot:
		return

	if _hovered != null:
		_hovered.set_hovered(false)
	_hovered = spot
	if _hovered != null:
		_hovered.set_hovered(true)

	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if _hovered != null else Input.CURSOR_ARROW
	)
	hover_changed.emit(_hovered)

#endregion
#region Levels

## Focus [param spot]: move the camera to its marker and reveal its details.
func focus(spot: InteractiveSpot) -> void:
	if _is_moving or spot == null or _stack.has(spot):
		return
	if not spot.has_focus_marker():
		push_warning("InteractiveSpot %s has no focus marker, focus ignored." % spot.name)
		return

	_set_hovered(null)
	_stack.append(spot)
	spot.set_revealed(true)
	_apply_level()
	await _travel(spot.get_focus_transform(), spot.focus_zoom, focus_duration)


## Leave the current level and go back to the previous one.
func back() -> void:
	if _is_moving or _stack.is_empty():
		return

	_set_hovered(null)
	var leaving: InteractiveSpot = _stack.pop_back()
	leaving.set_revealed(false)
	_apply_level()

	var parent: InteractiveSpot = get_focused_spot()
	if parent == null:
		await _travel(_rest_transform, _rest_size, return_duration)
	else:
		await _travel(parent.get_focus_transform(), parent.focus_zoom, return_duration)


## Leave every level at once and go back to the room view.
func reset() -> void:
	if _is_moving or _stack.is_empty():
		return

	_set_hovered(null)
	for spot: InteractiveSpot in _stack:
		spot.set_revealed(false)
	_stack.clear()
	_apply_level()
	await _travel(_rest_transform, _rest_size, return_duration)


## Only the spots of the active level stay clickable.
func _apply_level() -> void:
	var focused: InteractiveSpot = get_focused_spot()
	var level_spots: Array[InteractiveSpot] = _root_spots
	if focused != null:
		level_spots = focused.get_child_spots()

	for spot: InteractiveSpot in _spots:
		spot.set_enabled(level_spots.has(spot))

	level_changed.emit(get_depth(), focused)

#endregion
#region Camera move

## Move the camera to [param target] over [param duration] seconds.
func _travel(target: Transform3D, orthographic_size: float, duration: float) -> void:
	_is_moving = true

	_travel_from = _camera.global_transform
	_travel_to = target
	_quat_from = _travel_from.basis.get_rotation_quaternion()
	_quat_to = _travel_to.basis.get_rotation_quaternion()
	_size_from = _camera.size
	_size_to = orthographic_size if orthographic_size > 0.0 else _camera.size

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_apply_travel, 0.0, 1.0, duration)
	await tween.finished

	_is_moving = false
	_hover_pending = true


## Interpolate position and orientation separately: a linear interpolation
## of the complete matrix would distort the basis during rotation.
func _apply_travel(ratio: float) -> void:
	var rotation_basis := Basis(_quat_from.slerp(_quat_to, ratio))
	_camera.global_transform = Transform3D(
		rotation_basis, _travel_from.origin.lerp(_travel_to.origin, ratio)
	)
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.size = lerpf(_size_from, _size_to, ratio)

#endregion
