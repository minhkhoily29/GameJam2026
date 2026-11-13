extends Node

@export var normal_speed: float = 120.0

@export var slow_distance: float = 128.0

@export_range(0.0, 1.0) var slow_multiplier: float = 0.75

var player: Node2D
var enemy: Node2D


func _ready() -> void:
 
	enemy = get_parent() as Node2D


	player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
 
	if not is_instance_valid(enemy):
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
	var distance = enemy.global_position.distance_to(
		player.global_position
	)

	var direction = enemy.global_position.direction_to(
		player.global_position
	)

	var current_speed = normal_speed

	if distance <= slow_distance:
		current_speed = normal_speed * slow_multiplier

	enemy.global_position += direction * current_speed * delta
