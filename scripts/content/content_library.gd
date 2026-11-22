class_name ContentLibrary
extends RefCounted
## Lists and caches the markdown documents shipped with the project.
##
## Adding a project only means dropping a new markdown file in
## [constant PROJECTS_DIR]: the books of the interior bookshelf and their
## content are built from whatever this class finds there.
##
## [b]Note:[/b] markdown files are not Godot resources, so the export preset
## must keep them with the "*.md" non-resource filter.


## Folder scanned by [method list_projects], one file per project.
const PROJECTS_DIR := "res://content/projects"
## Folder holding the documents opened from a single element (skills, resume...).
const PAGES_DIR := "res://content/pages"

const EXTENSION := ".md"

## Parsed documents, by "res://" path.
static var _cache: Dictionary = {}


## Every project document, ordered by file name so a "01-" prefix controls the
## order the books are placed on the shelf.
static func list_projects() -> Array[DocumentData]:
	var documents: Array[DocumentData] = []
	for path: String in list_project_paths():
		var document: DocumentData = get_document(path)
		if document != null:
			documents.append(document)
	return documents


## Sorted "res://" paths of every project document.
static func list_project_paths() -> PackedStringArray:
	return _list_markdown(PROJECTS_DIR)


## Parse the document at [param path], or return the already parsed one.
static func get_document(path: String) -> DocumentData:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]

	var document: DocumentData = MarkdownParser.parse_file(path)
	if document != null:
		_cache[path] = document
	return document


## Forget every parsed document, so the next call reads the files again.
static func clear_cache() -> void:
	_cache.clear()


## Sorted markdown file paths found in [param directory].
static func _list_markdown(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(directory):
		push_warning("ContentLibrary: %s does not exist, no document loaded." % directory)
		return paths

	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.to_lower().ends_with(EXTENSION):
			paths.append(directory.path_join(file_name))

	if paths.is_empty():
		push_warning(
			"ContentLibrary: no document found in %s. On an exported build, check that the export preset keeps the \"*.md\" files."
			% directory
		)

	paths.sort()
	return paths
