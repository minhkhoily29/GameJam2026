class_name Weapon
extends Node2D

@export var projectile_scene: PackedScene
@export var muzzle: Node2D
@export var shots_per_second: float = 5.0

var _cooldown := 0.0


func _process(delta: float) -> void:
	_cooldown = max(_cooldown - delta, 0.0)


## Call from the player input/controller. The direction may be mouse aim or a stick.
func fire(direction: Vector2) -> bool:
	if _cooldown > 0.0 or direction.is_zero_approx() or projectile_scene == null:
		return false

	var projectile := projectile_scene.instantiate() as Projectile
	if projectile == null:
		return false

	var spawn_point := muzzle if muzzle != null else self
	projectile.global_position = spawn_point.global_position
	projectile.setup(direction)
	get_tree().current_scene.add_child(projectile)
	_cooldown = 1.0 / max(shots_per_second, 0.01)
	return true
