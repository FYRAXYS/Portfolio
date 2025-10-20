extends Node3D

@onready var JSON_PATH = "res://ressources/text/json/" + self.name + ".json"
@onready var presentation_text:RichTextLabel = %Text
@onready var subviewport:SubViewport = $SubViewport
@onready var quad:MeshInstance3D = $Quad
#@onready var panel:Panel = $SubViewport/Panel

var data:Dictionary = {}
var default_quad_scale_y:float
var default_viewport_size_y:float

func _ready() -> void:
	default_quad_scale_y = quad.scale.y
	default_viewport_size_y = subviewport.size.y
	
	read_json(JSON_PATH)
	await get_tree().process_frame #attente d'une frame
	update_size()

func update_size() -> void :
	var content_height:float = presentation_text.get_content_height()
	subviewport.size.y = int(content_height)
	
	var ratio_y:float
	if default_viewport_size_y > 0:
		ratio_y = content_height / default_viewport_size_y
	else :
		ratio_y = 1.0
	
	quad.scale.y = default_quad_scale_y * ratio_y


func read_json(file_path):
	if not FileAccess.file_exists(file_path):
		push_error("Fichier JSON non trouvé: " + file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = file.get_as_text()
	file.close()

	var json_object = JSON.new()
	var error = json_object.parse(json)
	if error != OK:
		push_error("Erreur de parsing JSON: " + json_object.get_error_message())
		return
		
	data = json_object.data
	presentation_text.text = ""
	
	for partie in data:
		var text_content = str(data[partie]) # S'assurer que c'est une chaîne
		presentation_text.append_text(text_content)
