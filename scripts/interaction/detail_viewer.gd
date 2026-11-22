class_name DetailViewer
extends CanvasLayer
## Second interaction type: the interior is blurred and the document appears in
## the foreground as a small book ([Book3D]).
##
## The viewer is opened by the interior when a [constant
## InteractiveSpot.Mode.DETAIL] spot is clicked, and it does not touch the
## camera: closing it leaves the user exactly where he was, which is what lets
## a focused element open a document and go back to the focused view.


## Emitted once the viewer is fully closed.
signal closed

## Duration of the open and close animations, in seconds.
@export var fade_duration: float = 0.35
## Part of the screen covered by the book: a click inside turns the pages,
## a click outside closes the viewer.
@export var book_screen_ratio := Vector2(0.62, 0.78)

@onready var _blur: ColorRect = %Blur
@onready var _ui: Control = %UI
@onready var _book_viewport: SubViewport = %BookViewport
@onready var _book: Book3D = %Book
@onready var _title: Label = %Title
@onready var _page_indicator: Label = %PageIndicator
@onready var _previous_button: Button = %Previous
@onready var _next_button: Button = %Next
@onready var _close_button: Button = %Close

var _blur_material: ShaderMaterial
var _is_open: bool = false
var _is_busy: bool = false


func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)

	_blur_material = _blur.material as ShaderMaterial
	_set_blur_amount(0.0)

	_close_button.pressed.connect(close)
	_previous_button.pressed.connect(_on_previous_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_blur.gui_input.connect(_on_blur_gui_input)
	_book.spread_changed.connect(_on_spread_changed)


#region Open and close

## Blur the interior and open [param document] in the book.
func open(document: DocumentData) -> void:
	if _is_open or document == null:
		return
	_is_open = true
	_is_busy = true

	visible = true
	set_process_unhandled_input(true)
	_book_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_title.text = document.title
	_page_indicator.text = ""
	_book.set_appear_ratio(0.0)
	_set_blur_amount(0.0)
	_ui.modulate.a = 0.0

	await _book.load_document(document)
	await _animate(0.0, 1.0)
	_is_busy = false


## Close the viewer and give the interaction back to the interior.
func close() -> void:
	if not _is_open or _is_busy:
		return
	_is_busy = true
	set_process_unhandled_input(false)

	await _animate(1.0, 0.0)

	visible = false
	# Nothing to render while the viewer is closed.
	_book_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_is_open = false
	_is_busy = false
	closed.emit()


func is_open() -> bool:
	return _is_open


## Blur and book appearance are driven together by the same ratio.
func _animate(from_ratio: float, to_ratio: float) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_blur_amount, from_ratio, to_ratio, fade_duration)
	tween.tween_method(_book.set_appear_ratio, from_ratio, to_ratio, fade_duration)
	tween.tween_property(_ui, "modulate:a", to_ratio, fade_duration)
	await tween.finished


func _set_blur_amount(value: float) -> void:
	if _blur_material != null:
		_blur_material.set_shader_parameter("amount", value)

#endregion
#region Navigation

func _on_previous_pressed() -> void:
	if not _is_busy:
		_book.previous_spread()


func _on_next_pressed() -> void:
	if not _is_busy:
		_book.next_spread()


func _on_spread_changed(spread: int, spread_count: int) -> void:
	_page_indicator.text = "%d / %d" % [spread + 1, spread_count]
	_previous_button.disabled = spread <= 0
	_next_button.disabled = spread + 1 >= spread_count

#endregion
#region Input

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open or _is_busy:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		_book.next_spread()
	elif event.is_action_pressed("ui_left"):
		_book.previous_spread()
	else:
		return
	get_viewport().set_input_as_handled()


## Clicks and wheel events land here: the blurred background covers the whole
## screen, the book itself being only a texture drawn over it.
func _on_blur_gui_input(event: InputEvent) -> void:
	if not _is_open or _is_busy or not (event is InputEventMouseButton):
		return

	var button_event := event as InputEventMouseButton
	if not button_event.pressed:
		return

	match button_event.button_index:
		MOUSE_BUTTON_WHEEL_DOWN:
			_book.next_spread()
		MOUSE_BUTTON_WHEEL_UP:
			_book.previous_spread()
		MOUSE_BUTTON_LEFT:
			if _is_over_book(button_event.position):
				# Reading gesture: the right half goes forward, the left back.
				if button_event.position.x >= _blur.size.x * 0.5:
					_book.next_spread()
				else:
					_book.previous_spread()
			else:
				close()


## Whether [param point] is inside the area covered by the book.
func _is_over_book(point: Vector2) -> bool:
	var screen_size: Vector2 = _blur.size
	var book_size: Vector2 = screen_size * book_screen_ratio
	var book_rect := Rect2((screen_size - book_size) * 0.5, book_size)
	return book_rect.has_point(point)

#endregion
