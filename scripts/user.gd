extends CharacterBody3D

@onready var is_sliding: bool = false
@onready var pivot: Node3D = $CollisionShape3D/Pivot
var speed: float = 10.0
const WALK_SPEED: float = 15.0
const SLIDE_SPEED: float = 25.0
const TURN_SPEED: float = 10.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	speed = SLIDE_SPEED if is_sliding else WALK_SPEED
	
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = Vector3(input_direction_2D.x, 0, input_direction_2D.y).normalized()
	var angle_rad = deg_to_rad(-45.0)
	direction = direction.rotated(Vector3.UP, angle_rad)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	move_and_slide()

	if direction != Vector3.ZERO:
		var target_angle = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * TURN_SPEED)
	
	if Input.is_action_just_pressed("slide") and is_on_floor():
		change_state(!is_sliding)

func change_state(state: bool) -> void:
	is_sliding = state
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	
	if is_sliding:
		tween.tween_property(pivot, "rotation_degrees:x", 90, 0.2)
		print("Glissade")
	
	else:
		tween.tween_property(pivot, "rotation_degrees:x", 0, 0.2)
		print("Debout")
