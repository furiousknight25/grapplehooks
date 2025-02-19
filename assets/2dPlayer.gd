extends CharacterBody2D

var jump_strength = 300
var speed = 120
var friction = .3
func _physics_process(delta: float) -> void:
	
	var input = Input.get_axis('left',"right")
	
	if is_on_floor():
		var current_friction: Vector2 = Vector2(velocity.x, velocity.y).rotated(PI) * friction
		velocity += Vector2(current_friction.x, current_friction.y)
		velocity.x += input * speed
	
	if Input.is_action_just_pressed('jump') or Input.is_action_just_pressed("forward"):
		velocity.y -= jump_strength
		
	velocity.y += 980 * delta#gravity
	
	
	move_and_slide()
