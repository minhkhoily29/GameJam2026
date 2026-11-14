extends SceneTree
var failures := 0
var batches := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func settle() -> void:
	for frame in range(6):
		await physics_frame
func check_and_freeze(section: Area2D, main: Node2D) -> void:
	for enemy in section._enemies:
		enemy.get_node("EnemyMovement").set_physics_process(false)
		var collision = enemy.get_node("CollisionShape2D")
		check(section.contains_body_position(enemy.global_position, collision), "Enemy must stay entirely inside its room")
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.collision_mask = 3
		query.exclude = [enemy.get_rid()]
		check(main.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(), "Enemy must not overlap walls or other bodies")
func run_checks() -> void:
	for trial in range(8):
		seed(170 + trial)
		var main = load("res://scenes/main.tscn").instantiate()
		main.get_node("CharacterBody2D/ControllerUDP").free()
		root.add_child(main)
		var player = main.get_node("CharacterBody2D")
		player.set_physics_process(false)
		await settle()
		var sections = main.get_node("Enemies")
		var cargo = sections.get_node("CargoRoom")
		var hall = sections.get_node("MessHall")
		var observation = sections.get_node("ObservationRoom")
		check(hall.minimum_enemies == 3 and hall.maximum_enemies == 4, "Main battle hall must have 3-4 enemies")
		check(observation.minimum_enemies == 2 and observation.maximum_enemies == 2, "Third large room must have exactly two enemies")
		# Walk all connecting corridors before entering any active room.
		var corridors := [Vector2(-821, -350), Vector2(-52, -374), Vector2(800, 200), Vector2(600, 650)]
		for point in corridors:
			player.global_position = point
			await settle()
			for section in [cargo, hall, observation]:
				check(not section.has_spawned, "Hallways must not activate room spawning")
		var rooms := [cargo, hall, observation]
		var positions := [Vector2(-180, -550), Vector2(0, 180), Vector2(620, -400)]
		for index in range(rooms.size()):
			var section = rooms[index]
			player.global_position = positions[index]
			await settle()
			var count: int = section.enemies_remaining
			check(section.has_spawned and count >= section.minimum_enemies and count <= section.maximum_enemies, "Room count must match configuration: %s (%d)" % [section.name, count])
			batches += 1
			check_and_freeze(section, main)
			for enemy in section._enemies:
				for point in corridors:
					check(not section.contains_body_position(point, enemy.get_node("CollisionShape2D")), "Hallways must not allow spawn or teleport placement")
			var wave: int = section.wave_number
			player.global_position = Vector2(600, 650)
			await settle()
			player.global_position = positions[index]
			await settle()
			check(section.wave_number == wave, "Corridor-only round trip must not create a new wave")
			for enemy in section._enemies:
				enemy.take_damage(enemy.max_health)
			await settle()
			check(section.enemies_remaining == 0, "Defeated enemies must clear the room")
		# Revisiting after a different room creates a fresh wave without stacking.
		player.global_position = positions[1]
		await settle()
		check(hall.wave_number == 2 and hall.enemies_remaining >= 3 and hall.enemies_remaining <= 4, "Main hall return wave must have 3-4 enemies")
		check_and_freeze(hall, main)
		player.global_position = positions[2]
		await settle()
		check(observation.wave_number == 2 and observation.enemies_remaining == 2, "Third-room return wave must have two enemies")
		check_and_freeze(observation, main)
		var previous_enemy = observation._enemies[0]
		player.global_position = positions[1]
		await settle()
		player.global_position = positions[2]
		await settle()
		check(observation.wave_number == 3 and observation.enemies_remaining == 2, "Returning again must replace the previous two-enemy wave")
		check(not is_instance_valid(previous_enemy), "Old waves must be replaced without stacking")
		main.queue_free()
		await process_frame
	print("Section spawning checks: ", "PASS" if failures == 0 else "FAIL", " (", batches, " room batches plus returns and hallway checks)")
	quit(failures)
