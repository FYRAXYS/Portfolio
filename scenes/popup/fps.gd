extends Label

func _process(_delta: float) -> void:
	#print(Engine.get_frames_per_second())
	self.text = str(Engine.get_frames_per_second())
