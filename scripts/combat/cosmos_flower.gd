extends Area2D
@export var damage_up: float = 2.0
@export var speed_up: float = 2.0
var collected: bool = false
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	call_deferred("_check_overlapping_players")
func _check_overlapping_players() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)
func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("apply_cosmos_buff"):
		push_warning("Player is missing apply_cosmos_buff()")
		return
	collected = true
	body.apply_cosmos_buff(
		damage_up,
		speed_up
	)
	queue_free()
