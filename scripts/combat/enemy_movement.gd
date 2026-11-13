
extends Node2D

@export var move_speed: float = 120.0
@export var orbit_speed: float = 90.0
@export var stop_distance: float = 128.0
@export var distance_tolerance: float = 8.0

var player: Node2D
var orbit_direction: float = 1.0
var enemy: Node2D


func _ready() -> void:
    enemy = get_parent() as Node2D
    player = get_tree().get_first_node_in_group("player") as Node2D

    orbit_direction = [-1.0, 1.0].pick_random()


func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player") as Node2D
        if player == null:
            return

    if not is_instance_valid(enemy):
        return

    var direction = enemy.global_position.direction_to(
        player.global_position
    )

    var distance = enemy.global_position.distance_to(
        player.global_position
    )

    var movement = Vector2.ZERO

    if distance > stop_distance + distance_tolerance:
        # Chase player
        movement = direction * move_speed

    elif distance < stop_distance - distance_tolerance:
        # Move away if too close
        movement = -direction * move_speed

    else:
        # Orbit around player
        var tangent = Vector2(-direction.y, direction.x)
        movement = tangent * orbit_speed * orbit_direction

    enemy.global_position += movement * delta
