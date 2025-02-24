extends Node3D
@onready var line: Path3D = $Path3D

var tendons = {}
func _ready() -> void:
	for i in line.curve.point_count:
		tendons[i] = Vector3.ZERO

@export var rest_length = .5
@export var squeeze_length = .2
@export var tension_physics = 2
var damping_tendon = .96
func _process(delta: float) -> void:
	if !tendons: return
	
	for i : int in line.curve.point_count:
		if i != 0 or i == line.curve.point_count:
			var distance = line.curve.get_point_position(i) - line.curve.get_point_position(i - 1)
			if distance.length() > rest_length or distance.length() < squeeze_length:
				tendons[i - 1] += distance * delta * tension_physics
				#var dist_mult = (distance - (Vector3(rest_length, rest_length,rest_length) * distance.normalized())) #somehow gives more weight to the end
				tendons[i] -= distance * delta * tension_physics
			
			tendons[i] *= damping_tendon
		if i == 0 or i == line.curve.point_count:
			tendons[i] = Vector3.ZERO
			if i == 0: 
				line.curve.set_point_position(i, line.to_local(Vector3.ZERO))
			if i == line.curve.point_count: 
				line.curve.set_point_position(i, line.to_local($MeshInstance3D.global_position))
		#if i.global_position != tendons[tendons.find(i) - 1].global_position: i.look_at(tendons[tendons.find(i) - 1].global_position)
		line.curve.set_point_position(i, tendons[i] + line.curve.get_point_position(i))
		print(tendons.values())
