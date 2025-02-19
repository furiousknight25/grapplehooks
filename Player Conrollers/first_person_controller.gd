extends CharacterBody3D
@onready var camera_3d: Camera3D = $Camera3D
@onready var look_ray_cast: RayCast3D = $Camera3D/LookRayCast

var mouse_sensitivity = 0.002
var jump_strength = 3
var friction = .1
var air_acceleration = .3
var jump_buffer = .2

var hook_point = Vector3.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _physics_process(delta: float) -> void:
	
	var input = Input.get_vector('left',"right","forward","back")
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y) #makes sure the forward is the forward you are facing
	jump_buffer -= delta
	if Input.is_action_just_pressed('jump'): jump_buffer = .2
	
	if is_on_floor():
		var current_friction: Vector2 = Vector2(velocity.x, velocity.z).rotated(PI) * friction
		var friction_dir = transform.basis * Vector3(current_friction.x, 0, current_friction.y)
		velocity += Vector3(current_friction.x, 0, current_friction.y)
		velocity += Vector3(movement_dir.x, 0, movement_dir.z)
		if jump_buffer >= 0:
			velocity.y += jump_strength
			jump_buffer = .2
	else:
		velocity += Vector3(movement_dir.x * air_acceleration, 0, movement_dir.z * air_acceleration)
		
	velocity.y -= 9.8 * delta#gravity
	
	
	hook_one_manager(delta)
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_3d.rotate_x(-event.relative.y * mouse_sensitivity)


func hook_one_manager(delta):
	if Input.is_action_just_pressed("left_click"):
		hook_point = look_ray_cast.get_collision_point()
	if Input.is_action_just_released("left_click"):
		hook_point = Vector3.ZERO
	
	if hook_point:
		velocity += (hook_point - global_position).normalized() * 30 * delta
	else:
		if look_ray_cast.is_colliding():
			look_ray_cast.get_child(0).global_position = look_ray_cast.get_collision_point()
	
