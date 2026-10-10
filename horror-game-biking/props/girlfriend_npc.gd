@tool
extends Node3D

# Skript fuer Girlfriend (Marieke):
# - @tool fuer Live-Vorschau im Godot-Editor
# - preview_wave_button zum Testen des Winkens
# - Linker & Rechter Arm separat konfigurierbar
# - Beim Winken hebt der Oberarm den Arm stabil an (wave_upper_arm_angle).
# - NUR der Unterarm schwingt hin und her (wave_forearm_amplitude).
# - Die rechte Hand hat ihre eigene Drehung (wave_hand_rotation_deg).

@export_group("Editor Preview")
@export var preview_wave_button: bool = false:
	set(val):
		if val:
			preview_wave_button = false
			wave_goodbye()

@export_group("Linker Arm (Ruhepose)")
@export var left_arm_drop_angle: float = 75.0:
	set(val):
		left_arm_drop_angle = val
		apply_pose()
@export var left_arm_forward_angle: float = 0.0:
	set(val):
		left_arm_forward_angle = val
		apply_pose()
@export var left_forearm_bend: float = 5.0:
	set(val):
		left_forearm_bend = val
		apply_pose()

@export_group("Rechter Arm (Ruhepose)")
@export var right_arm_drop_angle: float = 75.0:
	set(val):
		right_arm_drop_angle = val
		apply_pose()
@export var right_arm_forward_angle: float = 0.0:
	set(val):
		right_arm_forward_angle = val
		apply_pose()
@export var right_forearm_bend: float = 5.0:
	set(val):
		right_forearm_bend = val
		apply_pose()

@export_group("Winken")
@export var wave_upper_arm_angle: float = 25.0:     # Winkel des Oberarms beim Winken (bleibt waehrend des Winkens stabil)
	set(val):
		wave_upper_arm_angle = val
@export var wave_forearm_base_angle: float = 35.0:  # Grundhaltung des Unterarms beim Winken
	set(val):
		wave_forearm_base_angle = val
@export var wave_forearm_amplitude: float = 22.0:   # Wie weit NUR der Unterarm hin und her winkt
	set(val):
		wave_forearm_amplitude = val
@export var wave_hand_rotation_deg: float = 0.0:    # Drehung der Hand beim Winken (Winkhaltung / Handstellung)
	set(val):
		wave_hand_rotation_deg = val

var _skeleton: Skeleton3D = null
var _bone_right_arm: int = -1
var _bone_right_forearm: int = -1
var _bone_right_hand: int = -1
var _bone_left_arm: int = -1
var _bone_left_forearm: int = -1

var is_waving := false


func _ready() -> void:
	_init_skeleton()
	apply_pose()


func _process(_delta: float) -> void:
	if not is_waving and _skeleton and Engine.is_editor_hint():
		apply_pose()


func _init_skeleton() -> void:
	if not _skeleton:
		_find_skeleton(self)


func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D:
		_skeleton = node as Skeleton3D
		_setup_bones()
		return
	for child in node.get_children():
		_find_skeleton(child)


func _setup_bones() -> void:
	if not _skeleton:
		return

	_bone_right_arm = _find_bone(["mixamorig_RightArm", "RightArm", "upperarm_r"])
	_bone_right_forearm = _find_bone(["mixamorig_RightForeArm", "RightForeArm", "lowerarm_r"])
	_bone_right_hand = _find_bone(["mixamorig_RightHand", "RightHand", "hand_r"])
	_bone_left_arm = _find_bone(["mixamorig_LeftArm", "LeftArm", "upperarm_l"])
	_bone_left_forearm = _find_bone(["mixamorig_LeftForeArm", "LeftForeArm", "lowerarm_l"])


func _find_bone(candidates: Array) -> int:
	for cand in candidates:
		var idx := _skeleton.find_bone(cand)
		if idx != -1:
			return idx
	return -1


func apply_pose() -> void:
	_init_skeleton()
	if not _skeleton:
		return

	# Linker Arm
	if _bone_left_arm != -1:
		var rest_l := _skeleton.get_bone_rest(_bone_left_arm)
		var q_l := rest_l.basis.get_rotation_quaternion()
		q_l = q_l * Quaternion(Vector3(0, 0, 1), deg_to_rad(-left_arm_drop_angle))
		if left_arm_forward_angle != 0.0:
			q_l = q_l * Quaternion(Vector3(1, 0, 0), deg_to_rad(left_arm_forward_angle))
		_skeleton.set_bone_pose_rotation(_bone_left_arm, q_l)

	if _bone_left_forearm != -1:
		var rest_lf := _skeleton.get_bone_rest(_bone_left_forearm)
		var q_lf := rest_lf.basis.get_rotation_quaternion() * Quaternion(Vector3(0, 0, 1), deg_to_rad(-left_forearm_bend))
		_skeleton.set_bone_pose_rotation(_bone_left_forearm, q_lf)

	# Rechter Arm
	if not is_waving:
		_apply_right_arm_pose()


func _apply_right_arm_pose() -> void:
	if not _skeleton:
		return
	if _bone_right_arm != -1:
		var rest_r := _skeleton.get_bone_rest(_bone_right_arm)
		var q_r := rest_r.basis.get_rotation_quaternion()
		q_r = q_r * Quaternion(Vector3(0, 0, 1), deg_to_rad(right_arm_drop_angle))
		if right_arm_forward_angle != 0.0:
			q_r = q_r * Quaternion(Vector3(1, 0, 0), deg_to_rad(right_arm_forward_angle))
		_skeleton.set_bone_pose_rotation(_bone_right_arm, q_r)

	if _bone_right_forearm != -1:
		var rest_rf := _skeleton.get_bone_rest(_bone_right_forearm)
		var q_rf := rest_rf.basis.get_rotation_quaternion() * Quaternion(Vector3(0, 0, 1), deg_to_rad(right_forearm_bend))
		_skeleton.set_bone_pose_rotation(_bone_right_forearm, q_rf)

	if _bone_right_hand != -1:
		var rest_rh := _skeleton.get_bone_rest(_bone_right_hand)
		_skeleton.set_bone_pose_rotation(_bone_right_hand, rest_rh.basis.get_rotation_quaternion())


func wave_goodbye() -> void:
	_init_skeleton()
	if is_waving or not _skeleton or _bone_right_arm == -1:
		return

	is_waving = true
	var rest_r := _skeleton.get_bone_rest(_bone_right_arm).basis.get_rotation_quaternion()
	var rest_forearm := _skeleton.get_bone_rest(_bone_right_forearm).basis.get_rotation_quaternion() if _bone_right_forearm != -1 else Quaternion.IDENTITY
	var rest_hand := _skeleton.get_bone_rest(_bone_right_hand).basis.get_rotation_quaternion() if _bone_right_hand != -1 else Quaternion.IDENTITY

	# 1. Oberarm hebt sich nach oben und bleibt dort ruhig stehen
	var wave_up_arm := rest_r * Quaternion(Vector3(0, 0, 1), deg_to_rad(wave_upper_arm_angle)) * Quaternion(Vector3(1, 0, 0), deg_to_rad(-35.0))

	# 2. Handstellung (konfigurierbare Drehung beim Winken)
	var wave_hand_pose := rest_hand * Quaternion(Vector3(0, 1, 0), deg_to_rad(wave_hand_rotation_deg))

	# 3. Unterarm Basishaltung + Amplitude
	var forearm_mid := rest_forearm * Quaternion(Vector3(0, 0, 1), deg_to_rad(wave_forearm_base_angle))
	var forearm_left := forearm_mid * Quaternion(Vector3(0, 0, 1), deg_to_rad(-wave_forearm_amplitude))
	var forearm_right := forearm_mid * Quaternion(Vector3(0, 0, 1), deg_to_rad(wave_forearm_amplitude))

	var tween := create_tween()

	# Arm anheben: Oberarm geht hoch, Unterarm & Hand begeben sich in Position
	var start_r := _skeleton.get_bone_pose_rotation(_bone_right_arm)
	tween.tween_method(
		func(t: float):
			_skeleton.set_bone_pose_rotation(_bone_right_arm, start_r.slerp(wave_up_arm, t))
			if _bone_right_forearm != -1:
				_skeleton.set_bone_pose_rotation(_bone_right_forearm, rest_forearm.slerp(forearm_mid, t))
			if _bone_right_hand != -1:
				_skeleton.set_bone_pose_rotation(_bone_right_hand, rest_hand.slerp(wave_hand_pose, t)),
		0.0, 1.0, 0.4
	)

	# Hin- und herwinken (3x): NUR DER UNTERARM bewegt sich, der Oberarm bleibt stabil!
	for i in range(3):
		if _bone_right_forearm != -1:
			tween.tween_method(
				func(t: float):
					_skeleton.set_bone_pose_rotation(_bone_right_forearm, forearm_left.slerp(forearm_right, t)),
				0.0, 1.0, 0.25
			)
			tween.tween_method(
				func(t: float):
					_skeleton.set_bone_pose_rotation(_bone_right_forearm, forearm_right.slerp(forearm_left, t)),
				0.0, 1.0, 0.25
			)

	# Arm wieder weich zurueck in die Ruheposition senken
	var down_r := rest_r * Quaternion(Vector3(0, 0, 1), deg_to_rad(right_arm_drop_angle))
	tween.tween_method(
		func(t: float):
			var cur_arm := _skeleton.get_bone_pose_rotation(_bone_right_arm)
			_skeleton.set_bone_pose_rotation(_bone_right_arm, cur_arm.slerp(down_r, t))
			if _bone_right_forearm != -1:
				var cur_f := _skeleton.get_bone_pose_rotation(_bone_right_forearm)
				_skeleton.set_bone_pose_rotation(_bone_right_forearm, cur_f.slerp(rest_forearm, t))
			if _bone_right_hand != -1:
				var cur_h := _skeleton.get_bone_pose_rotation(_bone_right_hand)
				_skeleton.set_bone_pose_rotation(_bone_right_hand, cur_h.slerp(rest_hand, t)),
		0.0, 1.0, 0.45
	)

	await tween.finished
	_apply_right_arm_pose()
	is_waving = false
