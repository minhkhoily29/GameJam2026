extends Area2D
## Telegraph each wave before its enemies arrive.
signal section_spawned(count: int)
signal section_cleared

@export var enemy_scene: PackedScene = preload("res://scenes/human_enemy.tscn")
@export_range(1, 20) var minimum_enemies: int = 3
@export_range(1, 20) var maximum_enemies: int = 4
@export var player_clearance: float = 140.0
@export var enemy_spacing: float = 100.0
@export var placement_attempts: int = 300
enum SpawnLayout { RANDOM, SPREAD, CORNERS }
@export var spawn_layout: SpawnLayout = SpawnLayout.RANDOM

@export_range(1, 10) var wave_count: int = 1
@export var center_trigger_radius: float = 0.0
@export var spawn_warning_duration: float = 0.65

const REENTRY_DELAY: float = 1.0

var _started: bool = false
var _outside_time: float = 0.0
var _warning_time: float = 0.0
var _retry_time: float = 0.0
var _landing_points: Array[Vector2] = []
var _markers: Array[Node2D] = []
var wave_number: int = 0
var enemies_remaining: int = 0
var _player: CharacterBody2D
@onready var region: CollisionPolygon2D = $CollisionPolygon2D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null or _player.get("is_dead") == true:
		_clear_markers()
		return

	var point := region.to_local(_player.global_position)
	if not Geometry2D.is_point_in_polygon(point, region.polygon):
		_outside_time += delta
		return

	if not _started:
		if center_trigger_radius > 0.0 and point.distance_to(_room_bounds().get_center()) > center_trigger_radius:
			return
		_started = true
	elif _outside_time >= REENTRY_DELAY:
		_outside_time = 0.0
		_reset_encounter()
		return
	_outside_time = 0.0

	if not _landing_points.is_empty():
		_warning_time -= delta
		if _warning_time <= 0.0:
			_land_wave()
	elif enemies_remaining == 0 and wave_number < wave_count:
		_retry_time -= delta
		if _retry_time <= 0.0:
			_prepare_wave()


func _reset_encounter() -> void:
	_clear_markers()
	_landing_points.clear()
	for child in get_children():
		if child is Enemy:
			if child.died.is_connected(_on_enemy_died):
				child.died.disconnect(_on_enemy_died)
			child.queue_free()
	wave_number = 0
	enemies_remaining = 0
	_retry_time = 0.0


func _room_bounds() -> Rect2:
	var bounds := Rect2(region.polygon[0], Vector2.ZERO)
	for point in region.polygon:
		bounds = bounds.expand(point)
	return bounds


func _prepare_wave() -> void:
	if enemy_scene == null:
		return
	var preview := enemy_scene.instantiate() as CharacterBody2D
	var collision := preview.get_node("CollisionShape2D") as CollisionShape2D
	var count := randi_range(minimum_enemies, maxi(minimum_enemies, maximum_enemies))
	var bounds := _room_bounds()
	var points: Array[Vector2] = []
	for i in range(count):
		var destination = _find_spawn_point(bounds, i, preview, collision, points)
		if destination == null:
			preview.free()
			_retry_time = 0.25
			return
		points.append(destination)
	preview.free()

	_landing_points = points
	_warning_time = spawn_warning_duration
	for destination in points:
		var marker := preload("res://scripts/combat/teleport_marker.gd").new() as Node2D
		marker.position = to_local(destination)
		marker.z_index = 8
		add_child(marker)
		_markers.append(marker)


func _land_wave() -> void:
	_clear_markers()
	var preview := enemy_scene.instantiate() as CharacterBody2D
	var collision := preview.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.collision_mask = preview.collision_mask
	query.margin = 6.0
	for destination in _landing_points:
		query.transform = Transform2D(0.0, destination) * collision.transform
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			preview.free()
			_landing_points.clear()
			_retry_time = 0.25
			return
	preview.free()

	wave_number += 1
	enemies_remaining = _landing_points.size()
	for destination in _landing_points:
		var enemy := enemy_scene.instantiate() as CharacterBody2D
		enemy.set_meta("spawn_section", self)
		enemy.position = to_local(destination)
		enemy.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
		add_child(enemy)
		enemy.get_node("EnemyMovement").play_spawn_arrival()
	_landing_points.clear()
	AudioManager.play_sfx(&"enemy_teleport")
	section_spawned.emit(enemies_remaining)


func _clear_markers() -> void:
	for marker in _markers:
		marker.queue_free()
	_markers.clear()


func _find_spawn_point(bounds: Rect2, index: int, enemy: CharacterBody2D, collision: CollisionShape2D, points: Array[Vector2]) -> Variant:
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.collision_mask = enemy.collision_mask
	query.margin = 6.0
	var best: Variant = null
	var best_score := -1.0
	var valid_samples := 0
	var center := region.to_global(bounds.get_center())

	for attempt in range(placement_attempts):
		var zone := bounds
		if spawn_layout == SpawnLayout.CORNERS and attempt < placement_attempts / 2.0:
			var corner := Vector2(index % 2, floori(index / 2.0) % 2)
			var size := bounds.size * 0.5
			zone = Rect2(bounds.position + corner * size, size)
		var local_point := Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y, zone.end.y))
		var destination := region.to_global(local_point)
		if destination.distance_to(_player.global_position) < player_clearance or not contains_body_position(destination, collision):
			continue
		var nearest := INF
		for point in points:
			nearest = minf(nearest, point.distance_to(destination))
		if nearest < enemy_spacing:
			continue
		query.transform = Transform2D(0.0, destination) * collision.transform
		if not space.intersect_shape(query, 1).is_empty():
			continue
		if spawn_layout == SpawnLayout.RANDOM:
			return destination
		# Prefer the largest gap between enemies. Start near the room's edge.
		var score := destination.distance_to(center) if points.is_empty() else nearest
		if score > best_score:
			best = destination
			best_score = score
		valid_samples += 1
		if valid_samples >= 24:
			break
	return best


func contains_body_position(destination: Vector2, collision: CollisionShape2D) -> bool:
	# Keep the full body's bounding rectangle inside the section.
	var rect := collision.shape.get_rect().grow(6.0)
	var transform_at_destination := Transform2D(0.0, destination) * collision.transform
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		if not Geometry2D.is_point_in_polygon(region.to_local(transform_at_destination * corner), region.polygon):
			return false
	return true

func _on_enemy_died() -> void:
	enemies_remaining -= 1
	if enemies_remaining == 0 and wave_number >= wave_count:
		section_cleared.emit()
