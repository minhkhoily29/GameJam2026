extends CanvasLayer

@onready var key_label: Label = $HealthPanel/Content/KeyStatus
@onready var kills_label: Label = $HealthPanel/Content/KillCount
@onready var cosmos_status: VBoxContainer = $HealthPanel/Content/CosmosStatus
@onready var cosmos_label: Label = $HealthPanel/Content/CosmosStatus/Countdown
@onready var cosmos_bar: ProgressBar = $HealthPanel/Content/CosmosStatus/Remaining
@onready var cosmos_tint: ColorRect = $CosmosTint
@onready var health_warning: ColorRect = $LowHealthTint
var player: Node
var _warning_time: float = 0.0

func _ready() -> void:
	set_process(false)
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("HUD could not find player.")
		return
	player.final_key_collected.connect(_update_key)
	player.kill_count_changed.connect(_update_kills)
	player.cosmos_time_changed.connect(_update_cosmos)
	_update_key()
	_update_kills(player.enemies_killed)
	player.health_changed.connect(_update_health_warning)
	_update_health_warning(player.health, player.max_health)

func _update_key() -> void:
	key_label.text = "KEY: COLLECTED" if player.has_final_key else "KEY: NOT FOUND"
	key_label.modulate = Color(0.75, 1.0, 0.45) if player.has_final_key else Color(0.75, 0.78, 0.8)

func _update_kills(total: int) -> void:
	kills_label.text = "ENEMIES KILLED: %d" % total

func _update_cosmos(seconds_left: float, duration: float) -> void:
	cosmos_status.visible = seconds_left > 0.0
	cosmos_tint.visible = cosmos_status.visible
	cosmos_bar.max_value = duration
	cosmos_bar.value = seconds_left
	cosmos_label.text = "COSMOS BOOST  %.1fs" % (ceilf(seconds_left * 10.0) / 10.0)

func _update_health_warning(current_health: int, _maximum_health: int) -> void:
	var show_warning := current_health == 1
	if show_warning and not health_warning.visible:
		_warning_time = 0.0
		health_warning.color.a = 0.19
	health_warning.visible = show_warning
	set_process(show_warning)


func _process(delta: float) -> void:
	_warning_time += delta
	var pulse := (1.0 + cos(_warning_time * TAU / 1.4)) * 0.5
	health_warning.color.a = lerpf(0.035, 0.19, pulse)
