class_name MarkdownParser
extends RefCounted
## Converts the subset of markdown used by the portfolio documents into the
## BBCode understood by [RichTextLabel].
##
## Supported syntax: front matter, ATX headings, unordered and ordered lists,
## quotes, horizontal rules, fenced code blocks, images, links, bold, italic
## and inline code. Anything else is kept as plain text.


#region Layout constants
## Font sizes (in pixels of the page viewport) used by the generated BBCode.
const TITLE_SIZE := 30
const SUBTITLE_SIZE := 17
const META_SIZE := 15
const META_ICON_SIZE := 20
const H1_SIZE := 26
const H2_SIZE := 22
const H3_SIZE := 19
const CODE_SIZE := 14

## Width in pixels of the images inserted in a page.
const COVER_WIDTH := 380
const IMAGE_WIDTH := 420

## Separator inserted between the header block and the body of a document.
const RULE := "[font_size=16]* * *[/font_size]"
#endregion

#region Parsing constants
## Front matter keys that are not displayed as metadata.
const RESERVED_KEYS := ["title", "subtitle", "color", "cover"]

## Icon displayed in front of a metadata entry, by front matter key.
const META_ICONS := {
	"date": "res://ressources/images/clock.png",
	"team": "res://ressources/images/group.png",
	"equipe": "res://ressources/images/group.png",
	"tech": "res://ressources/images/code.png",
	"techno": "res://ressources/images/code.png",
}

## Markers wrapping the inline parts that must not be parsed twice.
const PLACEHOLDER_BEGIN := "\u0001"
const PLACEHOLDER_END := "\u0002"
#endregion


#region Entry points

## Read and parse the markdown file at [param path]. Returns [code]null[/code]
## when the file cannot be read.
static func parse_file(path: String) -> DocumentData:
	if not FileAccess.file_exists(path):
		push_error("MarkdownParser: no document found at %s" % path)
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MarkdownParser: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return null

	var text: String = file.get_as_text()
	file.close()

	return parse(text, path)


## Parse the markdown [param text] coming from [param source_path].
static func parse(text: String, source_path: String = "") -> DocumentData:
	var document := DocumentData.new()
	document.source_path = source_path
	document.id = _path_to_id(source_path)

	var base_dir := "res://"
	if not source_path.is_empty():
		base_dir = source_path.get_base_dir()

	var split: Array = _split_front_matter(text.replace("\r\n", "\n"))
	var front_matter: Dictionary = split[0]
	var body: String = split[1]

	_apply_front_matter(document, front_matter, base_dir)

	# A document without a "title" key falls back to its first heading.
	if document.title.is_empty():
		var heading: String = _first_heading(body)
		if heading.is_empty():
			document.title = document.id.capitalize()
		else:
			document.title = heading
			body = _remove_first_heading(body)

	document.body = body_to_bbcode(body, base_dir)
	return document

#endregion
#region Front matter

## Separate the leading "---" block from the body.
## Returns [code][front_matter, body][/code].
static func _split_front_matter(text: String) -> Array:
	var front_matter := {}
	var trimmed: String = text.lstrip(" \t\n")
	if not trimmed.begins_with("---"):
		return [front_matter, text]

	var lines: PackedStringArray = trimmed.split("\n")
	var index := 1
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		index += 1
		if line == "---":
			break
		var separator: int = line.find(":")
		if line.is_empty() or separator <= 0:
			continue
		var key: String = line.substr(0, separator).strip_edges().to_lower()
		var value: String = line.substr(separator + 1).strip_edges()
		front_matter[key] = value.lstrip("\"'").rstrip("\"'")

	return [front_matter, "\n".join(lines.slice(index))]


## Copy the front matter entries into [param document].
static func _apply_front_matter(document: DocumentData, front_matter: Dictionary, base_dir: String) -> void:
	document.title = String(front_matter.get("title", ""))
	document.subtitle = String(front_matter.get("subtitle", ""))

	var color_value := String(front_matter.get("color", ""))
	if not color_value.is_empty() and Color.html_is_valid(color_value):
		document.color = Color.html(color_value)

	var cover_value := String(front_matter.get("cover", ""))
	if not cover_value.is_empty():
		document.cover = _resolve_path(cover_value, base_dir)

	for key: String in front_matter:
		if RESERVED_KEYS.has(key):
			continue
		var value := String(front_matter[key])
		if value.is_empty():
			continue
		document.meta.append({
			"key": key,
			"value": value,
			"icon": String(META_ICONS.get(key, "")),
		})

#endregion
#region Body

## Convert the body of a document into BBCode, block by block.
static func body_to_bbcode(text: String, base_dir: String) -> String:
	var blocks: Array[String] = []
	var paragraph: Array[String] = []
	var list_items: Array[String] = []
	var code_lines: Array[String] = []
	var in_code_block := false

	for raw_line: String in text.split("\n"):
		var line: String = raw_line.rstrip(" \t")
		var stripped: String = line.strip_edges()

		# Fenced code block: everything inside is kept as it is written.
		if stripped.begins_with("```"):
			if in_code_block:
				blocks.append(_code_to_bbcode(code_lines))
				code_lines.clear()
			else:
				_flush_paragraph(blocks, paragraph, base_dir)
				_flush_list(blocks, list_items)
			in_code_block = not in_code_block
			continue
		if in_code_block:
			code_lines.append(line)
			continue

		if stripped.is_empty():
			_flush_paragraph(blocks, paragraph, base_dir)
			_flush_list(blocks, list_items)
			continue

		if _is_rule(stripped):
			_flush_paragraph(blocks, paragraph, base_dir)
			_flush_list(blocks, list_items)
			blocks.append("[center]%s[/center]" % RULE)
			continue

		if stripped.begins_with("#"):
			_flush_paragraph(blocks, paragraph, base_dir)
			_flush_list(blocks, list_items)
			blocks.append(_heading_to_bbcode(stripped, base_dir))
			continue

		if stripped.begins_with(">"):
			_flush_paragraph(blocks, paragraph, base_dir)
			_flush_list(blocks, list_items)
			blocks.append("[indent][i]%s[/i][/indent]" % inline_to_bbcode(
				stripped.substr(1).strip_edges(), base_dir
			))
			continue

		var item: String = _list_item_to_bbcode(line, base_dir)
		if not item.is_empty():
			_flush_paragraph(blocks, paragraph, base_dir)
			list_items.append(item)
			continue

		_flush_list(blocks, list_items)
		paragraph.append(stripped)

	if not code_lines.is_empty():
		blocks.append(_code_to_bbcode(code_lines))
	_flush_paragraph(blocks, paragraph, base_dir)
	_flush_list(blocks, list_items)

	return "\n\n".join(blocks)


## Append the pending paragraph lines as a single justified block.
static func _flush_paragraph(blocks: Array[String], paragraph: Array[String], base_dir: String) -> void:
	if paragraph.is_empty():
		return
	blocks.append(inline_to_bbcode(" ".join(paragraph), base_dir))
	paragraph.clear()


## Append the pending list items as a single block.
static func _flush_list(blocks: Array[String], list_items: Array[String]) -> void:
	if list_items.is_empty():
		return
	blocks.append("\n".join(list_items))
	list_items.clear()


## Wrap the lines of a fenced code block in a monospaced BBCode block.
static func _code_to_bbcode(code_lines: Array[String]) -> String:
	return "[font_size=%d][code]%s[/code][/font_size]" % [CODE_SIZE, "\n".join(code_lines)]


## "## Title" -> a bold line sized after the heading level.
static func _heading_to_bbcode(line: String, base_dir: String) -> String:
	var level := 0
	while level < line.length() and line[level] == "#":
		level += 1

	var content: String = inline_to_bbcode(line.substr(level).strip_edges(), base_dir)
	var size: int = H3_SIZE
	match level:
		1:
			size = H1_SIZE
		2:
			size = H2_SIZE

	return "[font_size=%d][b]%s[/b][/font_size]" % [size, content]


## "- item" or "1. item" -> an indented line. Returns "" for anything else.
static func _list_item_to_bbcode(line: String, base_dir: String) -> String:
	var indent_width: int = line.length() - line.lstrip(" \t").length()
	var stripped: String = line.strip_edges()
	var content := ""
	var bullet := ""

	if stripped.length() > 2 and stripped[0] in ["-", "*", "+"] and stripped[1] == " ":
		bullet = "•  "
		content = stripped.substr(2)
	else:
		var dot: int = stripped.find(". ")
		if dot > 0 and stripped.substr(0, dot).is_valid_int():
			bullet = "%s.  " % stripped.substr(0, dot)
			content = stripped.substr(dot + 2)

	if content.is_empty():
		return ""

	var depth: int = 1 + int(indent_width / 2.0)
	return "%s%s%s%s" % [
		"[indent]".repeat(depth),
		bullet,
		inline_to_bbcode(content, base_dir),
		"[/indent]".repeat(depth),
	]


## True for "---", "***" and "___" separator lines.
static func _is_rule(line: String) -> bool:
	if line.length() < 3:
		return false
	for marker: String in ["-", "*", "_"]:
		if line == marker.repeat(line.length()):
			return true
	return false

#endregion
#region Inline

## Convert the inline markup of a single text run into BBCode.
static func inline_to_bbcode(text: String, base_dir: String) -> String:
	var protected: Array[String] = []
	var result: String = text

	# Code spans, images and links are converted first and set aside so their
	# content is never read as markdown or as BBCode afterwards.
	result = _protect(result, "`([^`]+)`", protected,
		func(groups: PackedStringArray) -> String:
			return "[code]%s[/code]" % _escape_brackets(groups[1])
	)
	result = _protect(result, "!\\[([^\\]]*)\\]\\(([^)]+)\\)", protected,
		func(groups: PackedStringArray) -> String:
			return "[center][img=%d]%s[/img][/center]" % [IMAGE_WIDTH, _resolve_path(groups[2], base_dir)]
	)
	result = _protect(result, "\\[([^\\]]+)\\]\\(([^)]+)\\)", protected,
		func(groups: PackedStringArray) -> String:
			return "[url=%s]%s[/url]" % [groups[2], _escape_brackets(groups[1])]
	)

	result = _escape_brackets(result)
	result = _wrap(result, "\\*\\*([^*]+)\\*\\*", "b")
	result = _wrap(result, "__([^_]+)__", "b")
	result = _wrap(result, "\\*([^*]+)\\*", "i")
	result = _wrap(result, "(?<![a-zA-Z0-9])_([^_]+)_(?![a-zA-Z0-9])", "i")

	# Put the protected parts back now that no further pass can alter them.
	for index: int in protected.size():
		result = result.replace(_placeholder(index), protected[index])
	return result


## Replace every match of [param pattern] by a placeholder and store the BBCode
## returned by [param builder] so it can be restored at the end.
static func _protect(text: String, pattern: String, protected: Array[String], builder: Callable) -> String:
	var regex: RegEx = RegEx.create_from_string(pattern)
	if regex == null:
		return text

	var result: String = text
	var offset := 0
	var found: RegExMatch = regex.search(result, offset)
	while found != null:
		protected.append(String(builder.call(found.strings)))
		var placeholder: String = _placeholder(protected.size() - 1)
		result = result.substr(0, found.get_start()) + placeholder + result.substr(found.get_end())
		offset = found.get_start() + placeholder.length()
		found = regex.search(result, offset)
	return result


## Surround every match of [param pattern] with the BBCode tag [param tag].
static func _wrap(text: String, pattern: String, tag: String) -> String:
	var regex: RegEx = RegEx.create_from_string(pattern)
	if regex == null:
		return text
	return regex.sub(text, "[%s]$1[/%s]" % [tag, tag], true)


## Keep the square brackets written by the author out of the BBCode parser.
static func _escape_brackets(text: String) -> String:
	return text.replace("[", "[lb]")


static func _placeholder(index: int) -> String:
	return "%s%d%s" % [PLACEHOLDER_BEGIN, index, PLACEHOLDER_END]

#endregion
#region Helpers

## Turn a relative markdown path into a "res://" path.
static func _resolve_path(path: String, base_dir: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.begins_with("http"):
		return path
	return base_dir.path_join(path).simplify_path()


## "res://content/projects/01-my-project.md" -> "my-project".
static func _path_to_id(path: String) -> String:
	var file_name: String = path.get_file().get_basename()
	var separator: int = file_name.find("-")
	if separator > 0 and file_name.substr(0, separator).is_valid_int():
		file_name = file_name.substr(separator + 1)
	return file_name


## First ATX heading of [param text], without its "#" markers.
static func _first_heading(text: String) -> String:
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			return stripped.lstrip("#").strip_edges()
	return ""


## Same text without its first ATX heading line.
static func _remove_first_heading(text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	for index: int in lines.size():
		if lines[index].strip_edges().begins_with("#"):
			lines.remove_at(index)
			break
	return "\n".join(lines)

#endregion
