class_name Projectile
extends Area2D

@export var speed: float = 900.0
@export var damage: int = 1
@export var lifetime: float = 1.25

var direction := Vector2.RIGHT
var _time_alive := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(fire_direction: Vector2) -> void:
	direction = fire_direction.normalized()
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	_try_damage(body)


func _on_area_entered(area: Area2D) -> void:
	_try_damage(area)


func _try_damage(hit: Node) -> void:
	var target: Node = hit
	if not target.has_method("take_damage"):
		target = hit.get_parent()

	if target != null and target.has_method("take_damage"):
		target.take_damage(damage)
		queue_free()
