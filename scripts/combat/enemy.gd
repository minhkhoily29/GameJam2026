class_name Enemy
extends CharacterBody2D

## Temporary jam balance: every enemy takes exactly two normal shots.
@export var max_health: int = 2

var health: int
var _hit_flash_time: float = 0.0
@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

signal damaged(remaining_health: int)
signal died


func _ready() -> void:
	health = max_health
	add_to_group("enemies")


func take_damage(amount: int = 1) -> void:
	if health <= 0 or amount <= 0:
		return

	health = max(health - amount, 0)
	_hit_flash_time = 0.12
	if _sprite != null:
		_sprite.self_modulate = Color(1.0, 0.25, 0.25)
	damaged.emit(health)

	if health == 0:
		died.emit()
		queue_free()


func _process(delta: float) -> void:
	if _hit_flash_time > 0.0:
		_hit_flash_time = maxf(_hit_flash_time - delta, 0.0)
		if _hit_flash_time <= 0.0 and _sprite != null:
			_sprite.self_modulate = Color.WHITE


func on_player_hit(target: Node2D) -> void:
	if health <= 0:
		return
	var movement := get_node_or_null("EnemyMovement")
	if movement != null:
		movement.retreat_after_hit(target)
