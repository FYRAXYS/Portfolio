extends Control

@onready var ExitButton:Button = %Exit

func _ready() -> void:
	ExitButton.pressed.connect(_on_press)

func _on_press():

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.1)
	tween.finished.connect(self.hide)

	get_tree().paused = false
