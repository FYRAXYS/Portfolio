class_name BookPage
extends Node3D
## One page surface of the book: a quad whose texture is a [SubViewport]
## rendering the document at a given vertical offset.
##
## The whole document is laid out once in the page [RichTextLabel]; a page is
## then only a scroll offset snapped to a line start, so no line is ever cut in
## half. The viewport is rendered again only when the displayed page changes.


## Height of the page number strip at the bottom of the page, in pixels.
const NUMBER_HEIGHT := 46
## How many frames the text layout is waited for before giving up.
const LAYOUT_FRAME_BUDGET := 60

var _viewport: SubViewport
var _label: RichTextLabel
var _clip: Control
var _number: Label
var _quad: MeshInstance3D
var _material: StandardMaterial3D

var _content_size: Vector2 = Vector2.ZERO
var _refresh_frames: int = 0


#region Setup

## Build the page. [param world_size] is its size in meters, [param pixel_size]
## the resolution of its texture, and [param spine_on_right] tells on which
## side the shading of the book fold is drawn (true for a left page).
func setup(
		pixel_size: Vector2i,
		world_size: Vector2,
		margin: int,
		font_size: int,
		paper_color: Color,
		spine_on_right: bool
	) -> void:
	_content_size = Vector2(
		pixel_size.x - 2 * margin,
		pixel_size.y - margin - NUMBER_HEIGHT
	)

	_viewport = SubViewport.new()
	_viewport.name = "PageViewport"
	_viewport.size = pixel_size
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	var paper := ColorRect.new()
	paper.name = "Paper"
	paper.color = paper_color
	paper.size = Vector2(pixel_size)
	_viewport.add_child(paper)

	paper.add_child(_build_fold_shade(pixel_size, spine_on_right))

	_clip = Control.new()
	_clip.name = "Clip"
	_clip.position = Vector2(margin, margin)
	_clip.size = _content_size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(_clip)

	_label = RichTextLabel.new()
	_label.name = "Text"
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size = Vector2(_content_size.x, _content_size.y)
	_label.add_theme_font_size_override("normal_font_size", font_size)
	_label.add_theme_color_override("default_color", Color(0.14, 0.11, 0.09))
	_clip.add_child(_label)

	_number = Label.new()
	_number.name = "PageNumber"
	_number.position = Vector2(margin, pixel_size.y - NUMBER_HEIGHT)
	_number.size = Vector2(_content_size.x, NUMBER_HEIGHT)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.add_theme_font_size_override("font_size", 16)
	_number.add_theme_color_override("font_color", Color(0.42, 0.34, 0.27))
	paper.add_child(_number)

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_texture = _viewport.get_texture()
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = world_size

	_quad = MeshInstance3D.new()
	_quad.name = "Surface"
	_quad.mesh = quad_mesh
	_quad.material_override = _material
	add_child(_quad)


## Darker strip drawn along the book fold, to give the spread some depth.
func _build_fold_shade(pixel_size: Vector2i, spine_on_right: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.26))
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 8
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 0.0)

	var shade := TextureRect.new()
	shade.name = "FoldShade"
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.size = Vector2(pixel_size.x * 0.12, pixel_size.y)
	shade.flip_h = spine_on_right
	if spine_on_right:
		shade.position = Vector2(pixel_size.x - shade.size.x, 0.0)
	return shade

#endregion
#region Content

## Lay out the whole document on this page surface.
func set_source(bbcode: String) -> void:
	_label.text = bbcode
	_label.size = Vector2(_content_size.x, _content_size.y)
	_label.position = Vector2.ZERO
	request_refresh()


## Display the [param height] pixels of the document starting at
## [param offset], numbered [param number].
##
## The clipping rectangle is cut down to the content of the page: whatever the
## line positions end up being, the first line of the next page can never show
## up at the bottom of this one.
func show_page(offset: float, height: float, number: int) -> void:
	_clip.visible = true
	_clip.size = Vector2(_content_size.x, clampf(height, 0.0, _content_size.y))
	_label.position = Vector2(0.0, -offset)
	_label.size = Vector2(_content_size.x, maxf(_content_size.y, get_content_height()))
	_number.text = str(number)
	request_refresh()


## Wait until the label has shaped its text: the line positions the pagination
## relies on are only final once it is done.
func wait_until_laid_out() -> void:
	for frame: int in LAYOUT_FRAME_BUDGET:
		if _is_laid_out():
			return
		# Keep the viewport drawing: the label only shapes what it draws.
		request_refresh()
		await get_tree().process_frame
	push_warning("BookPage: the text layout is not ready, pages may be cut.")


## Whether the line positions of the label can be trusted.
func _is_laid_out() -> bool:
	if get_content_height() <= _content_size.y:
		return true # single page, no pagination needed
	var line_count: int = _label.get_line_count()
	return line_count > 1 and _label.get_line_offset(line_count - 1) > 0.0


## Display an empty page, for the last odd page of a document.
func show_blank() -> void:
	_clip.visible = false
	_number.text = ""
	request_refresh()


## Texture the quad of this page is showing.
func get_page_texture() -> Texture2D:
	return _viewport.get_texture()


func get_content_height() -> float:
	return float(_label.get_content_height())


## Height available for the text of a single page, in pixels.
func get_page_height() -> float:
	return _content_size.y

#endregion
#region Pagination

## Vertical offset of every page of the document, snapped to a line start so a
## line of text is never split between two pages.
func measure_pages() -> PackedFloat32Array:
	var offsets := PackedFloat32Array([0.0])
	var content_height: float = get_content_height()
	var page_height: float = _content_size.y
	if content_height <= page_height:
		return offsets

	var line_count: int = _label.get_line_count()
	# get_line_offset() needs a laid out label; fall back to fixed slices when
	# the line positions are not available.
	if not _is_laid_out():
		push_warning("BookPage: no line position available, pages are cut on a fixed height.")
	if line_count < 2 or _label.get_line_offset(line_count - 1) <= 0.0:
		var offset: float = page_height
		while offset < content_height:
			offsets.append(offset)
			offset += page_height
		return offsets

	var start: int = 0
	while start < line_count:
		var limit: float = _line_top(start, line_count, content_height) + page_height
		var last: int = start
		while last < line_count and _line_top(last + 1, line_count, content_height) <= limit:
			last += 1
		if last == start:
			last = start + 1 # a single line taller than the page
		start = last
		if start < line_count:
			offsets.append(_line_top(start, line_count, content_height))
	return offsets


## Vertical position of a line, the end of the content standing for the line
## right after the last one.
func _line_top(index: int, line_count: int, content_height: float) -> float:
	if index >= line_count:
		return content_height
	return _label.get_line_offset(index)

#endregion
#region Rendering

## Render the page texture again on the next frames: one frame is not enough,
## the control layout is only final once it has been processed.
func request_refresh() -> void:
	_refresh_frames = 3
	set_process(true)


func _process(_delta: float) -> void:
	if _refresh_frames <= 0:
		set_process(false)
		return
	_refresh_frames -= 1
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

#endregion
