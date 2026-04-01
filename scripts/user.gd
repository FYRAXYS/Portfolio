extends CharacterBody3D

@onready var is_sliding: bool = false
@onready var pivot: Node3D = $CollisionShape3D/Pivot
var speed: float = 10.0
const WALK_SPEED: float = 15.0
const SLIDE_SPEED: float = 25.0
const TURN_SPEED: float = 10.0

var debug_speed_multiplier: float = 1.0
var debug_disable_gravity: bool = false
var debug_noclip: bool = false
var debug_space_velocity: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	speed = (SLIDE_SPEED if is_sliding else WALK_SPEED) * debug_speed_multiplier
	
	var input_direction_2D:Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction:Vector3 = Vector3(input_direction_2D.x, 0, input_direction_2D.y).normalized()
	var angle_rad:float = deg_to_rad(-45.0)
	direction = direction.rotated(Vector3.UP, angle_rad)

	var target_horizontal_velocity: Vector2 = Vector2(direction.x, direction.z) * speed
	var current_horizontal_velocity: Vector2 = Vector2(velocity.x, velocity.z)

	if debug_space_velocity:
		var acceleration: float = 30.0
		var drag: float = 6.0
		var move_rate: float = acceleration if direction != Vector3.ZERO else drag
		current_horizontal_velocity = current_horizontal_velocity.move_toward(target_horizontal_velocity, move_rate * delta)
	else:
		current_horizontal_velocity = target_horizontal_velocity

	velocity.x = current_horizontal_velocity.x
	velocity.z = current_horizontal_velocity.y
	
	if not debug_disable_gravity and not is_on_floor():
		velocity.y -= 20.0 * delta
	elif debug_disable_gravity:
		velocity.y = 0.0
	
	move_and_slide()

	if direction != Vector3.ZERO:
		var target_angle:float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * TURN_SPEED)
	
	if Input.is_action_just_pressed("slide") and is_on_floor():
		change_state(!is_sliding)

func change_state(state: bool) -> void:
	is_sliding = state
	var tween:Tween = create_tween().set_trans(Tween.TRANS_SINE)
	
	if is_sliding:
		tween.tween_property(pivot, "rotation_degrees:x", 90, 0.2)
	
	else:
		tween.tween_property(pivot, "rotation_degrees:x", 0, 0.2)
