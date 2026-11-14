extends Node
## Player-owned state loops: no stacked voices or tails after the state ends.
@export var low_health_threshold: int = 1
@export var heartbeat_volume_db: float = -4.0
@export var powered_volume_db: float = -11.0
var _player: Node
var _heartbeat: AudioStreamPlayer
var _powered: AudioStreamPlayer
var _low_health_active := false
var _power_active := false

func _ready() -> void:
	_player = get_parent()
	if DisplayServer.get_name() != "headless":
		_heartbeat = _make_loop(preload("res://sound affects/opengameart/low_health_heartbeat.wav"), heartbeat_volume_db)
		_powered = _make_loop(preload("res://sound affects/power_up_hyper.wav"), powered_volume_db)
	_player.health_changed.connect(_on_health_changed)
	_player.cosmos_buff_changed.connect(_on_power_changed)
	_player.died.connect(_on_died)
	_on_health_changed(_player.health, _player.max_health)
	_on_power_changed(_player._cosmos_time_left > 0.0)

func _make_loop(stream: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.bus = &"SFX"
	voice.volume_db = volume
	add_child(voice)
	return voice

func _on_health_changed(current: int, _maximum: int) -> void:
	var active: bool = not _player.is_dead and current > 0 and current <= low_health_threshold
	if active == _low_health_active:
		return
	_low_health_active = active
	_set_loop(_heartbeat, active)

func _on_power_changed(active: bool) -> void:
	active = active and not _player.is_dead
	if active == _power_active:
		return
	_power_active = active
	_set_loop(_powered, active)

func _set_loop(voice: AudioStreamPlayer, active: bool) -> void:
	if not is_instance_valid(voice):
		return
	if active:
		voice.play()
	else:
		voice.stop()

func _on_died() -> void:
	_low_health_active = false
	_power_active = false
	_set_loop(_heartbeat, false)
	_set_loop(_powered, false)

func _exit_tree() -> void:
	for voice in [_heartbeat, _powered]:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
