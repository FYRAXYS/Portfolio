extends Control

func _ready() -> void:
	%InteractText.hide()

func _on_platform_inside_area() -> void:
	%InteractText.pivot_offset = %InteractText.size / 2
	%InteractText.show()
	var tween:Tween = create_tween()
	tween.tween_property(%InteractText,"scale",Vector2.ONE * 1.5,0.2)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_platform_outside_area() -> void:
	%InteractText.pivot_offset = %InteractText.size / 2
	var tween:Tween = create_tween()
	tween.tween_property(%InteractText,"scale",Vector2.ONE / 1.5 ,0.2)
	await get_tree().create_timer(0.2).timeout
	%InteractText.hide()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

#func _on_text_hover() -> void:
	#print("hover")
	#%InteractText/Label.font_color = Color(0.6, 0.596, 0.0, 1.0)
#
#func _on_text_unhover() -> void:
	#%InteractText/Label.font_color = Color(0.0, 0.0, 0.0, 1.0)
