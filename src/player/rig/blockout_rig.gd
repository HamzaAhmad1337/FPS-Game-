extends Node3D
class_name BlockoutRig
## Procedurally built humanoid blockout with code-driven animation.
##
## WHY PROCEDURAL: hand-keyed animation tracks for a placeholder body are slow
## to author and impossible to tune without an editor. Driving joints from the
## gait phase means proportions and timing are constants that can be adjusted
## and re-verified in one capture pass.
##
## PATH B SWAP: this node only consumes a PoseContext and exposes nothing else.
## Replacing it with a Skeleton3D + AnimationTree fed by imported clips means
## swapping the scene and implementing `apply(ctx)`; no state or gameplay code
## changes. That is the whole reason the interface is this narrow.

# --- Proportions (metres). Total height ~1.80. ---
const FOOT_H := 0.08
const SHIN_L := 0.40
const THIGH_L := 0.40
const HIP_Y := FOOT_H + SHIN_L + THIGH_L   # 0.95
const TORSO_L := 0.58
const HEAD_R := 0.135
const SHOULDER_Y := 0.48
const SHOULDER_X := 0.22
const UPPER_ARM_L := 0.30
const LOWER_ARM_L := 0.28
const HIP_X := 0.11

# --- Gait tuning ---
const STRIDE_RATE := 0.26          # gait cycles per metre travelled (~2/s at full run)
const THIGH_SWING := 0.62          # radians at full run
const KNEE_BEND := 1.30
const KNEE_BASE_BEND := 0.12
const ARM_SWING := 0.68
const ELBOW_BEND := 0.55
const BOB_AMOUNT := 0.055
const RUN_LEAN := 0.26             # forward torso lean at full speed
## A roll must pivot about the character's centre of mass. Rotating the body
## node directly spins it around the feet, sweeping the head through a 1.8m
## arc and throwing it off screen.
const ROLL_PIVOT_Y := 0.85
const SMOOTHING := 22.0            # higher = snappier joint tracking

## Everything the rig needs to pose itself. Filled in by the player each frame.
class PoseContext:
	var state := &"Idle"
	var speed_ratio := 0.0     # 0..1 of max run speed
	var planar_speed := 0.0    # m/s, drives gait phase advance
	var vertical_velocity := 0.0
	var grounded := true
	var state_progress := 0.0  # 0..1 through a finite state (land, dodge)
	var roll_sign := 1.0       # +1 rolls towards facing, -1 away from it

var _joints: Dictionary = {}
var _materials: Array[StandardMaterial3D] = []
var _targets: Dictionary = {}
var _gait_phase := 0.0
var _idle_time := 0.0
var _body: Node3D
var _pivot: Node3D


func _ready() -> void:
	_build()


# ---------------------------------------------------------------- construction

func _mat(color: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.emission = Color(0.55, 0.85, 1.0)
	_materials.append(m)
	return m


## Creates a joint pivot plus its limb mesh. The pivot sits at the joint so
## rotating it swings the limb correctly; the mesh is offset to hang from it.
func _joint(key: StringName, parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = String(key)
	pivot.position = at
	parent.add_child(pivot)
	_joints[key] = pivot
	_targets[key] = Vector3.ZERO
	return pivot


func _limb(parent: Node3D, size: Vector3, offset: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = mat
	parent.add_child(mi)


func _build() -> void:
	# Left limbs are darker so the gait stays readable in flat lighting and in
	# verification contact sheets.
	var skin := _mat(Color(0.82, 0.70, 0.58))
	var arm := _mat(Color(0.62, 0.64, 0.70))
	var arm_l := _mat(Color(0.40, 0.42, 0.49))
	var leg := _mat(Color(0.24, 0.26, 0.34))
	var leg_l := _mat(Color(0.15, 0.16, 0.22))
	var accent := _mat(Color(0.74, 0.15, 0.13), 0.45)

	_pivot = Node3D.new()
	_pivot.name = "RollPivot"
	_pivot.position = Vector3(0, ROLL_PIVOT_Y, 0)
	add_child(_pivot)

	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0, -ROLL_PIVOT_Y, 0)
	_pivot.add_child(_body)

	var hips := _joint(&"hips", _body, Vector3(0, HIP_Y, 0))
	_limb(hips, Vector3(0.34, 0.18, 0.22), Vector3(0, -0.04, 0), leg)

	var torso := _joint(&"torso", hips, Vector3.ZERO)
	_limb(torso, Vector3(0.40, TORSO_L, 0.24), Vector3(0, TORSO_L * 0.5, 0), accent)

	var neck := _joint(&"neck", torso, Vector3(0, TORSO_L, 0))
	_limb(neck, Vector3(HEAD_R * 2.0, HEAD_R * 2.0, HEAD_R * 2.0), Vector3(0, HEAD_R + 0.04, 0), skin)

	for side in [1, -1]:
		var tag := "r" if side > 0 else "l"
		var arm_mat := arm if side > 0 else arm_l
		var leg_mat := leg if side > 0 else leg_l

		var shoulder := _joint(
			StringName("shoulder_" + tag), torso, Vector3(SHOULDER_X * side, SHOULDER_Y, 0)
		)
		_limb(shoulder, Vector3(0.13, UPPER_ARM_L, 0.13), Vector3(0, -UPPER_ARM_L * 0.5, 0), arm_mat)

		var elbow := _joint(StringName("elbow_" + tag), shoulder, Vector3(0, -UPPER_ARM_L, 0))
		_limb(elbow, Vector3(0.11, LOWER_ARM_L, 0.11), Vector3(0, -LOWER_ARM_L * 0.5, 0), skin)
		_limb(elbow, Vector3(0.13, 0.13, 0.15), Vector3(0, -LOWER_ARM_L - 0.03, 0.01), skin)

		var thigh := _joint(StringName("thigh_" + tag), hips, Vector3(HIP_X * side, -0.06, 0))
		_limb(thigh, Vector3(0.16, THIGH_L, 0.17), Vector3(0, -THIGH_L * 0.5, 0), leg_mat)

		var knee := _joint(StringName("knee_" + tag), thigh, Vector3(0, -THIGH_L, 0))
		_limb(knee, Vector3(0.14, SHIN_L, 0.15), Vector3(0, -SHIN_L * 0.5, 0), leg_mat)

		var ankle := _joint(StringName("ankle_" + tag), knee, Vector3(0, -SHIN_L, 0))
		_limb(ankle, Vector3(0.15, FOOT_H, 0.27), Vector3(0, -FOOT_H * 0.5, 0.05), leg_mat)


# ------------------------------------------------------------------ animation

func apply(ctx: PoseContext, delta: float) -> void:
	# Gait phase is driven by distance travelled, not by time, so the feet do
	# not skate when the character accelerates.
	_gait_phase = fposmod(_gait_phase + ctx.planar_speed * STRIDE_RATE * delta * TAU, TAU)
	_idle_time += delta

	var body_pos := Vector3.ZERO
	var roll := 0.0

	match ctx.state:
		&"Dodge":
			_pose_dodge(ctx)
			roll = -ctx.state_progress * TAU * ctx.roll_sign
			body_pos.y = sin(ctx.state_progress * PI) * 0.10
		&"Jump", &"Fall":
			_pose_air(ctx)
		&"Land":
			_pose_land(ctx)
			body_pos.y = -sin(ctx.state_progress * PI) * 0.16
		&"Move":
			_pose_locomotion(ctx)
			body_pos.y = absf(sin(_gait_phase)) * BOB_AMOUNT * ctx.speed_ratio
		_:
			_pose_idle(ctx)
			body_pos.y = sin(_idle_time * 1.8) * 0.012

	var rest := Vector3(0, -ROLL_PIVOT_Y, 0)
	_body.position = _body.position.lerp(rest + body_pos, _blend(delta))
	# Applied directly, not damped: the roll ends on a whole revolution, so a
	# damped value would lag behind it and then unwind backwards on exit.
	_pivot.rotation.x = roll
	_commit(delta)


func _blend(delta: float) -> float:
	return 1.0 - exp(-SMOOTHING * delta)


func _pose_joint(key: StringName, rot: Vector3) -> void:
	_targets[key] = rot


## Dodge and roll poses are instant: easing into them would blunt exactly the
## snap that makes the action feel responsive.
func _commit(delta: float) -> void:
	var t := _blend(delta)
	for key in _joints:
		var node: Node3D = _joints[key]
		node.rotation = node.rotation.lerp(_targets[key], t)


func _pose_idle(_ctx: PoseContext) -> void:
	var breathe := sin(_idle_time * 1.8)
	_pose_joint(&"hips", Vector3.ZERO)
	_pose_joint(&"torso", Vector3(-0.04 + breathe * 0.012, 0, 0))
	_pose_joint(&"neck", Vector3(breathe * 0.02, sin(_idle_time * 0.6) * 0.10, 0))
	for side in [1, -1]:
		var tag := "r" if side > 0 else "l"
		_pose_joint(StringName("shoulder_" + tag), Vector3(0.05, 0, -0.14 * side))
		_pose_joint(StringName("elbow_" + tag), Vector3(-0.22, 0, 0))
		_pose_joint(StringName("thigh_" + tag), Vector3.ZERO)
		_pose_joint(StringName("knee_" + tag), Vector3(-0.05, 0, 0))
		_pose_joint(StringName("ankle_" + tag), Vector3.ZERO)


func _pose_locomotion(ctx: PoseContext) -> void:
	var r := ctx.speed_ratio
	var swing := THIGH_SWING * r
	var arm := ARM_SWING * r

	# Positive X rotation swings a limb forward (-Z is the rig's facing).
	_pose_joint(&"hips", Vector3(0, sin(_gait_phase) * 0.10 * r, 0))
	_pose_joint(&"torso", Vector3(-RUN_LEAN * r, -sin(_gait_phase) * 0.14 * r, 0))
	_pose_joint(&"neck", Vector3(RUN_LEAN * r * 0.85, 0, 0))

	for side in [1, -1]:
		var tag := "r" if side > 0 else "l"
		var phase := _gait_phase + (0.0 if side > 0 else PI)

		_pose_joint(StringName("thigh_" + tag), Vector3(sin(phase) * swing, 0, 0))
		# Knees only bend backwards, peaking during the recovery swing.
		var bend: float = KNEE_BASE_BEND + KNEE_BEND * r * maxf(0.0, -sin(phase - 0.5))
		_pose_joint(StringName("knee_" + tag), Vector3(-bend, 0, 0))
		# Toe points down while the foot is off the ground.
		_pose_joint(StringName("ankle_" + tag), Vector3(bend * 0.45 - 0.1, 0, 0))

		# Arms counter-swing against the same-side leg.
		_pose_joint(StringName("shoulder_" + tag), Vector3(-sin(phase) * arm, 0, -0.10 * side))
		_pose_joint(StringName("elbow_" + tag), Vector3(-ELBOW_BEND - r * 0.55 - maxf(0.0, sin(phase)) * 0.35, 0, 0))


func _pose_air(ctx: PoseContext) -> void:
	# Rising: knees tucked. Falling: legs reach for the ground.
	var rising := clampf(ctx.vertical_velocity / 9.0, 0.0, 1.0)
	var falling := clampf(-ctx.vertical_velocity / 12.0, 0.0, 1.0)

	_pose_joint(&"hips", Vector3.ZERO)
	_pose_joint(&"torso", Vector3(-0.22 * rising + 0.10 * falling, 0, 0))
	_pose_joint(&"neck", Vector3(0.10, 0, 0))

	for side in [1, -1]:
		var tag := "r" if side > 0 else "l"
		var lead := 1.0 if side > 0 else 0.55
		_pose_joint(StringName("thigh_" + tag), Vector3(0.95 * rising * lead - 0.30 * falling, 0, 0))
		_pose_joint(StringName("knee_" + tag), Vector3(-1.25 * rising * lead - 0.18, 0, 0))
		_pose_joint(StringName("ankle_" + tag), Vector3(0.35 * rising + 0.20 * falling, 0, 0))
		_pose_joint(StringName("shoulder_" + tag), Vector3(-0.85 * rising - 0.45 * falling, 0, -0.30 * side))
		_pose_joint(StringName("elbow_" + tag), Vector3(-0.90 - 0.40 * falling, 0, 0))


func _pose_land(ctx: PoseContext) -> void:
	var squash := sin(ctx.state_progress * PI)
	_pose_joint(&"hips", Vector3.ZERO)
	_pose_joint(&"torso", Vector3(-0.42 * squash, 0, 0))
	_pose_joint(&"neck", Vector3(0.30 * squash, 0, 0))
	for side in [1, -1]:
		var tag := "r" if side > 0 else "l"
		_pose_joint(StringName("thigh_" + tag), Vector3(0.75 * squash, 0, 0))
		_pose_joint(StringName("knee_" + tag), Vector3(-1.30 * squash - 0.08, 0, 0))
		_pose_joint(StringName("ankle_" + tag), Vector3(0.50 * squash, 0, 0))
		_pose_joint(StringName("shoulder_" + tag), Vector3(-0.55 * squash, 0, -0.22 * side))
		_pose_joint(StringName("elbow_" + tag), Vector3(-0.70 - 0.50 * squash, 0, 0))


func _pose_dodge(ctx: PoseContext) -> void:
	# Tight ball through the roll, opening up at the end.
	var tuck := sin(clampf(ctx.state_progress, 0.0, 1.0) * PI)
	tuck = maxf(tuck, 0.25)
	_pose_joint(&"hips", Vector3.ZERO)
	_pose_joint(&"torso", Vector3(-0.85 * tuck, 0, 0))
	_pose_joint(&"neck", Vector3(0.55 * tuck, 0, 0))
	for side in [1, -1]:
		var tag := "r" if side > 0 else "l"
		_pose_joint(StringName("thigh_" + tag), Vector3(1.75 * tuck, 0, 0))
		_pose_joint(StringName("knee_" + tag), Vector3(-1.90 * tuck, 0, 0))
		_pose_joint(StringName("ankle_" + tag), Vector3(0.45 * tuck, 0, 0))
		_pose_joint(StringName("shoulder_" + tag), Vector3(-1.35 * tuck, 0, -0.35 * side))
		_pose_joint(StringName("elbow_" + tag), Vector3(-1.70 * tuck, 0, 0))


## Emissive flash used for dodge invulnerability frames. Drives a real visual
## cue rather than a debug overlay, so what the capture harness proves is what
## the player actually sees.
func set_flash(amount: float) -> void:
	var on := amount > 0.001
	for m in _materials:
		m.emission_enabled = on
		m.emission_energy_multiplier = amount * 1.1
