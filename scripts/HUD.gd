extends CanvasLayer

@onready var key_label: Label = $HealthPanel/Content/KeyStatus
@onready var kills_label: Label = $HealthPanel/Content/KillCount
var player: Node

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("HUD could not find player.")
		return
	player.final_key_collected.connect(_update_key)
	player.kill_count_changed.connect(_update_kills)
	_update_key()
	_update_kills(player.enemies_killed)

func _update_key() -> void:
	key_label.text = "KEY: COLLECTED" if player.has_final_key else "KEY: NOT FOUND"
	key_label.modulate = Color(0.75, 1.0, 0.45) if player.has_final_key else Color(0.75, 0.78, 0.8)

func _update_kills(total: int) -> void:
	kills_label.text = "ENEMIES KILLED: %d" % total
