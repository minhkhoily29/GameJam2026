extends Area2D

const HOLD_SECONDS := 5.0
const ENDING := preload("res://scenes/ending.tscn")

@onready var observation: Area2D = $"../Enemies/ObservationRoom"
@onready var trigger: CollisionPolygon2D = $Trigger
@onready var prompt: Label = $Prompt
var _player: CharacterBody2D
var _held_seconds := 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null or _player.is_dead or _player.is_teleporting or not _is_on_portal():
		_held_seconds = 0.0
		prompt.hide()
		return

	prompt.show()
	if not _deck_is_clear():
		_held_seconds = 0.0
		prompt.text = "Defeat all observation deck enemies"
		return

	_held_seconds = minf(_held_seconds + delta, HOLD_SECONDS)
	prompt.text = "Extracting in %.1fs" % (ceilf((HOLD_SECONDS - _held_seconds) * 10.0) / 10.0)
	if _held_seconds >= HOLD_SECONDS:
		prompt.hide()
		_player.extract_to(ENDING)


func _is_on_portal() -> bool:
	return Geometry2D.is_point_in_polygon(trigger.to_local(_player.global_position), trigger.polygon)


func _deck_is_clear() -> bool:
	if observation.wave_number < observation.wave_count or observation.enemies_remaining > 0:
		return false
	var region: CollisionPolygon2D = observation.region
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy and enemy.health > 0 and not enemy.is_queued_for_deletion():
			if Geometry2D.is_point_in_polygon(region.to_local(enemy.global_position), region.polygon):
				return false
	return true
