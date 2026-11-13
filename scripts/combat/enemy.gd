class_name Enemy
extends Node2D

## Temporary jam balance: every enemy takes exactly two normal shots.
@export var max_health: int = 2

var health: int

signal damaged(remaining_health: int)
signal died


func _ready() -> void:
	health = max_health
	add_to_group("enemies")


func take_damage(amount: int = 1) -> void:
	if health <= 0:
		return

	health = max(health - amount, 0)
	damaged.emit(health)

	if health == 0:
		died.emit()
		queue_free()
