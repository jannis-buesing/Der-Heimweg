extends Node3D

enum SequenceState {
	START,
	DIALOG_1,
	FADE_OUT,
	BIKE_SETUP,
	FADE_IN,
	GOODBYE_WAVE,
	CAM_ROTATE,
	DIALOG_2,
	GAMEPLAY
}

@export var player_path: NodePath
@export var girlfriend_path: NodePath
@export var dialogue_ui_path: NodePath
@export var fade_overlay_path: NodePath

var player: CharacterBody3D
var girlfriend: Node3D
var dialogue_ui: CanvasLayer
var fade_overlay: CanvasLayer

var current_state: SequenceState = SequenceState.START
var current_line_idx: int = 0

var dialogue_lines: Array = [
	{"speaker": "Marieke", "text": "Danke, dass du mich nach Hause begleitet hast."},
	{"speaker": "Marieke", "text": "Die Straße wird nach dem Dorf echt dunkel... Fahr bitte vorsichtig."},
	{"speaker": "Ich", "text": "Mach ich. Danke dir, bis morgen!"},
	{"speaker": "Marieke", "text": "Pass auf dich auf! Sag Bescheid, wenn du angekommen bist."}
]

func _ready() -> void:
	if player_path:
		player = get_node_or_null(player_path)
	if girlfriend_path:
		girlfriend = get_node_or_null(girlfriend_path)
	if dialogue_ui_path:
		dialogue_ui = get_node_or_null(dialogue_ui_path)
	if fade_overlay_path:
		fade_overlay = get_node_or_null(fade_overlay_path)

	if dialogue_ui and dialogue_ui.has_signal("advance_requested"):
		dialogue_ui.advance_requested.connect(_on_dialogue_advance)

	call_deferred("_start_sequence")


func _calc_angles_to(from_pos: Vector3, target_pos: Vector3) -> Dictionary:
	var dir := (target_pos - from_pos).normalized()
	var yaw := atan2(-dir.x, -dir.z)
	var pitch := asin(clamp(dir.y, -1.0, 1.0))
	return {"yaw": yaw, "pitch": pitch}


func _start_sequence() -> void:
	if not player:
		return
	
	# 1. Spieler-Steuerung deaktivieren
	player.controls_enabled = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Fahrrad auf Fußweg ausblenden
	if player.has_method("set_bike_visible"):
		player.set_bike_visible(false)

	# 2. Fahrradlicht am Anfang auf Fußweg AUSschalten
	if "is_light_on" in player:
		player.is_light_on = false
		if player.has_method("_apply_light_state"):
			player._apply_light_state()

	# 3. Position der Freundin (Marieke) ermitteln
	var gf_pos := Vector3(5.2, 0.0, 71.8)
	if girlfriend:
		gf_pos = girlfriend.global_position

	# 4. Spieler zu Fuß vor Marieke platzieren
	player.global_position = gf_pos - Vector3(1.6, 0.0, 0.0) # 1.6m links von Marieke
	player.rotation.y = deg_to_rad(-90.0) # blickt nach +X zu Marieke

	if player.has_method("set_camera_angles"):
		player.set_camera_angles(0.0, 0.0)

	current_state = SequenceState.DIALOG_1
	current_line_idx = 0
	_show_current_line()


func _show_current_line() -> void:
	if current_line_idx < dialogue_lines.size():
		var line: Dictionary = dialogue_lines[current_line_idx]
		if dialogue_ui:
			dialogue_ui.show_line(line["speaker"], line["text"])
	else:
		_on_dialog_1_finished()


func _on_dialogue_advance() -> void:
	match current_state:
		SequenceState.DIALOG_1:
			current_line_idx += 1
			_show_current_line()
		SequenceState.DIALOG_2:
			if dialogue_ui:
				dialogue_ui.hide_dialogue()
			_finish_sequence()


func _on_dialog_1_finished() -> void:
	if dialogue_ui:
		dialogue_ui.hide_dialogue()
	
	current_state = SequenceState.FADE_OUT
	if fade_overlay:
		await fade_overlay.fade_out(1.0)
	else:
		await get_tree().create_timer(1.0).timeout

	_setup_bike_position()


func _setup_bike_position() -> void:
	current_state = SequenceState.BIKE_SETUP

	# Fahrrad auf der Strasse wieder einblenden
	if player.has_method("set_bike_visible"):
		player.set_bike_visible(true)

	# Spieler auf das Fahrrad auf der Strasse versetzen (Blickrichtung -Z)
	player.global_position = Vector3(0.0, 0.0, 70.0)
	player.rotation.y = 0.0

	# Fahrradlicht jetzt einschalten
	if "is_light_on" in player:
		player.is_light_on = true
		if player.has_method("_apply_light_state"):
			player._apply_light_state()
	
	# Exakte Kamera-Winkel dynamisch berechnen, um Marieke auf der Veranda perfekt anzuschauen
	var gf_head_pos := Vector3(5.2, 1.4, 71.8)
	if girlfriend:
		gf_head_pos = girlfriend.global_position + Vector3(0.0, 1.4, 0.0)
	
	var cam_pos := player.global_position + Vector3(0.0, 1.5, 0.0)
	var angles := _calc_angles_to(cam_pos, gf_head_pos)

	if player.has_method("set_camera_angles"):
		player.set_camera_angles(angles["yaw"], angles["pitch"])

	current_state = SequenceState.FADE_IN
	if fade_overlay:
		await fade_overlay.fade_in(1.0)
	else:
		await get_tree().create_timer(1.0).timeout

	_trigger_goodbye_wave()


func _trigger_goodbye_wave() -> void:
	current_state = SequenceState.GOODBYE_WAVE

	if girlfriend and girlfriend.has_method("wave_goodbye"):
		girlfriend.wave_goodbye()
	
	await get_tree().create_timer(2.2).timeout

	_rotate_camera_to_front()


func _rotate_camera_to_front() -> void:
	current_state = SequenceState.CAM_ROTATE

	# Weiche Drehung der Kamera von Marieke nach vorne auf die Strasse (yaw = 0, pitch = 0)
	var start_yaw: float = player._yaw if "_yaw" in player else 0.0
	var start_pitch: float = player._pitch if "_pitch" in player else 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_method(func(val: float): player.set_camera_angles(val, player._pitch), start_yaw, 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(val: float): player.set_camera_angles(player._yaw, val), start_pitch, 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	_show_dialog_2()


func _show_dialog_2() -> void:
	current_state = SequenceState.DIALOG_2
	if dialogue_ui:
		dialogue_ui.show_line("Ich", "Zeit zu fahren.")


func _finish_sequence() -> void:
	current_state = SequenceState.GAMEPLAY
	player.controls_enabled = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
