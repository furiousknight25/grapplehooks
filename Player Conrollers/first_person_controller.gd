extends CharacterBody3D
@onready var camera_3d: Camera3D = $Camera3D
@onready var look_ray_cast: RayCast3D = $Camera3D/LookRayCast
@onready var grapple_start: MeshInstance3D = $GrappleHook1/GrappleStart
@onready var grapple_end: MeshInstance3D = $GrappleHook1/GrappleEnd
@onready var line: Path3D = $GrappleHook1/Line

enum STATE {GROUNDED, AIR, GRAPPLE}
var cur_state = STATE.GROUNDED

var mouse_sensitivity = 0.002
var jump_strength = 2
var friction = .1
var air_acceleration = .3
var jump_buffer = .1
var speed = 1
var hook_point = Vector3.ZERO
var rope_amplitude = .5

var tendons = {}
func _ready() -> void:
	for i in line.curve.point_count:
		tendons[i] =  Vector3.ZERO
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	
func _physics_process(delta: float) -> void:
	$UI/Velocity.text = str(snapped((velocity.length()), 0.01))
	var input = Input.get_vector('left',"right","forward","back")
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y) * speed #makes sure the forward is the forward you are facing
	jump_buffer -= delta
	if Input.is_action_pressed('jump'): jump_buffer = .1
	
	match cur_state:
		STATE.GROUNDED:
			var current_friction: Vector2 = Vector2(velocity.x, velocity.z).rotated(PI) * friction
			var friction_dir = transform.basis * Vector3(current_friction.x, 0, current_friction.y)
			velocity += Vector3(current_friction.x, 0, current_friction.y)
			velocity += Vector3(movement_dir.x, 0, movement_dir.z)
			if jump_buffer >= 0:
				velocity.y += jump_strength
				jump_buffer = .1
		STATE.AIR:
			
			sv_airaccelerate(movement_dir, delta)
		STATE.GRAPPLE:
			
			manage_rope(delta)
	if cur_state != STATE.GRAPPLE:
		if is_on_floor(): cur_state = STATE.GROUNDED
		else: cur_state = STATE.AIR
	
	hook_one_manager(delta)
	velocity.y -= 9.8 * delta
	move_and_slide()

func sv_airaccelerate(movement_dir, delta):
	movement_dir = movement_dir * 3
	var wish_speed = movement_dir.length()
	
	if wish_speed > 1:
		wish_speed = 1
	
	var current_speed = velocity.dot(movement_dir)
	var add_speed = wish_speed - current_speed
	if add_speed <= 0:
		return
	
	var accel_speed = 10 * 10 * delta
	if accel_speed > add_speed:
		accel_speed = add_speed
	
	velocity += accel_speed * movement_dir
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_3d.rotate_x(-event.relative.y * mouse_sensitivity)

var sin_mag = 1
var hooked = false
var retracted = false

func hook_one_manager(delta):
	if Input.is_action_just_pressed("left_click"):
		rope_amplitude = .5
		cur_state = STATE.GRAPPLE
		#velocity += Vector3(0,2,0)
		hook_point = look_ray_cast.get_collision_point()
		var tween = get_tree().create_tween()
		tween.tween_property(grapple_end, 'global_position', hook_point, .1)
		generate_rope((global_position-hook_point).length())
		retracted = false
		await tween.finished
		hooked = true
	
	if Input.is_action_just_released("left_click"):
		cur_state = STATE.AIR
		hook_point = Vector3.ZERO
		hook_point = look_ray_cast.get_collision_point()
		var tween = get_tree().create_tween()
		tween.tween_property(grapple_end, 'global_position', grapple_start.global_position, .1)
		hooked = false
		await tween.finished
		retracted = true
	#Engine.time_scale = .1
	if hooked:
		pass
		#velocity += (hook_point - global_position).normalized() * 30 * delta #v1 grapple
	else:
		if look_ray_cast.is_colliding():
			look_ray_cast.get_child(0).global_position = look_ray_cast.get_collision_point()
	
	if !retracted:
		
		grapple_end.show()
		line.show()
	else:
		grapple_end.global_position = grapple_start.global_position
		grapple_end.hide()
		line.hide()
	
	amplitude_spring(delta)
	
	
var vel := .01
var goal := 0.0
var tension := 500.0
var damping := 10.0

func amplitude_spring(delta): 
	var displacement = rope_amplitude - goal
	
	var force = -tension * displacement - damping * vel
	vel += force * delta
	rope_amplitude += vel * delta
	
	
func generate_rope(length):
	return
	#line
	for i in floor(length):
		line.curve.add_point(Vector3.ZERO)

@export var rope_curve : Curve
#@export var noise_rope : 
func manage_rope(delta):
	#tendon_puller(delta)
	
	for i in line.curve.point_count:
		var ratio = float(i)/float(line.curve.point_count)
		var line_position = lerp(grapple_start.global_position, grapple_end.global_position, ratio)
		var offset_y = sin(ratio * .5 * (grapple_end.global_position - grapple_start.global_position).length()) * rope_amplitude * rope_curve.sample(ratio)
		
		line.curve.set_point_position(i, line.to_local(line_position) + (Vector3(0, offset_y, 0) * transform.basis))
		

@export var rest_length = 1 #squeze this small to titen
@export var squeeze_length = .2
@export var tension_physics = 3
const damping_tendon = .96
func tendon_puller(delta):
	return #and retire
	if !tendons: return
	rest_length = abs(global_position - grapple_end.global_position).length() * .01
	print(rest_length)
	for i : int in line.curve.point_count:
		if i != 0 and i != line.curve.point_count - 1:
			var distance = line.curve.get_point_position(i) - line.curve.get_point_position(i - 1)
			if distance.length() > rest_length or distance.length() < squeeze_length:
				tendons[i - 1] += distance * delta * tension_physics
				#var dist_mult = (distance - (Vector3(rest_length, rest_length,rest_length) * distance.normalized())) #somehow gives more weight to the end
				tendons[i] -= distance * delta * tension_physics
			
			tendons[i] *= damping_tendon
		if i == 0 or i == line.curve.point_count - 1:
			tendons[i] = Vector3.ZERO
			
			if i == 0: 
				line.curve.set_point_position(i, line.to_local(grapple_start.global_position))
			if i == line.curve.point_count - 1 :
				line.curve.set_point_position(i,  line.to_local(grapple_end.global_position))
		#if i.global_position != tendons[tendons.find(i) - 1].global_position: i.look_at(tendons[tendons.find(i) - 1].global_position)
		line.curve.set_point_position(i, tendons[i] + line.curve.get_point_position(i))
		
