extends Area2D
## A fresh wave on entry after visiting a different section.
signal section_spawned(count: int)
signal section_cleared

@export var enemy_scene: PackedScene = preload("res://scenes/human_enemy.tscn")
@export_range(1, 20) var minimum_enemies: int = 3
@export_range(1, 20) var maximum_enemies: int = 4
@export var player_clearance: float = 140.0
@export var enemy_spacing: float = 100.0
@export var placement_attempts: int = 300

var has_spawned: bool = false
var wave_number: int = 0
var enemies_remaining: int = 0
var _player: CharacterBody2D
var _active: bool = false
var _enemies: Array[CharacterBody2D] = []
@onready var region: CollisionPolygon2D = $CollisionPolygon2D

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		return
	var inside := overlaps_body(_player) and Geometry2D.is_point_in_polygon(region.to_local(_player.global_position), region.polygon)
	if inside != _active:
		_active = inside
		if inside:
			var previous: Node = _player.get_meta("enemy_current_section") if _player.has_meta("enemy_current_section") else null
			if previous != self or not has_spawned:
				_player.set_meta("enemy_current_section", self)
				_spawn_wave()
		for enemy in _enemies:
			if is_instance_valid(enemy):
				enemy.process_mode = Node.PROCESS_MODE_INHERIT if inside else Node.PROCESS_MODE_DISABLED

func _spawn_wave() -> void:
	if enemy_scene == null:
		return
	# Replace survivors on a return visit so waves never stack above room limits.
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.free()
	_enemies.clear()
	enemies_remaining = 0
	has_spawned = true
	wave_number += 1
	var count := randi_range(minimum_enemies, maxi(minimum_enemies, maximum_enemies))
	var points: Array[Vector2] = []
	var bounds := Rect2(region.polygon[0], Vector2.ZERO)
	for point in region.polygon:
		bounds = bounds.expand(point)
	for i in range(count):
		var enemy := enemy_scene.instantiate() as CharacterBody2D
		if enemy == null:
			push_error("Section enemy scene must be a CharacterBody2D.")
			break
		var collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.shape == null:
			enemy.free()
			push_error("Section enemy needs a CollisionShape2D.")
			break
		var placed := false
		for attempt in range(placement_attempts):
			var local_point := Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
			var destination := region.to_global(local_point)
			if destination.distance_to(_player.global_position) < player_clearance:
				continue
			if not contains_body_position(destination, collision):
				continue
			var too_close := false
			for point in points:
				if point.distance_to(destination) < enemy_spacing:
					too_close = true
					break
			if too_close:
				continue
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = collision.shape
			query.transform = Transform2D(0.0, destination) * collision.transform
			query.collision_mask = enemy.collision_mask
			query.margin = 6.0
			if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				continue
			enemy.set_meta("spawn_section", self)
			enemy.position = to_local(destination)
			enemy.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
			add_child(enemy)
			_enemies.append(enemy)
			points.append(destination)
			enemies_remaining += 1
			placed = true
			break
		if not placed:
			enemy.free()
			push_warning("Could not find a clear enemy spawn in section %s." % name)
	section_spawned.emit(enemies_remaining)

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
	if enemies_remaining == 0:
		section_cleared.emit()
