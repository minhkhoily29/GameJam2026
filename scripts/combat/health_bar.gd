
extends ProgressBar

@export var player: Player 

func _ready() -> void:
    player.healthChange.change(update)
    update()


func update():
    value = clampf(player.currentHealth, 0.0, max_value)
