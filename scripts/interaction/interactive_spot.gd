class_name InteractiveSpot
extends Area3D
## Clickable element of the interior. Clicks are not detected by the area
## itself: [FocusController] casts a ray on [constant SPOT_LAYER] so the
## closest spot of the active level always wins.
##
## Two behaviours are available:
## [br]- [constant Mode.FOCUS] moves the camera to [member focus_marker] and
## reveals [member reveal_root],
## [br]- [constant Mode.DETAIL] asks the controller to open
## [member document_path] in the detail viewer.
##
## A spot placed under another spot in the scene tree only becomes clickable
## once that parent spot is focused, which is what chains the two interactions
## (focus the bookshelf, then click one of its books).


## Emitted when the user clicks this spot while it is enabled.
signal activated(spot: InteractiveSpot)

## Collision layer the controller casts its picking ray against.
const SPOT_LAYER := 2

enum Mode {
	FOCUS, ## Move the camera closer and reveal extra nodes.
	DETAIL, ## Blur the background and open a document in the detail viewer.
}

## Name displayed by the interior hint label while the spot is hovered.
@export var display_name: String = ""
## Which of the two interactions this spot triggers.
@export var mode: Mode = Mode.FOCUS

@export_group("Focus")
## Where the camera goes while this spot is focused. Its rotation is used as
## it is, so a marker copied from the interior camera keeps the isometric view.
@export var focus_marker: NodePath
## Orthographic size of the camera while focused (the lower, the closer).
@export var focus_zoom: float = 5.0
## Node shown while this spot is focused, hidden again when going back. Its
## whole subtree appears at once, so it is usually a group of labels.
@export var reveal_root: NodePath

@export_group("Detail")
## Markdown document opened by a [constant Mode.DETAIL] spot.
@export_file("*.md") var document_path: String = ""

@export_group("Feedback")
## Mesh outlined while the spot is hovered, with its own meshes.
@export var highlight_root: NodePath

## Whether the spot belongs to the level the user is currently in.
var is_enabled: bool = true
## Whether the mouse is currently over the spot.
var is_hovered: bool = false

var _reveal_nodes: Array[Node3D] = []
var _hover_reveal_nodes: Array[Node3D] = []
var _reveal_scales: Array[Vector3] = []
var _highlight_nodes: Array[GeometryInstance3D] = []
var _resolved_child_spots: Array[InteractiveSpot] = []
var _reveal_tween: Tween

## Overlay shared by every spot, applied on hover to outline a mesh.
static var _highlight_material: StandardMaterial3D = null


func _ready() -> void:
	# Picking is done by the controller, the viewport does not need to test it.
	input_ray_pickable = false
	collision_layer = SPOT_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = false

	add_reveal_node(get_node_or_null(reveal_root) as Node3D)
	_collect_highlight_nodes(get_node_or_null(highlight_root))
	# Any spot placed under this one belongs to its focused level.
	_collect_child_spots(self)

	_set_reveal_visible(false)


#region Level

## Tell the listeners the user just clicked this spot. Called by the
## [FocusController], which owns the picking.
func activate() -> void:
	activated.emit(self)


## Enable or disable the spot: a disabled spot is not pickable any more.
func set_enabled(value: bool) -> void:
	if is_enabled == value:
		return
	is_enabled = value
	collision_layer = SPOT_LAYER if value else 0
	if not value:
		set_hovered(false)


## Nodes revealed while the spot is focused.
func set_revealed(value: bool) -> void:
	if _reveal_nodes.is_empty():
		return

	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()

	if not value:
		_set_reveal_visible(false)
		return

	_reveal_tween = create_tween().set_parallel(true)
	_reveal_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for index: int in _reveal_nodes.size():
		var node: Node3D = _reveal_nodes[index]
		var target_scale: Vector3 = _reveal_scales[index]
		node.visible = true
		node.scale = target_scale * 0.85
		_reveal_tween.tween_property(node, "scale", target_scale, 0.35)
		for property: String in _fade_properties(node):
			node.set(property, _with_alpha(node, property, 0.0))
			_reveal_tween.tween_property(node, "%s:a" % property, 1.0, 0.35)


## Spots that become clickable while this spot is focused: the spots placed
## under this one in the scene, plus the ones registered at runtime.
func get_child_spots() -> Array[InteractiveSpot]:
	return _resolved_child_spots


## Declare a spot as a child of this one, for spots created at runtime.
func register_child_spot(spot: InteractiveSpot) -> void:
	if spot == null or _resolved_child_spots.has(spot):
		return
	_resolved_child_spots.append(spot)
	spot.set_enabled(false)

#endregion
#region Focus target

## Whether the spot can move the camera.
func has_focus_marker() -> bool:
	return get_node_or_null(focus_marker) is Node3D


## Camera placement to use while this spot is focused.
func get_focus_transform() -> Transform3D:
	var marker: Node3D = get_node_or_null(focus_marker) as Node3D
	if marker == null:
		push_warning("InteractiveSpot %s: no focus marker set." % name)
		return global_transform
	return marker.global_transform

#endregion
#region Hover

## Outline the spot meshes and remember the hovered state.
func set_hovered(value: bool) -> void:
	if is_hovered == value:
		return
	is_hovered = value

	var overlay: StandardMaterial3D = _get_highlight_material() if value else null
	for node: GeometryInstance3D in _highlight_nodes:
		node.material_overlay = overlay
	for node: Node3D in _hover_reveal_nodes:
		node.visible = value


## Register a mesh outlined on hover, for spots created at runtime.
func add_highlight_node(node: GeometryInstance3D) -> void:
	if node == null or _highlight_nodes.has(node):
		return
	_highlight_nodes.append(node)


## Register a node shown only while the mouse is over the spot. Used for the
## titles of the books: showing them all at once would overlap.
func add_hover_reveal_node(node: Node3D) -> void:
	if node == null or _hover_reveal_nodes.has(node):
		return
	_hover_reveal_nodes.append(node)
	node.visible = false


## Register a node revealed on focus, for spots created at runtime.
func add_reveal_node(node: Node3D) -> void:
	if node == null or _reveal_nodes.has(node):
		return
	_reveal_nodes.append(node)
	_reveal_scales.append(node.scale)
	node.visible = false


## Register every mesh of [param root], including [param root] itself.
func _collect_highlight_nodes(root: Node) -> void:
	if root == null:
		return
	if root is GeometryInstance3D:
		add_highlight_node(root as GeometryInstance3D)
	for child: Node in root.get_children():
		_collect_highlight_nodes(child)


## Register every spot found under [param root], without going through the
## spots they own themselves.
func _collect_child_spots(root: Node) -> void:
	for child: Node in root.get_children():
		if child is InteractiveSpot:
			register_child_spot(child as InteractiveSpot)
		else:
			_collect_child_spots(child)


func _set_reveal_visible(value: bool) -> void:
	for index: int in _reveal_nodes.size():
		var node: Node3D = _reveal_nodes[index]
		node.visible = value
		node.scale = _reveal_scales[index]
		for property: String in _fade_properties(node):
			node.set(property, _with_alpha(node, property, 1.0))


## Color properties of [param node] that can be faded in. The outline of a
## [Label3D] carries its own alpha: left alone, the text stays on screen as a
## black silhouette. Plain [Node3D] group roots only get the scale animation.
static func _fade_properties(node: Node3D) -> Array[String]:
	var properties: Array[String] = []
	if node is Label3D:
		properties = ["modulate", "outline_modulate"]
	elif node is Sprite3D:
		properties = ["modulate"]
	return properties


## Color property of [param node] with its alpha replaced.
static func _with_alpha(node: Node3D, property: String, alpha: float) -> Color:
	var color: Color = node.get(property)
	color.a = alpha
	return color


## Translucent overlay drawn slightly larger than the mesh it is applied to.
static func _get_highlight_material() -> StandardMaterial3D:
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_material.albedo_color = Color(1.0, 0.91, 0.72, 0.18)
		_highlight_material.grow = true
		_highlight_material.grow_amount = 0.02
	return _highlight_material

#endregion
