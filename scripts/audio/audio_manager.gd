extends Node
## Shared playback survives enemy/projectile/pickup deletion. Uses its own RNG so
## pitch variation never changes seeded enemy spawning or teleport placement.
const MAX_VOICES := 32
const MUSIC_DUCK_DB: float = -8.0
const CUE_MUSIC_DUCK_DB: float = -4.0
const ROUTINE_DUCK_DB: float = -5.0
const ROUTINE_EVENTS := [&"snot_shoot", &"footstep", &"door_slide"]
const CUE_HOLD_SECONDS := {
	&"knife_slash": 0.2,
	&"player_hit": 0.35,
	&"enemy_death": 0.3,
	&"player_death": 0.6,
	&"enemy_teleport": 0.65,
	&"flower_pickup": 0.4,
	&"key_pickup": 0.4,
	&"door_locked": 0.2,
	&"final_door_explosion": 1.2,
}
const SOUNDS := {
	&"snot_shoot": [preload("res://sound affects/opengameart/snot_spit.wav"), -5.0],
	&"snot_hit": [preload("res://sound affects/opengameart/snot_hit.wav"), -11.0],
	&"knife_slash": [preload("res://sound affects/kenney/knife_slash.wav"), -4.0],
	&"player_hit": [preload("res://sound affects/kenney/player_hit.ogg"), -6.0],
	&"enemy_death": [preload("res://sound affects/enemy_vanish.wav"), -2.0],
	&"player_death": [preload("res://sound affects/slime for door.ogg"), -5.0],
	&"door_slide": [preload("res://sound affects/slime for door.ogg"), -13.0],
	&"enemy_teleport": [preload("res://sound affects/opengameart/enemy_teleport_02_immediate.wav"), -3.0],
	&"footstep": [preload("res://sound affects/foot steps.ogg"), -21.0],
	&"flower_pickup": [preload("res://sound affects/flower_pickup.wav"), -6.0],
	&"key_pickup": [preload("res://sound affects/kenney/key_pickup.ogg"), 8.0],
	&"final_door_explosion": [preload("res://sound affects/opengameart/final_door_grenade.wav"), -1.0],
	&"door_locked": [preload("res://sound affects/nuh uh short.wav"), 10.0],
}
var _rng := RandomNumberGenerator.new()
var _voices: Array[Node] = []
var _ambience: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_ducked := false
var _engine_paused := false
var _cue_time_left: float = 0.0
var _ambience_users: int = 0
var _next_locked_door_sound_msec: int = 0

func _ready() -> void:
	_rng.randomize()
	_ensure_bus(&"SFX", -2.0)
	_ensure_bus(&"Ambience", -34.0)
	_ensure_bus(&"Music", -18.0)
	_ensure_bus(&"Routine", 0.0, &"SFX")
	set_process(false)

func _ensure_bus(bus_name: StringName, volume: float, send: StringName = &"Master") -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, send)
		AudioServer.set_bus_volume_db(index, volume)

func _process(delta: float) -> void:
	_cue_time_left = maxf(_cue_time_left - delta, 0.0)
	if _cue_time_left <= 0.0:
		_refresh_mix()
		set_process(false)

func _music_gain() -> float:
	var state_gain := MUSIC_DUCK_DB if _music_ducked else 0.0
	return minf(state_gain, CUE_MUSIC_DUCK_DB) if _cue_time_left > 0.0 else state_gain

func _refresh_mix() -> void:
	if is_instance_valid(_music):
		_music.volume_db = _music_gain()
	var routine_bus := AudioServer.get_bus_index(&"Routine")
	if routine_bus >= 0:
		AudioServer.set_bus_volume_db(routine_bus, ROUTINE_DUCK_DB if _cue_time_left > 0.0 else 0.0)

func _make_room_for_cue(event: StringName) -> void:
	if not CUE_HOLD_SECONDS.has(event):
		return
	_cue_time_left = maxf(_cue_time_left, CUE_HOLD_SECONDS[event])
	_refresh_mix()
	set_process(true)

func play_sfx(event: StringName, world_position: Variant = null) -> Node:
	if not SOUNDS.has(event):
		push_warning("Unknown sound event: %s" % event)
		return null
	# Headless/server runs do not need an audio device.
	if DisplayServer.get_name() == "headless":
		return null
	_make_room_for_cue(event)
	while _voices.size() >= MAX_VOICES:
		var oldest := _voices.pop_front() as Node
		if is_instance_valid(oldest):
			oldest.stop()
			oldest.stream = null
			oldest.queue_free()
	var voice: Node
	if world_position is Vector2:
		var spatial := AudioStreamPlayer2D.new()
		spatial.max_distance = 1100.0
		spatial.attenuation = 1.4
		voice = spatial
	else:
		voice = AudioStreamPlayer.new()
	voice.stream = SOUNDS[event][0]
	voice.volume_db = SOUNDS[event][1]
	voice.bus = &"Routine" if ROUTINE_EVENTS.has(event) else &"SFX"
	voice.pitch_scale = _rng.randf_range(0.96, 1.04)
	if event == &"enemy_teleport":
		voice.pitch_scale = 1.0
	elif event == &"player_death":
		voice.pitch_scale *= 0.8
	elif event == &"final_door_explosion":
		voice.pitch_scale = 1.0
	elif event == &"door_locked":
		voice.pitch_scale *= 0.85
	add_child(voice)
	if voice is AudioStreamPlayer2D:
		voice.global_position = world_position
	_voices.append(voice)
	voice.finished.connect(_release_voice.bind(voice), CONNECT_ONE_SHOT)
	voice.play()
	return voice

func play_locked_door() -> void:
	var now := Time.get_ticks_msec()
	if now < _next_locked_door_sound_msec:
		return
	_next_locked_door_sound_msec = now + 600
	play_sfx(&"door_locked")

func _release_voice(voice: Node) -> void:
	_voices.erase(voice)
	if is_instance_valid(voice):
		voice.queue_free()

func stop_all_sfx() -> void:
	for voice in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
			voice.queue_free()
	_voices.clear()
	_cue_time_left = 0.0
	_refresh_mix()
	set_process(false)

func set_music_ducked(active: bool) -> void:
	_music_ducked = active
	_refresh_mix()

func set_engine_paused(active: bool) -> void:
	_engine_paused = active
	if is_instance_valid(_ambience):
		_ambience.stream_paused = active

func start_ambience() -> void:
	_ambience_users += 1
	if DisplayServer.get_name() == "headless":
		return
	if not is_instance_valid(_music):
		_music = AudioStreamPlayer.new()
		var theme := preload("res://sound affects/music/Intense background battle music.wav")
		theme.loop_mode = AudioStreamWAV.LOOP_FORWARD
		theme.loop_begin = 0
		theme.loop_end = roundi(theme.get_length() * theme.mix_rate)
		_music.stream = theme
		_music.bus = &"Music"
		_music.volume_db = _music_gain()
		add_child(_music)
		_music.play()
	if is_instance_valid(_ambience):
		return
	_ambience = AudioStreamPlayer.new()
	var stream := preload("res://sound affects/background noise.ogg")
	stream.loop = true
	_ambience.stream = stream
	_ambience.bus = &"Ambience"
	add_child(_ambience)
	_ambience.play()
	_ambience.stream_paused = _engine_paused

func stop_ambience() -> void:
	_ambience_users = maxi(_ambience_users - 1, 0)
	if _ambience_users == 0 and is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null
		_ambience.queue_free()
		_ambience = null
	if _ambience_users == 0 and is_instance_valid(_music):
		_music.stop()
		_music.stream = null
		_music.queue_free()
		_music = null

func _exit_tree() -> void:
	stop_all_sfx()
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
