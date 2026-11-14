
extends ProgressBar

@export var player: Player 

func _ready() -> void:
    player.healthChange.change(update)
    update()


func update(current_health: float) -> void:
    value = clampf(current_health, 0.0, max_value)
