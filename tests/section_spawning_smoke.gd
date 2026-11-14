extends SceneTree
var failures: int = 0
var batches: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func settle() -> void:
	for frame in range(6):
		await physics_frame
func run_checks() -> void:
	for trial in range(8):
		seed(trial + 170)
		var main = load("res://scenes/main.tscn").instantiate()
		main.get_node("CharacterBody2D/ControllerUDP").free()
		root.add_child(main)
		var player = main.get_node("CharacterBody2D")
		player.set_physics_process(false)
		await settle()
		var sections = main.get_node("Enemies").get_children()
		check(sections[0].has_spawned, "Starting room should spawn automatically")
		for index in range(1, sections.size()):
			check(not sections[index].has_spawned, "Unvisited room must not spawn")
		var visit_positions = [Vector2(-789, -575), Vector2(-180, -450), Vector2(0, 180), Vector2(620, -400)]
		for index in range(sections.size()):
			var section = sections[index]
			player.global_position = visit_positions[index]
			await settle()
			var count: int = section.enemies_remaining
			check(section.has_spawned and ((index < 2 and count == 1) or (index >= 2 and count >= 3 and count <= 4)), "Room should respect its configured size: %s count=%d" % [section.name, count])
			batches += 1
			for enemy in section._enemies:
				enemy.get_node("EnemyMovement").set_physics_process(false)
				var collision = enemy.get_node("CollisionShape2D")
				check(section.contains_body_position(enemy.global_position, collision), "Full enemy body must be inside its room")
				var query := PhysicsShapeQueryParameters2D.new()
				query.shape = collision.shape
				query.transform = collision.global_transform
				query.collision_mask = 3
				query.exclude = [enemy.get_rid()]
				check(main.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(), "Spawn must not overlap walls, player, or enemies")
			player.global_position = Vector2(2000, 2000)
			await settle()
			for enemy in section._enemies:
				check(enemy.process_mode == Node.PROCESS_MODE_DISABLED, "Enemies outside current room should pause")
			player.global_position = visit_positions[index]
			await settle()
			check(section.enemies_remaining == count and section._enemies.size() == count, "Re-entering must not spawn another batch")
			for enemy in section._enemies:
				enemy.take_damage(2)
			await settle()
			check(section.enemies_remaining == 0, "Room should count defeated enemies")
			player.global_position = Vector2(2000, 2000)
			await settle()
			player.global_position = visit_positions[index]
			await settle()
			check(section.enemies_remaining == 0, "Cleared room must never respawn")
		# Returning after another room creates a fresh wave, even if cleared before.
		player.global_position = visit_positions[0]
		await settle()
		check(sections[0].wave_number == 2 and sections[0].enemies_remaining == 1, "Small room should spawn a fresh single enemy on return")
		player.global_position = visit_positions[3]
		await settle()
		check(sections[3].wave_number == 2 and sections[3].enemies_remaining >= 3 and sections[3].enemies_remaining <= 4, "Large room should spawn a fresh 3-4 enemy wave on return")
		var old_enemy = sections[3]._enemies[0]
		player.global_position = visit_positions[0]
		await settle()
		player.global_position = visit_positions[3]
		await settle()
		check(sections[3].wave_number == 3, "Returning again should create one additional wave")
		check(not is_instance_valid(old_enemy), "Previous survivors must be replaced rather than stacked")
		check(sections[3]._enemies.size() == sections[3].enemies_remaining and sections[3].enemies_remaining <= 4, "Room enemy count must remain capped")
		await settle()
		check(sections[3].wave_number == 3, "Staying in a room must not repeatedly spawn waves")
		var sprite = sections[3]._enemies[0].get_node("AnimatedSprite2D")
		check(sprite.sprite_frames.get_frame_count("walk") == 8, "Astronaut walk should have all eight frames")
		check(sprite.sprite_frames.get_frame_texture("walk", 0).get_width() == 500, "Sprite atlas frames should be 500 pixels wide")
		main.queue_free()
		await process_frame
	print("Section spawning checks: ", "PASS" if failures == 0 else "FAIL", " (", batches, " room batches)")
	quit(failures)
