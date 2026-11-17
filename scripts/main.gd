extends Node
## Main scene entry point for the portfolio.
## This file is only used for setting up the [Game] class in the _ready() function.

@onready var world_host: Node = $WorldHost


func _ready() -> void:
	Game.world_host = world_host

	# Start the scene as a black screen for security (some 3d meshs might be loaded before the materials)
	Game.set_black(true)

	await get_tree().physics_frame

	if OS.has_feature("web"):
		# small timeout on web exports while the shaders are compiling
		await get_tree().create_timer(1.0).timeout
	
	await Game.change_world(Game.EXTERIOR_SCENE, 2.0)
