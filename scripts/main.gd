extends Node3D

const TRANSITION_SPEED: float = 5.0

@onready var TransitionCamera: Camera3D = $World/Cameras/TransitionCamera
@onready var PlayerCamera: Camera3D = $World/Cameras/PlayerCamera
@onready var PresentationCamera: Camera3D = $World/Cameras/PresentationCamera
@onready var BeginCamera: Camera3D = $World/Cameras/BeginCamera

var target_camera: Camera3D
var selected_camera: Camera3D
# Variable pour empêcher de relancer la transition en boucle
var game_started: bool = false 

func _ready() -> void:
	await get_tree().physics_frame
	
	# État initial : on est sur la BeginCamera
	selected_camera = BeginCamera
	# target_camera doit être null au début pour ne pas déclencher de mouvement
	target_camera = null 
	
	# IMPORTANT : La caméra de transition doit se caler sur la caméra de DÉBUT
	TransitionCamera.global_transform = BeginCamera.global_transform
	TransitionCamera.fov = BeginCamera.fov
	
	BeginCamera.make_current()


func _process(delta: float) -> void:
	# 1. Gestion du DÉMARRAGE (ne s'exécute qu'une seule fois)
	if not game_started and Input.is_anything_pressed():
		game_started = true
		
		# On aligne la caméra de transition sur la vue actuelle (Begin)
		TransitionCamera.global_transform = BeginCamera.global_transform
		TransitionCamera.fov = BeginCamera.fov
		
		# On lance la transition vers le joueur
		_change_camera(PlayerCamera)
	
	# 2. Gestion de la TRANSITION (s'exécute à chaque frame si une cible existe)
	# Ce bloc doit être en dehors du "if Input..."
	if is_instance_valid(target_camera):
		var target_transform = target_camera.global_transform
		TransitionCamera.global_transform = TransitionCamera.global_transform.interpolate_with(target_transform, TRANSITION_SPEED * delta)
		
		var target_fov = target_camera.fov
		TransitionCamera.fov = lerp(TransitionCamera.fov, target_fov, TRANSITION_SPEED * delta)
		
		var distance_to_target = TransitionCamera.global_position.distance_to(target_transform.origin)
		
		# Fin de la transition
		if distance_to_target < 0.01:
			TransitionCamera.global_transform = target_transform
			selected_camera = target_camera
			selected_camera.make_current()
			target_camera = null # On arrête le lerp

func _change_camera(new_camera: Camera3D) -> void:
	# On s'assure qu'on ne change pas pour la caméra déjà active
	if new_camera != selected_camera:
		target_camera = new_camera
		selected_camera = null # On n'a plus de caméra fixe sélectionnée
		TransitionCamera.make_current() # La caméra de transition prend le relais visuel

func _on_area_3d_body_entered(_body: Node3D) -> void:
	if game_started: # On ne change que si le jeu a commencé
		_change_camera(PresentationCamera)

func _on_area_3d_body_exited(_body: Node3D) -> void:
	if game_started:
		_change_camera(PlayerCamera)
