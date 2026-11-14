
extends ProgressBar

@export var player: Player 

func _ready() -> void:
    player.health_changed.connect(update)
    update(player.health, player.max_health)


func update(current_health: int, maximum_health: int) -> void:
    max_value = maximum_health
    value = clampi(current_health, 0, maximum_health)
