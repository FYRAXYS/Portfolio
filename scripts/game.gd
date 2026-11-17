extends Node
## Singleton responsible for managing black fade-out and transitions between the differents scenes

signal world_changed(world: Node)

const EXTERIOR_SCENE := "res://scenes/node_3d.tscn"
const INTERIOR_SCENE := "res://scenes/interior.tscn"

const DEFAULT_FADE := 0.6

## values are set by main.gd when starting
var world_host: Node = null
var current_world: Node = null

## variables for the transition fade-out
var _layer: CanvasLayer
var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	# process mode is set to Always the fade-out doesn't stop even if there is a popup
	process_mode = Node.PROCESS_MODE_ALWAYS

	## CanvasLayer that will contain the Rect
	_layer = CanvasLayer.new()
	_layer.name = "FadeLayer"
	_layer.layer = 128
	add_child(_layer)

	## UI Rect
	_rect = ColorRect.new()
	_rect.name = "FadeRect"
	_rect.color = Color.BLACK
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.modulate.a = 0.0
	_rect.visible = false
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_rect)


#region Fade-out

## Darken the screen [b](need to be awaited)[/b].
func fade_to_black(duration: float = DEFAULT_FADE) -> void:
	_set_input_blocked(true)
	_rect.visible = true
	_restart_tween()
	_tween.tween_property(_rect, "modulate:a", 1.0, duration)
	await _tween.finished


## Reveal the scene [b](need to be awaited)[/b].
func fade_from_black(duration: float = DEFAULT_FADE) -> void:
	_rect.visible = true
	_restart_tween()
	_tween.tween_property(_rect, "modulate:a", 0.0, duration)
	await _tween.finished
	_rect.visible = false
	_set_input_blocked(false)


## Instantly set the screen to full black or remove it completely.
func set_black(opaque: bool) -> void:
	_restart_tween()
	_rect.visible = opaque
	_rect.modulate.a = 1.0 if opaque else 0.0
	_set_input_blocked(opaque)


func _restart_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()


## Switch inputs detection (when doing the transition from the main scene to the interior and vice-versa).
func _set_input_blocked(blocked: bool) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP if blocked else Control.MOUSE_FILTER_IGNORE

#endregion
#region World

## Change the current world (=scene) with a fade-out effect.
func change_world(scene_path: String, fade_in_duration: float = 0.8) -> void:
	if world_host == null:
		push_error("Game.change_world : No current world found. main.gd must define it in _ready().")
		return

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("Game.change_world : Did not found any scene in %s" % scene_path)
		return

	## remove every node from the host/current world
	for child in world_host.get_children():
		world_host.remove_child(child)
		child.queue_free()

	## set the new scene as the current one
	current_world = packed.instantiate()
	world_host.add_child(current_world)
	world_changed.emit(current_world)

	## let one frame run for _ready()
	await get_tree().process_frame
	await fade_from_black(fade_in_duration)

## Go from the outside into the cabin.
func go_to_interior(fade_in_duration: float = 0.8) -> void:
	await change_world(INTERIOR_SCENE, fade_in_duration)

## Exit from the cabin into the outside.
func go_to_exterior(fade_in_duration: float = 0.8) -> void:
	await change_world(EXTERIOR_SCENE, fade_in_duration)

#endregion
