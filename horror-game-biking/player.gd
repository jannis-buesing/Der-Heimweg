@tool
extends CharacterBody3D

@export var acceleration := 3.375        # 75% von 4.5
@export var max_speed := 5
@export var coasting_friction := 2.0
@export var active_braking := 9.0
@export var turn_speed := 1
@export var light_on_at_start := true
@export var controls_enabled: bool = true

# Kamera-Umsehen
@export var mouse_sensitivity := 0.01
@export var cam_friction := 0.88
@export var cam_return_speed := 10
@export var cam_return_delay := 1
@export var max_yaw_deg := 80.0
@export var max_pitch_up_deg := 25.0
@export var max_pitch_down_deg := 18.0

@export_group("Editor Preview")
@export var editor_preview_hands: bool = false:
	set(val):
		editor_preview_hands = val
		if Engine.is_editor_hint():
			_update_editor_preview()

@export_group("Linke Hand")
@export var left_hand_roll: float = 90.0:
	set(val):
		left_hand_roll = val
		if Engine.is_editor_hint() and editor_preview_hands:
			_update_editor_preview()
@export var left_hand_extra_rotation: Vector3 = Vector3.ZERO:
	set(val):
		left_hand_extra_rotation = val
		if Engine.is_editor_hint() and editor_preview_hands:
			_update_editor_preview()
@export var left_hand_offset: Vector3 = Vector3(0.0, 0.03, 0.0):
	set(val):
		left_hand_offset = val
		if Engine.is_editor_hint() and editor_preview_hands:
			_update_editor_preview()

@export_group("Rechte Hand")
@export var right_hand_roll: float = 90.0:
	set(val):
		right_hand_roll = val
		if Engine.is_editor_hint() and editor_preview_hands:
			_update_editor_preview()
@export var right_hand_extra_rotation: Vector3 = Vector3.ZERO:
	set(val):
		right_hand_extra_rotation = val
		if Engine.is_editor_hint() and editor_preview_hands:
			_update_editor_preview()
@export var right_hand_offset: Vector3 = Vector3(0.0, 0.03, 0.0):
	set(val):
		right_hand_offset = val
		if Engine.is_editor_hint() and editor_preview_hands:
			_update_editor_preview()

# Kamera-Zustand: aktuelle Winkel und deren Geschwindigkeit
var _yaw: float = 0.0
var _pitch: float = 0.0
var _vel_yaw: float = 0.0
var _vel_pitch: float = 0.0
var _time_since_mouse: float = 999.0

# Maus-Akkumulation zwischen Frames
var _mouse_delta_x: float = 0.0
var _mouse_delta_y: float = 0.0

# Visuelle Referenzen
@onready var camera: Camera3D = get_node_or_null("Camera3D")
@onready var bike: Node3D = get_node_or_null("Bike")
@onready var steering_assembly: Node3D = get_node_or_null("Bike/SteeringAssembly")
@onready var headlight: SpotLight3D = get_node_or_null("Bike/SteeringAssembly/Lamp/Headlight")
@onready var lamp_lens: MeshInstance3D = get_node_or_null("Bike/SteeringAssembly/Lamp/LampLens")
@onready var player_model: Node3D = get_node_or_null("PlayerModel")

var is_light_on := true

# Skelett und Arm-Bones
var _skeleton: Skeleton3D = null
var _bone_left_arm: int = -1
var _bone_left_forearm: int = -1
var _bone_left_hand: int = -1

var _bone_right_arm: int = -1
var _bone_right_forearm: int = -1
var _bone_right_hand: int = -1

var _bones_initialized := false
var _debug_printed := false


func set_bike_visible(state: bool) -> void:
	if bike:
		bike.visible = state


func set_player_model_visible(state: bool) -> void:
	if player_model:
		player_model.visible = state


func _ready() -> void:
	if Engine.is_editor_hint():
		_init_references()
		if editor_preview_hands:
			_update_editor_preview()
		return

	add_to_group("player")
	is_light_on = light_on_at_start
	_apply_light_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_player_model()
	if player_model:
		player_model.visible = false


func _init_references() -> void:
	if not bike:
		bike = get_node_or_null("Bike")
	if not steering_assembly:
		steering_assembly = get_node_or_null("Bike/SteeringAssembly")
	if not player_model:
		player_model = get_node_or_null("PlayerModel")
	if not camera:
		camera = get_node_or_null("Camera3D")
	if player_model and not _skeleton:
		_find_skeleton(player_model)


func _setup_player_model() -> void:
	_init_references()
	if not player_model:
		return

	player_model.position = Vector3(0.0, -0.05, 0.22)
	player_model.rotation_degrees = Vector3(0, 180, 0)

	_find_skeleton(player_model)


func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D:
		_skeleton = node as Skeleton3D
		_setup_arm_bones()
		return
	for child in node.get_children():
		_find_skeleton(child)


func _setup_arm_bones() -> void:
	if not _skeleton:
		return

	_bone_left_arm = _find_bone(_skeleton, ["mixamorig_LeftArm", "LeftArm", "upperarm_l"])
	_bone_left_forearm = _find_bone(_skeleton, ["mixamorig_LeftForeArm", "LeftForeArm", "lowerarm_l"])
	_bone_left_hand = _find_bone(_skeleton, ["mixamorig_LeftHand", "LeftHand", "hand_l"])

	_bone_right_arm = _find_bone(_skeleton, ["mixamorig_RightArm", "RightArm", "upperarm_r"])
	_bone_right_forearm = _find_bone(_skeleton, ["mixamorig_RightForeArm", "RightForeArm", "lowerarm_r"])
	_bone_right_hand = _find_bone(_skeleton, ["mixamorig_RightHand", "RightHand", "hand_r"])

	_bones_initialized = true


func _find_bone(skel: Skeleton3D, candidates: Array) -> int:
	for cand in candidates:
		var idx := skel.find_bone(cand)
		if idx != -1:
			return idx
	return -1


func _update_editor_preview() -> void:
	_init_references()
	if not player_model or not _skeleton:
		return

	if editor_preview_hands:
		player_model.visible = true
		player_model.position = Vector3(0.0, -0.05, 0.22)
		player_model.rotation_degrees = Vector3(0, 180, 0)
		_apply_hand_ik_overrides()
	else:
		_skeleton.clear_bones_global_pose_override()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if not controls_enabled:
		_mouse_delta_x = 0.0
		_mouse_delta_y = 0.0
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta_x += event.relative.x
		_mouse_delta_y += event.relative.y
		_time_since_mouse = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not controls_enabled:
		return
	if event.is_action_pressed("toggle_light"):
		toggle_light()


func set_camera_angles(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	_vel_yaw = 0.0
	_vel_pitch = 0.0
	if camera:
		camera.rotation.y = _yaw
		camera.rotation.x = _pitch


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if player_model and player_model.visible:
		_update_hand_ik()

	if not controls_enabled:
		if camera:
			camera.rotation.y = _yaw
			camera.rotation.x = _pitch
		return

	_time_since_mouse += delta

	if _mouse_delta_x != 0.0 or _mouse_delta_y != 0.0:
		var impulse_scale := mouse_sensitivity / maxf(delta, 0.008)
		_vel_yaw   -= _mouse_delta_x * impulse_scale * delta
		_vel_pitch -= _mouse_delta_y * impulse_scale * delta
		_mouse_delta_x = 0.0
		_mouse_delta_y = 0.0

	if _time_since_mouse > cam_return_delay:
		var return_strength := cam_return_speed * delta
		_vel_yaw   -= _yaw   * return_strength
		_vel_pitch -= _pitch * return_strength * 0.7

	var friction_factor := pow(cam_friction, 60.0 * delta)
	_vel_yaw   *= friction_factor
	_vel_pitch *= friction_factor

	_yaw   += _vel_yaw   * delta
	_pitch += _vel_pitch * delta

	var max_yaw   := deg_to_rad(max_yaw_deg)
	var max_pu    := deg_to_rad(max_pitch_up_deg)
	var max_pd    := deg_to_rad(max_pitch_down_deg)

	if abs(_yaw) >= max_yaw:
		_yaw = clamp(_yaw, -max_yaw, max_yaw)
		_vel_yaw = 0.0
	if _pitch > max_pu:
		_pitch = max_pu
		_vel_pitch = minf(_vel_pitch, 0.0)
	if _pitch < -max_pd:
		_pitch = -max_pd
		_vel_pitch = maxf(_vel_pitch, 0.0)

	if _time_since_mouse > cam_return_delay:
		if abs(_yaw) < 0.002 and abs(_vel_yaw) < 0.005:
			_yaw = 0.0
			_vel_yaw = 0.0
		if abs(_pitch) < 0.002 and abs(_vel_pitch) < 0.005:
			_pitch = 0.0
			_vel_pitch = 0.0

	if camera:
		camera.rotation.y = _yaw
		camera.rotation.x = _pitch


func _update_hand_ik() -> void:
	if not _skeleton or not _bones_initialized or not player_model or not player_model.visible:
		return

	if not _debug_printed:
		_debug_printed = true
		print("[PlayerModel] Bones initialisiert. L-Hand: ", _bone_left_hand, " R-Hand: ", _bone_right_hand)

	if _bone_left_hand == -1 and _bone_right_hand == -1:
		return

	_apply_hand_ik_overrides()


func _apply_hand_ik_overrides() -> void:
	if not _skeleton:
		return

	var grip_pos_l := _get_grip_world_pos(true)
	var grip_pos_r := _get_grip_world_pos(false)
	var skel_inv := _skeleton.global_transform.affine_inverse()

	# 1. LINKE SEITE
	# Oberarm und Unterarm bleiben in ihrer natuerlichen Grundposition (Ellenbogen stabil am Koerper)
	if _bone_left_arm != -1:
		_skeleton.set_bone_pose_rotation(_bone_left_arm, _skeleton.get_bone_rest(_bone_left_arm).basis.get_rotation_quaternion())

	if _bone_left_forearm != -1:
		_skeleton.set_bone_pose_rotation(_bone_left_forearm, _skeleton.get_bone_rest(_bone_left_forearm).basis.get_rotation_quaternion())

	if _bone_left_hand != -1:
		var local_pos := skel_inv * grip_pos_l
		var rest_b := _skeleton.get_bone_rest(_bone_left_hand).basis.orthonormalized()
		var hand_basis := rest_b.rotated(rest_b.y.normalized(), deg_to_rad(left_hand_roll))
		if left_hand_extra_rotation != Vector3.ZERO:
			hand_basis = hand_basis.rotated(Vector3.RIGHT, deg_to_rad(left_hand_extra_rotation.x))
			hand_basis = hand_basis.rotated(Vector3.UP, deg_to_rad(left_hand_extra_rotation.y))
			hand_basis = hand_basis.rotated(Vector3.FORWARD, deg_to_rad(left_hand_extra_rotation.z))
		_skeleton.set_bone_global_pose_override(
			_bone_left_hand,
			Transform3D(hand_basis.orthonormalized(), local_pos),
			1.0,
			true
		)

	# 2. RECHTE SEITE
	# Oberarm und Unterarm bleiben in ihrer natuerlichen Grundposition (Ellenbogen stabil am Koerper)
	if _bone_right_arm != -1:
		_skeleton.set_bone_pose_rotation(_bone_right_arm, _skeleton.get_bone_rest(_bone_right_arm).basis.get_rotation_quaternion())

	if _bone_right_forearm != -1:
		_skeleton.set_bone_pose_rotation(_bone_right_forearm, _skeleton.get_bone_rest(_bone_right_forearm).basis.get_rotation_quaternion())

	if _bone_right_hand != -1:
		var local_pos := skel_inv * grip_pos_r
		var rest_b := _skeleton.get_bone_rest(_bone_right_hand).basis.orthonormalized()
		var hand_basis := rest_b.rotated(rest_b.y.normalized(), deg_to_rad(-right_hand_roll))
		if right_hand_extra_rotation != Vector3.ZERO:
			hand_basis = hand_basis.rotated(Vector3.RIGHT, deg_to_rad(right_hand_extra_rotation.x))
			hand_basis = hand_basis.rotated(Vector3.UP, deg_to_rad(-right_hand_extra_rotation.y))
			hand_basis = hand_basis.rotated(Vector3.FORWARD, deg_to_rad(-right_hand_extra_rotation.z))
		_skeleton.set_bone_global_pose_override(
			_bone_right_hand,
			Transform3D(hand_basis.orthonormalized(), local_pos),
			1.0,
			true
		)


func _get_grip_world_pos(left: bool) -> Vector3:
	if not steering_assembly:
		steering_assembly = get_node_or_null("Bike/SteeringAssembly")
	var offset := left_hand_offset if left else right_hand_offset
	if steering_assembly:
		var base_x := -0.27 if left else 0.27
		var lp := Vector3(base_x + offset.x, 1.1689351 + offset.y, -0.05805713 + offset.z)
		return steering_assembly.global_transform * lp
	return global_position + Vector3((-0.3 if left else 0.3) + offset.x, 1.0 + offset.y, -0.5 + offset.z)


func toggle_light() -> void:
	is_light_on = !is_light_on
	_apply_light_state()


func _apply_light_state() -> void:
	if headlight:
		headlight.visible = is_light_on
	if lamp_lens and lamp_lens.mesh and lamp_lens.mesh.material:
		var mat := lamp_lens.get_surface_override_material(0)
		if not mat:
			mat = lamp_lens.mesh.material.duplicate()
			lamp_lens.set_surface_override_material(0, mat)
		if mat is StandardMaterial3D:
			mat.emission_enabled = is_light_on


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not controls_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var forward_input := Input.get_axis("move_backward", "move_forward")
	var turn_input := Input.get_axis("turn_left", "turn_right")
	var forward_dir := -transform.basis.z

	# Bewegung
	if forward_input > 0.0:
		velocity = velocity.move_toward(forward_dir * max_speed, acceleration * delta)
	elif forward_input < 0.0:
		var current_fwd := velocity.dot(forward_dir)
		if current_fwd > 0.05:
			velocity = velocity.move_toward(Vector3.ZERO, active_braking * delta)
		else:
			velocity = velocity.move_toward(forward_dir * -1.5, acceleration * 0.6 * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, coasting_friction * delta)

	# Lenken
	var speed_factor: float = clamp(
		velocity.length() / max_speed,
		0.0,
		1.0
	)

	var is_reversing: bool = velocity.dot(forward_dir) < -0.05
	var steer_flip: float = -1.0 if is_reversing else 1.0

	if velocity.length() > 0.1:
		rotate_y(
			-turn_input
			* turn_speed
			* speed_factor
			* delta
			* steer_flip
		)

	if steering_assembly:
		var target_steer: float = -turn_input * deg_to_rad(14.0)

		steering_assembly.rotation.y = lerp_angle(
			steering_assembly.rotation.y,
			target_steer,
			10.0 * delta
		)

	if bike:
		var target_lean: float = -turn_input * deg_to_rad(3.5) * speed_factor

		bike.rotation.z = lerp_angle(
			bike.rotation.z,
			target_lean,
			8.0 * delta
		)

	move_and_slide()
