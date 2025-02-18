extends CharacterBody2D

enum STATES {SWINGING, THROWN, LOCKED}
var cur_state = STATES.SWINGING

@onready var player : CharacterBody2D = get_parent()
var hook_point = Vector2.ZERO

func _ready() -> void:
	add_collision_exception_with(player)
	global_position = player.global_position


func _physics_process(delta: float) -> void:
	match cur_state:
		STATES.SWINGING:
			#lets spring this shit
			swinging_process(delta)
		STATES.THROWN:
			thrown_process(delta)
		STATES.LOCKED:
			locked_process(delta)
	move_and_slide()

var tension := 300.0
var damping := 20.0

func swinging_process(delta):
	var displacement = global_position - player.global_position
	
	var force = -tension * displacement - damping * velocity
	velocity += force * delta
	
	if Input.is_action_just_pressed("right_click"): #SET STATE THROW
		cur_state = STATES.THROWN
		wall_min_slide_angle = PI/2
		velocity += (get_global_mouse_position() - global_position).normalized() * 3500 #throw strength
		
func thrown_process(delta):
	if Input.is_action_just_released("right_click"):
		set_state_swing()
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if (collision == null):
			continue
		var collider = collision.get_collider()
		if collider.is_in_group('enemy'):
			set_state_locked(collider.global_position)
			global_position = collider.global_position
			collider.die()
		else:
			set_state_locked(global_position)
	
func locked_process(delta):
	
	velocity = Vector2.ZERO
	
	if Input.is_action_just_released("right_click"):
		set_state_swing()
		player.velocity.y += -400
	#check rope collisions here and letting go

func set_state_locked(lock_point):
	cur_state = STATES.LOCKED
	hook_point = lock_point
	player.hook_point = hook_point
	player.hook_length = (hook_point - player.global_position).length()
	#move_and_slide()

func set_state_swing():
	cur_state = STATES.SWINGING
	hook_point = Vector2.ZERO
	player.hook_point = Vector2.ZERO
	wall_min_slide_angle = 0
	
