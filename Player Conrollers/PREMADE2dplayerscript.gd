extends CharacterBody2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity") #980
var stand_threshold = 100
var hook_point = Vector2.ZERO
var hook_length = 0
@export var centri_force : Vector2

@export var bounce := .4
var can_bounce = false

@onready var babyboo_sprite = $CollisionPolygon2D

@onready var default_scale_sprite = $CollisionPolygon2D/Sprite2D.scale

func _physics_process(delta):
	$CollisionPolygon2D/Sprite2D.scale.y = (default_scale_sprite.y + velocity.length() / 1500 + .2)
	$CollisionPolygon2D/Sprite2D.scale.x = (default_scale_sprite.x - velocity.length() / 2500 + .2)
	
#region JUNK you dont have to care abouts
	if not is_on_floor():
		velocity.y += gravity * delta
		
	if get_last_slide_collision() != null:
		velocity += get_last_slide_collision().get_normal() * (bounce * get_real_velocity().length())
		velocity = lerp(velocity, Vector2.ZERO, delta * 3)
		reset_bounce()
		
		
		if get_last_slide_collision():
			pass
	if !get_floor_normal():
		var forward_rotation = atan2(get_real_velocity().y, get_real_velocity().x) - PI/2
	if get_real_velocity().length() >= stand_threshold:
		babyboo_sprite.rotation = lerp_angle(babyboo_sprite.rotation, atan2(get_real_velocity().y, get_real_velocity().x) - PI/2, 25*delta)
	else:
		babyboo_sprite.rotation = lerp_angle(babyboo_sprite.rotation, 0, 12*delta)
	if get_last_slide_collision(): velocity += transform.x * delta * 50
	launch(delta)
	grapple(delta)
	babyboo_sprite.scale.x = lerp(babyboo_sprite.scale.x, 1.0, delta * 8)
	babyboo_sprite.scale.y = lerp(babyboo_sprite.scale.y, 1.0, delta * 2)
	
	move_and_slide()
#endregion

func launch(delta):
	if Input.is_action_just_pressed("left_click") and can_bounce:
		can_bounce = false
		velocity *= 0
		modulate.r = 0
		$CollisionPolygon2D/Sprite2D.play("default")
		velocity += (get_global_mouse_position() - global_position).normalized() * 600
		
	
func grapple(delta):
	$HookPoint/Hook.set_point_position(0, global_position)
	$HookPoint/Hook.set_point_position(1, $HookPoint.global_position)
	if hook_point:
		if (hook_point - global_position).length() > hook_length:
			
			var angle_dif = hook_point-global_position
			centri_force = ((angle_dif).dot(velocity)/angle_dif.length_squared())*angle_dif
			velocity += -centri_force

func hurt(direction, damage_percent): #damage percent is just a whole number that 
	velocity += direction
	babyboo_sprite.scale.y = 1.5
	babyboo_sprite.scale.x = .5

func reset_bounce():
	can_bounce = true
	modulate.r = 1.0
	$CollisionPolygon2D/Sprite2D.play("red")

func boost():
	#velocity *= 1.3 
	velocity += + Vector2(0,-200)
	reset_bounce()
