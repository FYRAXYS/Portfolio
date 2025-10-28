extends Node3D
@onready var PressText:Label3D =$Bouton.get_child(0)
@onready var PopUpScenePath = $"../../PopUps/popup_container"
@onready var popup_number = NodePath(PressText.name)

var is_player_inside_area:bool
signal inside_area
signal outside_area


func _ready() -> void:
	PressText.hide()
	is_player_inside_area = false


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact") and is_player_inside_area :
		print("sucess")
		PopUpScenePath.get_node(popup_number).show()
		$"../../PopUps/popup_container/InteractText".hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true


func _on_area_3d_body_entered(_body: Node3D) -> void:
	PressText.show()
	is_player_inside_area = true
	inside_area.emit()


func _on_area_3d_body_exited(_body: Node3D) -> void:
	PressText.hide()
	is_player_inside_area = false
	outside_area.emit()
