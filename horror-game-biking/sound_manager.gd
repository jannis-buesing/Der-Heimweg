# sound_manager.gd
# Central Audio Manager supporting dynamic bike sound synthesis,
# sample playback, environmental loops, and horror triggers.

extends Node

# Audio Players
var _bike_tire_player: AudioStreamPlayer
var _bike_chain_player: AudioStreamPlayer
var _bike_pedal_player: AudioStreamPlayer
var _bike_sfx_player: AudioStreamPlayer

var _forest_ambient_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _village_ambient_player: AudioStreamPlayer
var _horror_drone_player: AudioStreamPlayer

# Preloaded AudioStreams
var sound_bike_bell: AudioStream = load("res://Audio/Bike/bike_bell.wav")
var sound_bike_brake: AudioStream = load("res://Audio/Bike/bike_brake.wav")
var sound_bike_light: AudioStream = load("res://Audio/Bike/bike_light_switch.wav")

var sound_forest_night: AudioStream = load("res://Audio/Environment/Forest/forest_night_loop.wav")
var sound_forest_wind: AudioStream = load("res://Audio/Environment/Forest/forest_wind_light.wav")
var sound_tire_asphalt: AudioStream = load("res://Audio/Bike/bike_tire_asphalt.wav")
var sound_chain_loop: AudioStream = load("res://Audio/Bike/bike_chain_loop.wav")
var sound_pedal_loop: AudioStream = load("res://Audio/Bike/bike_pedal_loop.wav")
var sound_village_ambient: AudioStream = load("res://Audio/Environment/Village/village_ambient_night.wav")
var sound_horror_drone: AudioStream = load("res://Audio/Horror/subtle_drone_night.wav")

# State tracking for dynamic bike audio
var _prev_speed: float = 0.0
var _is_braking_prev: bool = false


func _ready() -> void:
	_setup_audio_players()
	_start_ambient_loops()


func _setup_audio_players() -> void:
	_bike_tire_player = _create_player("Bike", sound_tire_asphalt, true)
	_bike_chain_player = _create_player("Bike", sound_chain_loop, true)
	_bike_pedal_player = _create_player("Bike", sound_pedal_loop, true)
	_bike_sfx_player = _create_player("Bike", null, false)
	
	_forest_ambient_player = _create_player("Environment", sound_forest_night, true)
	_wind_player = _create_player("Environment", sound_forest_wind, true)
	_village_ambient_player = _create_player("Environment", sound_village_ambient, true)
	_horror_drone_player = _create_player("Horror", sound_horror_drone, true)


func _create_player(bus_name: String, stream: AudioStream, auto_play: bool) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.bus = bus_name if AudioServer.get_bus_index(bus_name) != -1 else "Master"
	p.volume_db = -60.0
	p.stream = stream
	add_child(p)
	if auto_play and stream != null:
		p.play()
	return p


func _start_ambient_loops() -> void:
	if _forest_ambient_player and _forest_ambient_player.stream:
		_forest_ambient_player.volume_db = -24.0
	if _wind_player and _wind_player.stream:
		_wind_player.volume_db = -30.0


func _process(delta: float) -> void:
	_update_bike_audio(delta)


func _update_bike_audio(delta: float) -> void:
	var speed := 0.0
	var player_node: Node3D = null
	
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_node = players[0] as Node3D
		if "velocity" in player_node:
			speed = player_node.velocity.length()
	
	var norm_speed := clamp(speed / 7.0, 0.0, 1.0) # 0 to 1 scaling (up to ~25 km/h)
	var accel := (speed - _prev_speed) / max(delta, 0.001)
	_prev_speed = speed
	
	# Tire Rolling Volume & Pitch
	if norm_speed > 0.02:
		var target_tire_vol = lerp(-40.0, -12.0, norm_speed)
		_bike_tire_player.volume_db = lerp(_bike_tire_player.volume_db, target_tire_vol, 6.0 * delta)
		_bike_tire_player.pitch_scale = lerp(0.8, 1.4, norm_speed)
	else:
		_bike_tire_player.volume_db = lerp(_bike_tire_player.volume_db, -60.0, 8.0 * delta)
	
	# Pedal & Chain Cadence (only audible when accelerating/pedaling)
	if accel > 0.1 and norm_speed > 0.05:
		var target_pedal_vol = lerp(-36.0, -14.0, norm_speed)
		_bike_pedal_player.volume_db = lerp(_bike_pedal_player.volume_db, target_pedal_vol, 8.0 * delta)
		_bike_pedal_player.pitch_scale = lerp(0.7, 1.5, norm_speed)
		
		_bike_chain_player.volume_db = lerp(_bike_chain_player.volume_db, target_pedal_vol - 4.0, 8.0 * delta)
		_bike_chain_player.pitch_scale = lerp(0.8, 1.3, norm_speed)
	else:
		# Freewheel / Coasting
		_bike_pedal_player.volume_db = lerp(_bike_pedal_player.volume_db, -60.0, 6.0 * delta)
		_bike_chain_player.volume_db = lerp(_bike_chain_player.volume_db, -60.0, 6.0 * delta)
	
	# Brake squeal detection
	var is_braking = (accel < -2.0 and speed > 1.0)
	if is_braking and not _is_braking_prev:
		play_sfx(sound_bike_brake, -10.0)
	_is_braking_prev = is_braking


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or _bike_sfx_player == null:
		return
	_bike_sfx_player.stream = stream
	_bike_sfx_player.volume_db = volume_db
	_bike_sfx_player.play()


func play_bell() -> void:
	play_sfx(sound_bike_bell, -6.0)


func play_light_switch() -> void:
	play_sfx(sound_bike_light, -12.0)
