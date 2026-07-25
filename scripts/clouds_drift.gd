extends Node3D
## À attacher sur le nœud parent qui contient les nuages (ex: "Clouds").
## Chaque enfant se déplace dans la même direction, mais avec sa propre
## vitesse et sa propre échelle, tirées aléatoirement. Quand un nuage
## sort de la zone de vol, il est replacé au départ (hors champ) avec
## de nouvelles valeurs aléatoires -> boucle infinie et jamais identique.
 
@export var direction: Vector3 = Vector3(1, 0, 0.3) # direction commune (sera normalisée)
@export var min_speed: float = 0.15
@export var max_speed: float = 0.45
@export var min_scale: float = 0.3
@export var max_scale: float = 1.7
@export var travel_distance: float = 35.0 # longueur totale du trajet (doit dépasser le champ de vision)
@export var randomize_rotation: bool = true
@export var min_rotation_deg: float = 0.0
@export var max_rotation_deg: float = 360.0 # rotation autour de l'axe Y (vertical)

 
var _dir: Vector3
var _clouds: Array = []
 
func _ready() -> void:
	_dir = direction.normalized()
	for child in get_children():
		if child is Node3D:
			var base_scale: float = child.scale.x # on garde le ratio d'échelle d'origine comme référence
			_clouds.append({
				"node": child,
				"start_pos": child.position, # position de départ définie dans l'éditeur
				"base_scale": base_scale,
				"offset": 0.0,
				"speed": 0.0,
			})
			_reset_cloud(_clouds[-1], true)
 
func _process(delta: float) -> void:
	for data in _clouds:
		data.offset += data.speed * delta
		if data.offset > travel_distance:
			_reset_cloud(data, false)
		data.node.position = data.start_pos + _dir * data.offset
 
func _reset_cloud(data: Dictionary, initial_spawn: bool) -> void:
	data.speed = randf_range(min_speed, max_speed)
	var scale_factor: float = randf_range(min_scale, max_scale)
	data.node.scale = Vector3.ONE * data.base_scale * scale_factor
	if randomize_rotation:
		# Rotation autour de l'axe vertical (Y) uniquement, pour ne pas
		# faire "basculer" le nuage de façon irréaliste.
		var y_rot_deg: float = randf_range(min_rotation_deg, max_rotation_deg)
		data.node.rotation.y = deg_to_rad(y_rot_deg)
	if initial_spawn:
		# Au lancement, on répartit les nuages sur tout le trajet pour ne pas
		# qu'ils partent tous groupés depuis le même point.
		data.offset = randf_range(0.0, travel_distance)
	else:
		data.offset = 0.0