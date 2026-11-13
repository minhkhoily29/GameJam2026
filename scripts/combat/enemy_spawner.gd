
extends Node2D
@export var enemy_scene: PackedScene
@export var spawn_radius: float = 200.0
func spawn_enemies(amount: int) -> void:
    var player = get_tree().get_first_node_in_group("player") as Node2D
    if player == null:
        push_warning("Player not found!")
        return
    for i in range(amount):
        var enemy = enemy_scene.instantiate() as CharacterBody2D

        # Spread enemies evenly around the player
        var angle = TAU * i / amount
        var offset = Vector2.RIGHT.rotated(angle) * spawn_radius

        get_tree().current_scene.add_child(enemy)
        enemy.global_position = player.global_position + offset
