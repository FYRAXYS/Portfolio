extends Camera3D

@onready var player_path: CharacterBody3D = $"../../CharacterBody3D"
@export var offset: Vector3 = Vector3(-8, 12, 8)
@export var follow_speed: float = 5.0

var player: Node3D = null
var fixed_rotation_degrees: Vector3

func _ready() -> void:
	player = get_node("../../CharacterBody3D")
	if not player:
		push_error("PlayerCamera : player_path incorrect ou node introuvable : %s" % player_path)
	# mémorise l'angle fixe donné dans l'éditeur
	top_level = true
	fixed_rotation_degrees = rotation_degrees
	# Pour debug, tu peux décommenter la ligne suivante pour voir si la camera devient visible :
	#make_current()

func _physics_process(_delta: float) -> void:
	if not player:
		return
	#var target_pos: Vector3 = player.global_position + offset
	#global_position = global_position.lerp(target_pos, clamp(follow_speed * delta, 0.0, 1.0))
	#rotation_degrees = fixed_rotation_degrees
	self.global_position = player_path.global_position + offset
