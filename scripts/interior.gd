extends Node3D
## Handle the interior logic (with an isometric view).
##
## Clicking an element of the room triggers one of the two interactions:
## [br]- a [constant InteractiveSpot.Mode.FOCUS] spot moves the camera closer
## and reveals the details attached to it ([FocusController]),
## [br]- a [constant InteractiveSpot.Mode.DETAIL] spot blurs the room and opens
## its markdown document in the book ([DetailViewer]).
##
## Both chain: the books of the shelf are detail spots that only exist once the
## shelf itself is focused.


## Hint shown while nothing is focused.
const ROOM_HINT := "Cliquez sur un élément du chalet pour l'explorer"
## Hint shown while an element is focused.
const FOCUS_HINT := "Cliquez à côté ou sur « Retour » pour revenir"

@onready var exit_zone: Area3D = $ExitZone
@onready var exit_button: Button = $UI/ExitButton
@onready var back_button: Button = $UI/BackButton
@onready var hint_label: Label = $UI/HintLabel
@onready var furniture: Node3D = $Furniture
@onready var focus_controller: FocusController = $FocusController
@onready var detail_viewer: DetailViewer = $DetailViewer

var _is_leaving: bool = false
## Always visible labels of the room, faded out while an element is focused.
var _section_labels: Array[Label3D] = []
var _section_tween: Tween


func _ready() -> void:
	# let the mouse be detected inside the exit zone
	get_viewport().physics_object_picking = true

	## signals connection for exit logic
	exit_button.pressed.connect(leave_house)
	exit_zone.input_event.connect(_on_exit_zone_input_event)
	exit_zone.mouse_entered.connect(_on_exit_mouse_entered)
	exit_zone.mouse_exited.connect(_on_exit_mouse_exited)

	## signals connection for the interactions
	back_button.pressed.connect(_on_back_pressed)
	focus_controller.level_changed.connect(_on_level_changed)
	focus_controller.hover_changed.connect(_on_hover_changed)
	focus_controller.detail_requested.connect(_on_detail_requested)
	detail_viewer.closed.connect(_on_detail_closed)

	for child: Node in furniture.get_children():
		if child is Label3D:
			_section_labels.append(child as Label3D)

	hint_label.text = ROOM_HINT
	# The books of the shelf are already in the tree: the rack fills it in its
	# own _ready(), which runs before this one.
	focus_controller.register_spots(_collect_spots())


#region Interactions

## Every spot of the interior, including the ones created at runtime.
func _collect_spots() -> Array[InteractiveSpot]:
	var spots: Array[InteractiveSpot] = []
	_append_spots(self, spots)
	return spots


func _append_spots(node: Node, spots: Array[InteractiveSpot]) -> void:
	for child: Node in node.get_children():
		if child is InteractiveSpot:
			spots.append(child as InteractiveSpot)
		_append_spots(child, spots)


## Update the user interface to match the level the user is in.
func _on_level_changed(depth: int, _spot: InteractiveSpot) -> void:
	var is_room: bool = depth == 0
	back_button.visible = not is_room
	exit_button.visible = is_room
	exit_zone.input_ray_pickable = is_room
	hint_label.text = ROOM_HINT if is_room else FOCUS_HINT
	_fade_section_labels(is_room)


## Show the name of the hovered element, or the hint of the current level.
func _on_hover_changed(spot: InteractiveSpot) -> void:
	if spot != null and not spot.display_name.is_empty():
		hint_label.text = spot.display_name
	elif focus_controller.get_depth() == 0:
		hint_label.text = ROOM_HINT
	else:
		hint_label.text = FOCUS_HINT


func _on_back_pressed() -> void:
	focus_controller.back()


## Open the document of a detail spot, the camera staying where it is.
func _on_detail_requested(spot: InteractiveSpot) -> void:
	var document: DocumentData = ContentLibrary.get_document(spot.document_path)
	if document == null:
		push_error("Interior: no document to show for the spot %s." % spot.name)
		return

	focus_controller.set_input_locked(true)
	detail_viewer.open(document)


func _on_detail_closed() -> void:
	focus_controller.set_input_locked(false)


## Fade the section labels out while an element is focused: its own details
## take their place.
func _fade_section_labels(visible_labels: bool) -> void:
	if _section_labels.is_empty():
		return
	if _section_tween != null and _section_tween.is_valid():
		_section_tween.kill()

	_section_tween = create_tween().set_parallel(true)
	var target: float = 1.0 if visible_labels else 0.0
	for label: Label3D in _section_labels:
		# The outline carries its own color: without it the text stays on
		# screen as a black silhouette.
		_section_tween.tween_property(label, "modulate:a", target, 0.25)
		_section_tween.tween_property(label, "outline_modulate:a", target, 0.25)

#endregion
#region Exit

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

#endregion
