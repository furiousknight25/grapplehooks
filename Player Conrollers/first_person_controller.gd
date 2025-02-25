extends CharacterBody3D
@onready var camera_3d: Camera3D = $Camera3D
@onready var look_ray_cast: RayCast3D = $Camera3D/LookRayCast
@onready var grapple_start: MeshInstance3D = $GrappleHook1/GrappleStart
@onready var grapple_end: MeshInstance3D = $GrappleHook1/GrappleEnd
@onready var line: Path3D = $GrappleHook1/Line

@onready var grapple_end_2: RigidBody3D = $GrappleHook2/GrappleEnd
@onready var line_2: Path3D = $GrappleHook2/Line

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
	for i in $GrappleHook2/Line.curve.point_count:
		tendons[i] = Vector3.ZERO
		
	grapple_end.hide()
	line.hide()
	grapple_end_2.hide()
	line_2.hide()
	release_2()
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
			if is_on_wall(): velocity.lerp(Vector3.ZERO, delta * 5)
			sv_airaccelerate(movement_dir, delta)
		STATE.GRAPPLE:
			sv_airaccelerate(movement_dir, delta)
			#velocity += Vector3(movement_dir.x, 0, movement_dir.z) * .4
			manage_rope(delta)
	if cur_state != STATE.GRAPPLE:
		if is_on_floor(): cur_state = STATE.GROUNDED
		else: cur_state = STATE.AIR
	
	hook_one_manager(delta)
	velocity.y -= 9.8 * delta
	move_and_slide()


func sv_airaccelerate(movement_dir, delta):
	var air_strength
	if cur_state == STATE.GRAPPLE: air_strength = 2
	else: air_strength = 3
	
	movement_dir = movement_dir * air_strength
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
var pause_hook = true

var length_timer = 0.0
var max_length = 0.0

var hooked2 = false
var retracting_2 = false
var centripetal_range
var centri_force : Vector3

@export var rest_length = 1 #squeze this small to titen
@export var squeeze_length = .2
@export var tension_physics = 5

func hook_one_manager(delta):
	tendon_puller(delta)
#region click manager
	if Input.is_action_just_pressed("left_click") and retracted == true:
		connect_g()
	
	if Input.is_action_just_released("left_click") and retracted == false:
		release()
		
	if Input.is_action_just_pressed('right_click') and retracted:
		connect_g_2()
	
	if Input.is_action_just_released("right_click") and retracted == false:
		release_2()
#endregion
	#Engine.time_scale = .1
#region grapple state
#region grapple 1
	if Input.is_action_just_pressed('pause'): pause_hook = !pause_hook 
	if hooked and pause_hook:
		length_timer -= delta * 6
		if length_timer <= .2 or (hook_point - global_position).length() < 1:
			release()
		#v1 grapple
		velocity += (hook_point - global_position).normalized() * 40 * delta
		#velocity +=  delta * Vector3(0,4.8,0)
	else:
		if look_ray_cast.is_colliding():
			look_ray_cast.get_child(0).global_position = look_ray_cast.get_collision_point()
	
	if retracted:
		grapple_end.global_position = grapple_start.global_position
		grapple_end_2.global_position = $GrappleHook2/GrappleStart.global_position
		grapple_end.hide()
		line.hide()
		grapple_end_2.hide()
		line_2.hide()
#endregion
	
	if hooked2:
		if (grapple_end_2.global_position - global_position).length() > centripetal_range: #dot product magic
			var angle_dif = grapple_end_2.global_position-global_position
			centri_force = ((angle_dif).dot(velocity)/angle_dif.length_squared())*angle_dif
			velocity += -centri_force
	elif retracting_2 == false:
		if $GrappleHook2/GrappleEnd/Area3D.has_overlapping_bodies():
			rest_length = .1
			hooked2 = true
			grapple_end_2.freeze = true
			centripetal_range = (grapple_end_2.global_position - global_position).length()
			#print(grapple_end_2.freeze)
		
#endregion
	
	amplitude_spring(delta)

func connect_g():
	rope_amplitude = .5
	#make the if statement based on direction 
	grapple_end.show()
	line.show()
	var match_face_dir = max(0, velocity.normalized().dot((global_position-hook_point).normalized()))
	velocity -= velocity * Vector3(match_face_dir,match_face_dir,match_face_dir) * .5
	cur_state = STATE.GRAPPLE
	velocity += Vector3(0,2,0)
	hook_point = look_ray_cast.get_collision_point()
	var tween = get_tree().create_tween()
	tween.tween_property(grapple_end, 'global_position', hook_point, .1)
	length_timer = (global_position-hook_point).length()
	max_length = length_timer
	retracted = false
	await tween.finished
	hooked = true

func release():
	cur_state = STATE.AIR
	hook_point = Vector3.ZERO
	hook_point = look_ray_cast.get_collision_point()
	var tween = get_tree().create_tween()
	tween.tween_property(grapple_end, 'global_position', grapple_start.global_position, .1)
	hooked = false
	await tween.finished
	retracted = true

func connect_g_2():
	grapple_end_2.show()
	line_2.show()
	retracted = false
	grapple_end_2.freeze = false
	grapple_end_2.apply_central_impulse(-$Camera3D.global_basis.z * 50)
	rest_length = 1
	
	for i in line_2.curve.point_count:
		randomize()
		#tendons[i] += Vector3(randf_range(-.5,.5),randf_range(-.5,.5),0) * basis * rope_curve.sample(i/line_2.curve.point_count)
	
func release_2():
	if hooked2: velocity.y += 4
	grapple_end_2.freeze = true
	hooked2 = false
	retracting_2 = true
	var tween = get_tree().create_tween()
	tween.tween_property(grapple_end_2, "global_position", $GrappleHook2/GrappleStart.global_position, .2)
	await tween.finished
	retracting_2 = false
	retracted = true
	
	
	

var vel := .01
var goal := 0.0
var tension := 500.0
var damping := 10.0

func amplitude_spring(delta): 
	var displacement = rope_amplitude - goal
	
	var force = -tension * displacement - damping * vel
	vel += force * delta
	rope_amplitude += vel * delta
	

@export var rope_curve : Curve
@export var noise_rope : NoiseTexture3D
var noise_progression = randf()
func manage_rope(delta):
	
	
	for i in line.curve.point_count:
		
		var ratio = float(i)/float(line.curve.point_count)
		var line_position = lerp(grapple_start.global_position, grapple_end.global_position, ratio)
		var offset_y = sin(ratio * .5 * (grapple_end.global_position - grapple_start.global_position).length()) * rope_amplitude * rope_curve.sample(ratio)
		var offset_noise = noise_rope.noise.get_noise_2d(noise_progression,noise_progression)
		noise_progression += delta * 25
		
		line.curve.set_point_position(i, line.to_local(line_position) + (Vector3(0, offset_y, 0) * transform.basis))
		if i != 0 and i != line.curve.point_count - 1:
			line.curve.set_point_position(i, line.to_local(line_position) + (Vector3(offset_noise * .1, offset_y, 0) * transform.basis))



const damping_tendon = .96
func tendon_puller(delta):
	
	
	if !tendons: return
	rest_length = abs(global_position - grapple_end_2.global_position).length() * .01
	
	for i : int in line_2.curve.point_count:
		if i != 0 and i != line_2.curve.point_count - 1:
			var distance = line_2.curve.get_point_position(i) - line_2.curve.get_point_position(i + 1)
			if distance.length() > rest_length or distance.length() < squeeze_length:
				for e in 1:
					tendons[i + 1] += distance * delta * tension_physics
					#var dist_mult = (distance - (Vector3(rest_length, rest_length,rest_length) * distance.normalized())) #somehow gives more weight to the end
					tendons[i] -= distance * delta * tension_physics
			
			tendons[i] *= damping_tendon
		if i == 0 or i == line_2.curve.point_count - 1:
			tendons[i] = Vector3.ZERO
			
			if i == 0: 
				line_2.curve.set_point_position(i, line_2.to_local($GrappleHook2/GrappleStart.global_position))
			if i == line_2.curve.point_count - 1:
				line_2.curve.set_point_position(i,  line_2.to_local(grapple_end_2.global_position))
		#if i.global_position != tendons[tendons.find(i) - 1].global_position: i.look_at(tendons[tendons.find(i) - 1].global_position)
		line_2.curve.set_point_position(i, tendons[i] + line_2.curve.get_point_position(i))
		
