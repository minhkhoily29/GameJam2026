
extends Area2D
@export var enemies_to_spawn: int = 2
@export var enemy_spawner: Node2D
var activated: bool = false
func _on_body_entered(body: Node2D) -> void:
    if activated:
        return
    if body.is_in_group("player"):
        activated = true

        if enemy_spawner != null:
            enemy_spawner.spawn_enemies(enemies_to_spawn)
