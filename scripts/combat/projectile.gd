class_name Projectile
extends Area2D

@export var speed: float = 900.0
@export var damage: int = 1
@export var lifetime: float = 1.25

var direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0
var _has_hit: bool = false
var _shooter: CollisionObject2D
@onready var sweep: ShapeCast2D = $ShapeCast2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if is_instance_valid(_shooter):
		sweep.add_exception(_shooter)


func setup(fire_direction: Vector2, shooter: CollisionObject2D = null) -> void:
	_shooter = shooter
	direction = fire_direction.normalized()
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	# Sweep the bullet's full radius so fast shots cannot skip thin walls/enemies.
	sweep.target_position = Vector2.RIGHT * speed * delta
	sweep.force_shapecast_update()
	if sweep.is_colliding():
		_try_damage(sweep.get_collider(0))
		if _has_hit:
			return
	global_position += direction * speed * delta
	_time_alive += delta

	if _time_alive >= lifetime:
		_has_hit = true
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	_try_damage(body)


func _on_area_entered(area: Area2D) -> void:
	_try_damage(area)


func _try_damage(hit: Node) -> void:
	if _has_hit or hit == _shooter:
		return

	# Find the enemy, including when its hurtbox is nested.
	var target: Node = hit

	while target != null:
		if target.is_in_group("enemies") and target.has_method("take_damage"):
			break
		target = target.get_parent()

	if target == null:
		if hit is PhysicsBody2D:
			_has_hit = true
			queue_free()
		return

	# queue_free() is deferred, so block any additional hits now.
	_has_hit = true
	target.take_damage(damage)
	queue_free()
