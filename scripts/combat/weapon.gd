class_name Weapon
extends Node2D
## Projectile attack component used by the shrimp's innate SnotAttack.

@export var projectile_scene: PackedScene
@export var muzzle: Node2D
@export var shots_per_second: float = 5.0
@export var damage: int = 1
var damage_multiplier: float = 1.0

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
	projectile.damage = maxi(ceili(damage * damage_multiplier), 1)
	projectile.setup(direction, get_parent() as CollisionObject2D)
	var container := get_tree().current_scene
	if container == null:
		container = get_tree().root
	container.add_child(projectile)
	projectile.global_position = spawn_point.global_position
	_cooldown = 1.0 / max(shots_per_second, 0.01)
	AudioManager.play_sfx(&"snot_shoot")
	return true
