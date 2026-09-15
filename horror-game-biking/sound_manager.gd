# sound_manager.gd
# Erzeugt alle Fahrrad- und Umgebungsgeraeusche prozedural (AudioStreamGenerator).
# Keine externen Audiodateien benoetigt.
# Kommunikation: Liest Spielergeschwindigkeit ueber Gruppe "player".

extends Node

const SAMPLE_RATE: float = 44100.0

# Interner LCG-Rauschgenerator (schneller als randi())
var _noise_seed: int = 54321

# Glaettungszustand fuer Wind-Lowpass
var _wind_lp: float = 0.0
var _rolling_lp: float = 0.0

var _rolling_phase: float = 0.0
var _ambient_phase: float = 0.0

# Zielwerte (werden geglaettet)
var _wind_vol_target: float = -60.0
var _rolling_vol_target: float = -60.0

var _wind_player: AudioStreamPlayer
var _rolling_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer

var _wind_pb: AudioStreamGeneratorPlayback
var _rolling_pb: AudioStreamGeneratorPlayback
var _ambient_pb: AudioStreamGeneratorPlayback


func _ready() -> void:
	_wind_player   = _make_player("Environment", 0.2)
	_rolling_player = _make_player("SFX", 0.15)
	_ambient_player = _make_player("Environment", 0.25)

	add_child(_wind_player)
	add_child(_rolling_player)
	add_child(_ambient_player)

	# Kurz warten, dann Playback-Referenzen holen (erst nach play() verfuegbar)
	_wind_player.play()
	_rolling_player.play()
	_ambient_player.play()

	await get_tree().process_frame
	await get_tree().process_frame

	_wind_pb    = _wind_player.get_stream_playback()    as AudioStreamGeneratorPlayback
	_rolling_pb = _rolling_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_ambient_pb = _ambient_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _make_player(bus: String, buf_len: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -60.0
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = buf_len
	p.stream = gen
	return p


func _process(delta: float) -> void:
	# Spielergeschwindigkeit lesen
	var speed := 0.0
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p := players[0] as CharacterBody3D
		if p:
			speed = p.velocity.length()

	var t: float = clamp(speed / 5.2, 0.0, 1.0)  # Normierung 0..1

	# Ziel-Lautstaerken
	_wind_vol_target    = lerp(-52.0, -22.0, t)
	_rolling_vol_target = lerp(-60.0, -30.0, t)

	# Lautstaerken sanft anpassen
	_wind_player.volume_db    = lerp(_wind_player.volume_db,    _wind_vol_target,    4.0 * delta)
	_rolling_player.volume_db = lerp(_rolling_player.volume_db, _rolling_vol_target, 4.0 * delta)
	# Ambient ist konstant leise
	_ambient_player.volume_db = lerp(_ambient_player.volume_db, -38.0, 2.0 * delta)

	_fill_wind(t)
	_fill_rolling(t)
	_fill_ambient()


func _noise() -> float:
	_noise_seed = (_noise_seed * 1664525 + 1013904223) & 0x7FFFFFFF
	return float(_noise_seed) / 2147483647.0 * 2.0 - 1.0


func _fill_wind(t: float) -> void:
	if not _wind_pb:
		return
	var frames := _wind_pb.get_frames_available()
	for _i in frames:
		# Lowpass-gefiltertes Rauschen (sanfter Wind)
		_wind_lp += (_noise() - _wind_lp) * 0.08
		var s := _wind_lp * 0.6
		# Leichte Stereo-Variation
		_wind_pb.push_frame(Vector2(s * 0.95, s * 1.05))


func _fill_rolling(t: float) -> void:
	if not _rolling_pb:
		return
	var frames := _rolling_pb.get_frames_available()
	# Rollfrequenz steigt mit Geschwindigkeit
	var base_freq: float = lerp(35.0, 110.0, t)
	var phase_step: float = base_freq / SAMPLE_RATE * TAU

	for _i in frames:
		_rolling_phase = fmod(_rolling_phase + phase_step, TAU)
		_rolling_lp += (_noise() - _rolling_lp) * 0.12
		# Grundton (Kette/Rad) + koerniges Rauschen
		var tone := sin(_rolling_phase) * 0.12
		var grain := _rolling_lp * 0.08
		var s := (tone + grain) * t
		_rolling_pb.push_frame(Vector2(s, s))


func _fill_ambient() -> void:
	if not _ambient_pb:
		return
	var frames := _ambient_pb.get_frames_available()
	for _i in frames:
		_ambient_phase += 0.3 / SAMPLE_RATE
		# Sehr langsam moduliertes Rauschen (Nachtambiente)
		var mod := sin(_ambient_phase) * 0.012 + 0.018
		var s := _noise() * mod
		_ambient_pb.push_frame(Vector2(s, s))
