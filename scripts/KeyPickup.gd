extends Area2D

var collected: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	if not body.has_method("collect_final_key"):
		return
	if not body.collect_final_key():
		return
	collected = true
	queue_free()
