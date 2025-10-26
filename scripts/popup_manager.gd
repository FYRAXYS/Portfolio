extends Control

@onready var ExitButton:Button = %Exit

func _ready() -> void:
	ExitButton.pressed.connect(_on_press)

func _on_press():
	self.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
