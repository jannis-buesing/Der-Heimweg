extends CharacterBody3D

@export var acceleration := 3.375        # 75% von 4.5
@export var max_speed := 5
@export var coasting_friction := 2.0
@export var active_braking := 9.0
@export var turn_speed := 1
@export var light_on_at_start := true
@export var controls_enabled: bool = true

# Kamera-Umsehen
# Hinweis: mouse_sensitivity steuert die Winkelgeschwindigkeit (nicht direkt die Position).
@export var mouse_sensitivity := 0.01    # Wiederhergestellte hoehere Sensitivitaet (passend zum Smoothing-System)
@export var cam_friction := 0.88          # Wie schnell die Kamerageschw. abbremst (0..1, hoeher = mehr Glide)
@export var cam_return_speed := 10       # Staerke des Zurueckziehens zur Mitte
@export var cam_return_delay := 1       # Sekunden Inaktivitaet vor Rueckfuehrung
@export var max_yaw_deg := 80.0
@export var max_pitch_up_deg := 25.0
@export var max_pitch_down_deg := 18.0

# Kamera-Zustand: aktuelle Winkel und deren Geschwindigkeit
var _yaw: float = 0.0
var _pitch: float = 0.0
var _vel_yaw: float = 0.0    # Winkelgeschwindigkeit horizontal (rad/s)
var _vel_pitch: float = 0.0  # Winkelgeschwindigkeit vertikal (rad/s)
var _time_since_mouse: float = 999.0

# Maus-Akkumulation zwischen Frames (verhindert Frame-Rate-Abhaengigkeit)
var _mouse_delta_x: float = 0.0
var _mouse_delta_y: float = 0.0

# Visuelle Referenzen
@onready var camera: Camera3D = get_node_or_null("Camera3D")
@onready var bike: Node3D = get_node_or_null("Bike")
@onready var steering_assembly: Node3D = get_node_or_null("Bike/SteeringAssembly")
@onready var headlight: SpotLight3D = get_node_or_null("Bike/SteeringAssembly/Lamp/Headlight")
@onready var lamp_lens: MeshInstance3D = get_node_or_null("Bike/SteeringAssembly/Lamp/LampLens")

var is_light_on := true


func set_bike_visible(state: bool) -> void:
	if bike:
		bike.visible = state


func _ready() -> void:
	add_to_group("player")
	is_light_on = light_on_at_start
	_apply_light_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if not controls_enabled:
		_mouse_delta_x = 0.0
		_mouse_delta_y = 0.0
		return

	# Maus-Rohdaten akkumulieren (werden in _process verarbeitet)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta_x += event.relative.x
		_mouse_delta_y += event.relative.y
		_time_since_mouse = 0.0


func _unhandled_input(event: InputEvent) -> void:
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
	if not controls_enabled:
		if camera:
			camera.rotation.y = _yaw
			camera.rotation.x = _pitch
		return

	_time_since_mouse += delta

	# Maus-Eingabe als Impuls auf die Kamera-Geschwindigkeit uebertragen
	# (delta-normiert, damit FPS-unabhaengig)
	if _mouse_delta_x != 0.0 or _mouse_delta_y != 0.0:
		var impulse_scale := mouse_sensitivity / maxf(delta, 0.008)
		_vel_yaw   -= _mouse_delta_x * impulse_scale * delta
		_vel_pitch -= _mouse_delta_y * impulse_scale * delta
		_mouse_delta_x = 0.0
		_mouse_delta_y = 0.0

	# Sanfter Zug zur Mitte nach Inaktivitaet (kein harter Snap)
	if _time_since_mouse > cam_return_delay:
		var return_strength := cam_return_speed * delta
		_vel_yaw   -= _yaw   * return_strength
		_vel_pitch -= _pitch * return_strength * 0.7

	# Physikalische Daempfung (Friction) – sorgt fuer gleichmaessiges Ausgleiten
	var friction_factor := pow(cam_friction, 60.0 * delta)  # FPS-unabhaengig
	_vel_yaw   *= friction_factor
	_vel_pitch *= friction_factor

	# Winkel integrieren
	_yaw   += _vel_yaw   * delta
	_pitch += _vel_pitch * delta

	# Clamp auf Maximalwinkel
	var max_yaw   := deg_to_rad(max_yaw_deg)
	var max_pu    := deg_to_rad(max_pitch_up_deg)
	var max_pd    := deg_to_rad(max_pitch_down_deg)

	# Beim Anschlag Geschwindigkeit abfangen (kein Prellen)
	if abs(_yaw) >= max_yaw:
		_yaw = clamp(_yaw, -max_yaw, max_yaw)
		_vel_yaw = 0.0
	if _pitch > max_pu:
		_pitch = max_pu
		_vel_pitch = minf(_vel_pitch, 0.0)
	if _pitch < -max_pd:
		_pitch = -max_pd
		_vel_pitch = maxf(_vel_pitch, 0.0)

	# Sehr kleine Restbewegung einrasten lassen (verhindert ewiges Nachschwingen)
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

	# Lenkeinschlag des Lenkers
	# Der Lenker selbst bewegt sich immer gleich.
	if steering_assembly:
		var target_steer: float = -turn_input * deg_to_rad(14.0)

		steering_assembly.rotation.y = lerp_angle(
			steering_assembly.rotation.y,
			target_steer,
			10.0 * delta
		)

	# Fahrrad-Neigung
	if bike:
		var target_lean: float = -turn_input * deg_to_rad(3.5) * speed_factor

		bike.rotation.z = lerp_angle(
			bike.rotation.z,
			target_lean,
			8.0 * delta
		)
	
	move_and_slide()
