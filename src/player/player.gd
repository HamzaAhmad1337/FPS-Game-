extends CharacterBody3D
class_name Player
## 2.5D character-action player.
##
## Movement is free on X (screen axis) and clamped to a shallow band on Z
## (depth). Y is jump height. All logic runs on the fixed 60Hz physics tick;
## nothing gameplay-relevant may live in _process.

signal state_changed(from: StringName, to: StringName)

# --- Locomotion ---
const WALK_SPEED := 3.4
const RUN_SPEED := 7.6
const GROUND_ACCEL := 68.0
const GROUND_DECEL := 85.0
const AIR_ACCEL := 30.0
const AIR_DECEL := 9.0
const DEPTH_SPEED_SCALE := 0.72   # depth movement is slower, as in 2.5D brawlers

# --- Jump ---
const JUMP_HEIGHT := 2.3
const FALL_GRAVITY_MUL := 1.38    # heavier on the way down; floaty jumps feel dead
const LOW_JUMP_GRAVITY_MUL := 2.1 # released early = shorter hop
const COYOTE_FRAMES := 6

# --- Dodge ---
const DODGE_SPEED := 13.5
const DODGE_FRAMES := 24
const DODGE_IFRAME_START := 3
const DODGE_IFRAME_END := 16

# --- Arena ---
const DEPTH_LIMIT := 3.6

const BUFFERED_ACTIONS: Array[StringName] = [&"jump", &"dodge", &"attack", &"heavy", &"gun"]

@onready var rig: BlockoutRig = $Rig
@onready var state_machine: StateMachine = $StateMachine

var input_buffer := InputBuffer.new()
var frame := 0

var facing := 1.0                 # +1 faces +X, -1 faces -X
var frames_since_grounded := 0
var invulnerable_until_frame := -1
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)

var _pose := BlockoutRig.PoseContext.new()


func _ready() -> void:
	state_machine.setup(self)
	state_machine.state_changed.connect(func(f, t): state_changed.emit(f, t))


func _physics_process(delta: float) -> void:
	frame += 1
	input_buffer.poll(BUFFERED_ACTIONS, frame)

	if is_on_floor():
		frames_since_grounded = 0
	else:
		frames_since_grounded += 1

	state_machine.physics_update(delta)
	move_and_slide()
	_clamp_depth()
	_update_facing(delta)
	_update_rig(delta)


# --------------------------------------------------------------- input access

## Raw stick/key direction. x = screen axis, y = depth axis.
func move_input() -> Vector2:
	return Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_back", &"move_fore")
	).limit_length(1.0)


func desired_speed() -> float:
	# Analog sticks get a walk; keyboard always reads 1.0 and so always runs.
	return lerpf(WALK_SPEED, RUN_SPEED, clampf(move_input().length(), 0.0, 1.0))


# ------------------------------------------------------------------- movement

func apply_planar_movement(delta: float, speed: float, accel: float, decel: float) -> void:
	var input := move_input()
	var target := Vector3(input.x * speed, 0.0, -input.y * speed * DEPTH_SPEED_SCALE)
	var rate := accel if target.length_squared() > 0.01 else decel
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)


func apply_gravity(delta: float) -> void:
	var mul := 1.0
	if velocity.y < 0.0:
		mul = FALL_GRAVITY_MUL
	elif not Input.is_action_pressed(&"jump"):
		mul = LOW_JUMP_GRAVITY_MUL
	velocity.y -= gravity * mul * delta


func jump_velocity() -> float:
	return sqrt(2.0 * gravity * JUMP_HEIGHT)


func can_coyote_jump() -> bool:
	return frames_since_grounded <= COYOTE_FRAMES


func planar_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func speed_ratio() -> float:
	return clampf(planar_speed() / RUN_SPEED, 0.0, 1.0)


## Depth is a hard wall rather than a soft push so the player can never be
## shoved out of the fighting plane by knockback.
func _clamp_depth() -> void:
	if absf(position.z) > DEPTH_LIMIT:
		position.z = signf(position.z) * DEPTH_LIMIT
		velocity.z = 0.0


# -------------------------------------------------------------------- facing

func _update_facing(delta: float) -> void:
	var x := move_input().x
	# Facing only flips on deliberate input; drifting velocity must not spin
	# the character mid-combo.
	if absf(x) > 0.25 and state_machine.current_name != &"Dodge":
		facing = signf(x)
	var target_yaw := -PI * 0.5 if facing > 0.0 else PI * 0.5
	rig.rotation.y = lerp_angle(rig.rotation.y, target_yaw, 1.0 - exp(-18.0 * delta))


# ---------------------------------------------------------------- i-frames

func set_invulnerable_for(frames: int) -> void:
	invulnerable_until_frame = frame + frames


func is_invulnerable() -> bool:
	return frame < invulnerable_until_frame


# -------------------------------------------------------------------- visuals

func _update_rig(delta: float) -> void:
	_pose.state = state_machine.current_name
	_pose.speed_ratio = speed_ratio()
	_pose.planar_speed = planar_speed()
	_pose.vertical_velocity = velocity.y
	_pose.grounded = is_on_floor()
	_pose.state_progress = state_machine.current.state_progress() if state_machine.current else 0.0
	# Roll tumbles the way the character is travelling, not always forwards.
	_pose.roll_sign = signf(velocity.x * facing) if absf(velocity.x) > 0.5 else 1.0
	rig.apply(_pose, delta)
	rig.set_flash(1.0 if is_invulnerable() else 0.0)
