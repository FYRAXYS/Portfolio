extends Node3D

const TRANSITION_SPEED: float = 5.0

@onready var transition_rect = $TransitionLayer/ColorRect

func _ready() -> void:
	await get_tree().physics_frame

	transition_rect.show()
	transition_rect.modulate.a = 1.0

	if OS.has_feature("web"):
		await get_tree().create_timer(1.0).timeout
	

	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT)
	tween.tween_callback(transition_rect.queue_free)
