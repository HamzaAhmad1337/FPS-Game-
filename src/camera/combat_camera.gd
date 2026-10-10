extends Camera3D
class_name CombatCamera
## Side-on 2.5D combat camera.
##
## Damping is deliberately asymmetric. The screen axis catches up fast because
## the player reads their own position from it; height and depth lag so that
## jumps and depth steps do not swing the whole frame around.

@export var target_path: NodePath
@export var distance := 7.2
## Small off-axis angle. A dead-on side view flattens the character into a
## silhouette and hides arm swing entirely; ~15 degrees restores readable
## depth without losing the 2.5D plane.
@export var yaw_degrees := 15.0
@export var height := 1.95
@export var look_height := 1.05
@export var height_follow := 0.38      # fraction of player height the camera tracks
@export var depth_follow := 0.30

@export var follow_rate_x := 11.0
@export var follow_rate_y := 5.5
@export var follow_rate_z := 4.5

var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("CombatCamera has no target")
		return
	global_position = _desired_position()
	_aim()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var want := _desired_position()
	global_position = Vector3(
		_damp(global_position.x, want.x, follow_rate_x, delta),
		_damp(global_position.y, want.y, follow_rate_y, delta),
		_damp(global_position.z, want.z, follow_rate_z, delta)
	)
	_aim()


func _desired_position() -> Vector3:
	var t := _target.global_position
	var yaw := deg_to_rad(yaw_degrees)
	return Vector3(
		t.x + sin(yaw) * distance,
		height + t.y * height_follow,
		cos(yaw) * distance + t.z * depth_follow
	)


func _aim() -> void:
	var t := _target.global_position
	look_at(Vector3(t.x, look_height + t.y * height_follow, t.z * depth_follow), Vector3.UP)


## Framerate-independent exponential damping.
func _damp(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))
