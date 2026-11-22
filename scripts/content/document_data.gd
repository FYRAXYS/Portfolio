class_name DocumentData
extends RefCounted
## Content of a single markdown document (a project README or a static page),
## already converted to BBCode. Instances are built by [MarkdownParser] and
## cached by [ContentLibrary].


## File name without its ordering prefix and extension ("01-foo.md" -> "foo").
var id: String = ""
## Title shown on the first page and on the viewer header.
var title: String = ""
## Optional single line shown under the title.
var subtitle: String = ""
## Front matter entries displayed as metadata, as [code]{key, value, icon}[/code].
var meta: Array[Dictionary] = []
## Color used by the generated book spines.
var color: Color = Color(0.4, 0.27, 0.2)
## Optional "res://" path of an image shown on the first page.
var cover: String = ""
## Document body, converted to BBCode.
var body: String = ""
## "res://" path the document was read from.
var source_path: String = ""


## Full BBCode of the document: header block (title, metadata, cover) then body.
func to_bbcode() -> String:
	var parts: Array[String] = []

	parts.append("[center][font_size=%d][b]%s[/b][/font_size][/center]" % [
		MarkdownParser.TITLE_SIZE, title
	])

	if not subtitle.is_empty():
		parts.append("[center][font_size=%d][i]%s[/i][/font_size][/center]" % [
			MarkdownParser.SUBTITLE_SIZE, subtitle
		])

	var meta_line: String = _meta_to_bbcode()
	if not meta_line.is_empty():
		parts.append(meta_line)

	if not cover.is_empty():
		parts.append("[center][img=%d]%s[/img][/center]" % [MarkdownParser.COVER_WIDTH, cover])

	parts.append("[center]%s[/center]" % MarkdownParser.RULE)

	if not body.is_empty():
		parts.append(body)

	return "\n\n".join(parts)


## One centered line per metadata entry, prefixed by its icon when there is one.
func _meta_to_bbcode() -> String:
	if meta.is_empty():
		return ""

	var lines: Array[String] = []
	for entry: Dictionary in meta:
		var icon := String(entry.get("icon", ""))
		var prefix: String = ""
		if not icon.is_empty():
			prefix = "[img=%d]%s[/img]  " % [MarkdownParser.META_ICON_SIZE, icon]
		else:
			prefix = "%s : " % String(entry.get("key", "")).capitalize()
		lines.append("%s%s" % [prefix, String(entry.get("value", ""))])

	return "[center][font_size=%d]%s[/font_size][/center]" % [
		MarkdownParser.META_SIZE, "    ".join(lines)
	]
