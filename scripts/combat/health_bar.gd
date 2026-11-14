
extends ProgressBar

@export var full_HP: float = 100.0

func _ready() -> void:
    max_value = full_HP
    value = full_HP
    show_percentage = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_health(current_health: float) -> void:
    value = clampf(current_health, 0.0, max_value)
