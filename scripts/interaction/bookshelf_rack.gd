class_name BookshelfRack
extends Node3D
## Fills the bookshelf with one book per document found by [ContentLibrary].
##
## Each book is a box with its own [InteractiveSpot] in
## [constant InteractiveSpot.Mode.DETAIL] mode, registered as a child spot of
## [member shelf_spot]: the books only become clickable once the shelf is
## focused. Adding a project is therefore only a matter of adding a markdown
## file in [constant ContentLibrary.PROJECTS_DIR].
##
## [method build] is called by the interior before the spots are given to the
## [FocusController], so the generated spots are part of the same level system.


## Spot of the shelf itself, which the generated books are attached to.
@export var shelf_spot: NodePath

@export_group("Shelf")
## Width available for a row of books, in meters.
@export var row_width: float = 2.2
## Vertical distance between two rows, in meters.
@export var row_spacing: float = 0.72
## Draw a plank under each row of books.
@export var show_planks: bool = true
@export var plank_color := Color(0.31, 0.2, 0.13)

@export_group("Book")
@export var book_size := Vector3(0.11, 0.42, 0.24)
## Gap between two books of the same row, in meters.
@export var book_spacing: float = 0.05
## Largest tilt applied to a book, in degrees, to avoid a too regular row.
@export var book_tilt: float = 2.5

@export_group("Label")
## Title shown above a book while the mouse is over it. Only the hovered one
## is shown: all the titles at once would overlap.
@export var label_font_size: int = 28
@export var label_pixel_size: float = 0.006
## Height of the label above the book, in meters.
@export var label_offset: float = 0.22
## Width the title wraps at, in pixels.
@export var label_width: float = 320.0

var _spots: Array[InteractiveSpot] = []
var _is_built: bool = false


func _ready() -> void:
	# Built here so the books are already in the tree when the interior hands
	# the spots over to the controller.
	if not _is_built:
		build()


## Create one book per project document. Calling it again rebuilds everything.
func build() -> void:
	_is_built = true
	_clear()

	var shelf: InteractiveSpot = get_node_or_null(shelf_spot) as InteractiveSpot
	if shelf == null:
		push_error("BookshelfRack: shelf_spot does not point to an InteractiveSpot (%s)." % shelf_spot)
		return

	var documents: Array[DocumentData] = ContentLibrary.list_projects()
	if documents.is_empty():
		push_warning("BookshelfRack: no project document found, the shelf stays empty.")
		return

	var per_row: int = maxi(1, floori((row_width + book_spacing) / (book_size.x + book_spacing)))
	var row_count: int = ceili(documents.size() / float(per_row))

	if show_planks:
		for row: int in row_count:
			_add_plank(row)

	for index: int in documents.size():
		var row: int = floori(float(index) / float(per_row))
		var column: int = index % per_row
		var in_row: int = mini(per_row, documents.size() - row * per_row)
		_add_book(documents[index], shelf, index, row, column, in_row)


## Remove every generated node, so the shelf can be filled again.
func _clear() -> void:
	_spots.clear()
	for child: Node in get_children():
		# Removed right away so the names stay free for the new books.
		remove_child(child)
		child.queue_free()


#region Generated nodes

## Place a book, its title and its clickable spot.
func _add_book(
		document: DocumentData,
		shelf: InteractiveSpot,
		index: int,
		row: int,
		column: int,
		in_row: int
	) -> void:
	var book := Node3D.new()
	book.name = "Book_%s" % document.id
	book.position = Vector3(
		_column_x(column, in_row),
		row * row_spacing + book_size.y * 0.5,
		0.0
	)
	# A deterministic tilt per book keeps the row from looking too regular.
	book.rotation_degrees = Vector3(0.0, 0.0, (float((index * 37) % 5) - 2.0) * book_tilt)
	add_child(book)

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _book_mesh()
	mesh.material_override = _book_material(document.color)
	book.add_child(mesh)

	var label := Label3D.new()
	label.name = "Title"
	label.text = document.title
	label.font_size = label_font_size
	label.pixel_size = label_pixel_size
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# A billboard title is wider than the gap in front of the shelf: without
	# this the wall and the furniture would cut it.
	label.no_depth_test = true
	label.width = label_width
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector3(0.0, book_size.y * 0.5 + label_offset, book_size.z * 0.5)
	book.add_child(label)

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = book_size * 1.1
	shape.shape = box

	var spot := InteractiveSpot.new()
	spot.name = "Spot"
	spot.display_name = document.title
	spot.mode = InteractiveSpot.Mode.DETAIL
	spot.document_path = document.source_path
	spot.add_child(shape)
	book.add_child(spot)

	spot.add_highlight_node(mesh)
	spot.add_hover_reveal_node(label)
	shelf.register_child_spot(spot)
	_spots.append(spot)


## Plank the books of [param row] are resting on.
func _add_plank(row: int) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(row_width + 0.1, 0.04, book_size.z + 0.06)

	var plank := MeshInstance3D.new()
	plank.name = "Plank%d" % row
	plank.mesh = box
	plank.position = Vector3(0.0, row * row_spacing - 0.02, 0.0)
	plank.material_override = _book_material(plank_color)
	add_child(plank)


## Horizontal position of a book inside its row, the row being centered.
func _column_x(column: int, in_row: int) -> float:
	var total: float = in_row * book_size.x + maxf(0.0, in_row - 1) * book_spacing
	return -total * 0.5 + book_size.x * 0.5 + column * (book_size.x + book_spacing)


func _book_mesh() -> BoxMesh:
	var box := BoxMesh.new()
	box.size = book_size
	return box


func _book_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

#endregion
