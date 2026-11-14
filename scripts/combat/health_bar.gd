extends ProgressBar

@export var player: Node
@onready var health_text: Label = $HealthText

func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_signal("health_changed"):
		push_error("Health bar could not find the player.")
		return
	player.health_changed.connect(update_health)
	update_health(player.health, player.max_health)

func update_health(current_health: int, maximum_health: int) -> void:
	max_value = maxi(maximum_health, 1)
	value = clampi(current_health, 0, maximum_health)
	health_text.text = "%d / %d" % [int(value), maximum_health]
