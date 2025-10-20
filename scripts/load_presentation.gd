extends Label3D

@onready var JSON_PATH = "res://ressources/text/presentation.json"
@onready var presentation_text:RichTextLabel = %PresentationText
var data:Dictionary = {}


func _ready() -> void:
	presentation_text.text = ""

	read_json(JSON_PATH)
	
	for parties in data :
		if parties == "titre" :
			presentation_text.newline()
			presentation_text.add_text("[b]"+data[parties]+"[/b]")
		else :
			presentation_text.font_size = 12
			presentation_text.text += data[parties]



func read_json(file_path) :
	if !FileAccess.file_exists(file_path) :
		push_error()
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	var json = file.get_as_text()
	var json_object = JSON.new()
	
	json_object.parse(json)
	data = json_object.data
	
	file.close()
