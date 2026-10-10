extends Node3D
## Minimal scene used to prove the verification harness end to end:
## rendering works, scripted input reaches the game, and motion is visible
## across captured frames. Deleted once a real player scene exists.

const SPEED := 6.0
const JUMP_VELOCITY := 9.0

@onready var _cube: Node3D = $Cube

var _velocity_y := 0.0
var _grounded := true


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	_cube.position.x += dir * SPEED * delta
	_cube.rotate_y(dir * 4.0 * delta)

	if Input.is_action_just_pressed("jump") and _grounded:
		_velocity_y = JUMP_VELOCITY
		_grounded = false

	if not _grounded:
		_velocity_y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		_cube.position.y += _velocity_y * delta
		if _cube.position.y <= 0.5:
			_cube.position.y = 0.5
			_velocity_y = 0.0
			_grounded = true
