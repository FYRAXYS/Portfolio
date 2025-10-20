extends Node3D

const TRANSITION_SPEED: float = 7.0

@onready var TransitionCamera: Camera3D = $World/Cameras/TransitionCamera
@onready var PlayerCamera: Camera3D = $World/Cameras/PlayerCamera
@onready var PresentationCamera: Camera3D = $World/Cameras/PresentationCamera

var target_camera: Camera3D
var selected_camera: Camera3D

# On transforme _ready en une fonction asynchrone pour pouvoir utiliser 'await'
func _ready() -> void:
	# --- LA CORRECTION EST ICI ---
	# On attend la toute première image physique du jeu.
	# Cela garantit que tous les nœuds, y compris PlayerCamera, ont exécuté
	# leur premier _physics_process et sont à leur position de départ correcte.
	await get_tree().physics_frame

	# Maintenant que tout est bien initialisé, on peut configurer les caméras
	# en toute sécurité, en sachant que PlayerCamera.global_transform est correct.
	selected_camera = PlayerCamera
	target_camera = PlayerCamera
	
	TransitionCamera.global_transform = PlayerCamera.global_transform
	TransitionCamera.fov = PlayerCamera.fov
	TransitionCamera.make_current()

func _process(delta: float) -> void:
	#print("PlayerCamera : " , $World/Cameras/PlayerCamera.global_position)
	#print("TransitionCamera : " , $World/Cameras/TransitionCamera.global_position)
	
	if is_instance_valid(target_camera):
		var target_transform = target_camera.global_transform
		TransitionCamera.global_transform = TransitionCamera.global_transform.interpolate_with(target_transform, TRANSITION_SPEED * delta)
		
		var target_fov = target_camera.fov
		TransitionCamera.fov = lerp(TransitionCamera.fov, target_fov, TRANSITION_SPEED * delta)
		
		var distance_to_target = TransitionCamera.global_position.distance_to(target_transform.origin)
		
		if distance_to_target < 0.01:
			TransitionCamera.global_transform = target_transform
			selected_camera = target_camera
			selected_camera.make_current()
			target_camera = null

func _change_camera(new_camera: Camera3D) -> void:
	if new_camera != target_camera and new_camera != selected_camera:
		target_camera = new_camera
		selected_camera = null
		TransitionCamera.make_current()

func _on_area_3d_body_entered(_body: Node3D) -> void:
	_change_camera(PresentationCamera)
	print("entree")

func _on_area_3d_body_exited(_body: Node3D) -> void:
	_change_camera(PlayerCamera)
	print("sortie")
