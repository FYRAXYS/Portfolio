class_name Book3D
extends Node3D
## Open book shown in the foreground by the [DetailViewer].
##
## The geometry is built from boxes and quads at runtime, so the document only
## needs its markdown file: covers, page block and three page surfaces
## ([BookPage]). Turning a page rotates a sheet around the spine; the sheet
## carries the page the user is leaving on its front and the page that lands on
## the left on its back, while the static pages are swapped behind it.
##
## This node lives in its own [SubViewport] world, with its own camera, and
## every material is unshaded: the viewer is never affected by the interior
## lighting nor by the physical light units of the project.


## Emitted after each page turn and when a document is loaded.
signal spread_changed(spread: int, spread_count: int)

@export_group("Page")
## Resolution of a single page texture.
@export var page_pixels := Vector2i(640, 860)
## Margin between the page border and its text, in pixels.
@export var page_margin: int = 54
## Size of the page body text, in pixels.
@export var page_font_size: int = 18
@export var paper_color := Color(0.96, 0.94, 0.88)

@export_group("Book")
## Width of a single page, in meters. The height follows [member page_pixels].
@export var page_width: float = 1.0
## Fallback cover color, used until a document gives its own.
@export var cover_color := Color(0.27, 0.18, 0.13)
## Tilt of the book towards the camera, in degrees.
@export var tilt_degrees: float = -16.0

@export_group("Camera")
## Direction the camera looks from, as a height over a distance. The distance
## itself is computed so the whole book fits in the window.
@export var camera_distance: float = 2.35
@export var camera_height: float = 0.62
## Horizontal field of view of the book camera.
@export var camera_fov: float = 58.0
## Free space kept around the book, in meters.
@export var camera_margin: float = 0.12

@export_group("Animation")
## Duration of a single page turn, in seconds.
@export var turn_duration: float = 0.55
## How far the turning sheet lifts away from the book, in meters.
@export var turn_lift: float = 0.14

## Z offset of the turning sheet, above the static pages.
const SHEET_OFFSET := 0.008

var _pivot: Node3D
var _camera: Camera3D
## Size of a single page, in meters.
var _page_size := Vector2.ONE
var _cover_material: StandardMaterial3D
var _spine_material: StandardMaterial3D
var _left_page: BookPage
var _right_page: BookPage
var _turn_pivot: Node3D
var _turn_front: BookPage
var _turn_back: BookPage

var _document: DocumentData = null
var _page_offsets := PackedFloat32Array()
## Total height of the laid out document, in page pixels.
var _content_height: float = 0.0
var _spread: int = 0
var _is_turning: bool = false


func _ready() -> void:
	_build()


#region Build

## Create the camera, the lights and every part of the book.
func _build() -> void:
	var page_height: float = page_width * float(page_pixels.y) / float(page_pixels.x)
	var page_size := Vector2(page_width, page_height)
	_page_size = page_size

	_camera = Camera3D.new()
	_camera.name = "BookCamera"
	_camera.fov = camera_fov
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.current = true
	add_child(_camera)
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)

	_pivot = Node3D.new()
	_pivot.name = "BookPivot"
	_pivot.rotation_degrees = Vector3(tilt_degrees, 0.0, 0.0)
	add_child(_pivot)

	_build_body(page_size)

	_left_page = _add_page(_pivot, "LeftPage", page_size, true)
	_left_page.position = Vector3(-page_width * 0.5, 0.0, 0.0)

	_right_page = _add_page(_pivot, "RightPage", page_size, false)
	_right_page.position = Vector3(page_width * 0.5, 0.0, 0.0)

	_turn_pivot = Node3D.new()
	_turn_pivot.name = "TurnPivot"
	_turn_pivot.position = Vector3(0.0, 0.0, SHEET_OFFSET)
	_turn_pivot.visible = false
	_pivot.add_child(_turn_pivot)

	_turn_front = _add_page(_turn_pivot, "TurnFront", page_size, false)
	_turn_front.position = Vector3(page_width * 0.5, 0.0, 0.001)

	_turn_back = _add_page(_turn_pivot, "TurnBack", page_size, true)
	_turn_back.position = Vector3(page_width * 0.5, 0.0, -0.001)
	_turn_back.rotation_degrees = Vector3(0.0, 180.0, 0.0)


## Place the camera far enough for the whole spread to be visible, whatever
## the shape of the window: a wide window would otherwise cut the pages.
func _fit_camera() -> void:
	if _camera == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = 1.0
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		aspect = viewport_size.x / viewport_size.y

	var half_width: float = _page_size.x + camera_margin
	var half_height: float = _page_size.y * 0.5 + camera_margin
	var tan_half_fov: float = tan(deg_to_rad(camera_fov * 0.5))
	var distance: float = maxf(half_width, half_height * aspect) / maxf(tan_half_fov, 0.01)

	var direction: Vector3 = Vector3(0.0, camera_height, camera_distance).normalized()
	_camera.position = direction * distance
	_camera.look_at(Vector3.ZERO)


## Covers, spine and paper block the pages are resting on.
func _build_body(page_size: Vector2) -> void:
	_cover_material = _flat_material(cover_color)
	_spine_material = _flat_material(cover_color.darkened(0.3))
	var paper_block_material := _flat_material(paper_color.darkened(0.14))

	_add_box(
		"Cover",
		Vector3(page_size.x * 2.0 + 0.09, page_size.y + 0.07, 0.022),
		Vector3(0.0, 0.0, -0.028),
		_cover_material
	)
	_add_box(
		"Spine",
		Vector3(0.055, page_size.y + 0.07, 0.03),
		Vector3(0.0, 0.0, -0.022),
		_spine_material
	)
	for side: int in [-1, 1]:
		_add_box(
			"PaperBlock%s" % ("Left" if side < 0 else "Right"),
			Vector3(page_size.x - 0.01, page_size.y - 0.015, 0.016),
			Vector3(page_size.x * 0.5 * float(side), 0.0, -0.012),
			paper_block_material
		)


## Unshaded material, so the book keeps the same flat look everywhere.
func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _add_box(box_name: String, size: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size

	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = box
	instance.position = offset
	instance.material_override = material
	_pivot.add_child(instance)
	return instance


## A page is added to the tree before being set up: its viewport texture can
## only be created once the viewport is inside the tree.
func _add_page(parent: Node3D, page_name: String, page_size: Vector2, spine_on_right: bool) -> BookPage:
	var page := BookPage.new()
	page.name = page_name
	parent.add_child(page)
	page.setup(page_pixels, page_size, page_margin, page_font_size, paper_color, spine_on_right)
	return page

#endregion
#region Document

## Display [param document]: lay it out, cut it into pages and open it.
func load_document(document: DocumentData) -> void:
	if document == null:
		return
	_document = document
	_cover_material.albedo_color = document.color.darkened(0.25)
	_spine_material.albedo_color = document.color.darkened(0.5)

	var bbcode: String = document.to_bbcode()
	for page: BookPage in _pages():
		page.set_source(bbcode)

	# The line positions are only final once the label has shaped its text.
	await _left_page.wait_until_laid_out()

	_content_height = _left_page.get_content_height()
	_page_offsets = _left_page.measure_pages()
	_spread = 0
	_turn_pivot.visible = false
	_is_turning = false
	_show_spread(0)


## Progress of the open animation, from 0 (away) to 1 (in place). Driven by
## the viewer so the book slides in with the background blur.
func set_appear_ratio(ratio: float) -> void:
	if _pivot == null:
		return
	_pivot.scale = Vector3.ONE * lerpf(0.84, 1.0, ratio)
	_pivot.rotation_degrees = Vector3(tilt_degrees, lerpf(-12.0, 0.0, ratio), 0.0)
	_pivot.position.y = lerpf(-0.14, 0.0, ratio)


func get_page_count() -> int:
	return _page_offsets.size()


func get_spread_count() -> int:
	return maxi(1, ceili(get_page_count() / 2.0))


func get_spread() -> int:
	return _spread


func is_turning() -> bool:
	return _is_turning

#endregion
#region Page turn

## Turn to the next spread, if there is one.
func next_spread() -> void:
	if _is_turning or _spread + 1 >= get_spread_count():
		return
	var target: int = _spread + 1
	_is_turning = true

	# The sheet carries the page being left and the one landing on the left,
	# while the right page already shows the spread being revealed.
	_set_page(_turn_front, _spread * 2 + 1)
	_set_page(_turn_back, target * 2)
	_set_page(_right_page, target * 2 + 1)
	_turn_pivot.visible = true

	await _animate_turn(0.0, PI)
	_finish_turn(target)


## Turn back to the previous spread, if there is one.
func previous_spread() -> void:
	if _is_turning or _spread <= 0:
		return
	var target: int = _spread - 1
	_is_turning = true

	_set_page(_turn_back, _spread * 2)
	_set_page(_turn_front, target * 2 + 1)
	_set_page(_left_page, target * 2)
	_turn_pivot.visible = true

	await _animate_turn(PI, 0.0)
	_finish_turn(target)


func _finish_turn(spread: int) -> void:
	_spread = spread
	_show_spread(_spread)
	_turn_pivot.visible = false
	_turn_pivot.rotation = Vector3.ZERO
	_turn_pivot.position = Vector3(0.0, 0.0, SHEET_OFFSET)
	_is_turning = false


## Rotate the sheet around the spine, lifting it away from the book on the way.
func _animate_turn(from_angle: float, to_angle: float) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_apply_turn, from_angle, to_angle, turn_duration)
	await tween.finished


func _apply_turn(angle: float) -> void:
	_turn_pivot.rotation.y = angle
	var ratio: float = clampf(angle / PI, 0.0, 1.0)
	_turn_pivot.position.z = SHEET_OFFSET + sin(ratio * PI) * turn_lift


## Show the two pages of [param spread] on the static page surfaces.
func _show_spread(spread: int) -> void:
	_set_page(_left_page, spread * 2)
	_set_page(_right_page, spread * 2 + 1)
	spread_changed.emit(spread, get_spread_count())


func _set_page(page: BookPage, index: int) -> void:
	if index < 0 or index >= _page_offsets.size():
		page.show_blank()
		return

	# A page stops where the next one starts, so a line is never shown twice.
	var offset: float = _page_offsets[index]
	var end: float = _content_height
	if index + 1 < _page_offsets.size():
		end = _page_offsets[index + 1]
	page.show_page(offset, end - offset, index + 1)


func _pages() -> Array[BookPage]:
	var pages: Array[BookPage] = [_left_page, _right_page, _turn_front, _turn_back]
	return pages

#endregion
