extends SceneTree
var failures: int = 0
var hits: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	Engine.time_scale = 4.0
	for trial in range(8):
		seed(170 + trial)
		hits = 0
		var main = load("res://scenes/main.tscn").instantiate()
		main.get_node("CharacterBody2D/ControllerUDP").free()
		root.add_child(main)
		var player = main.get_node("CharacterBody2D")
		player.hit_by_enemy.connect(func(_source): hits += 1)
		for frame in range(6):
			await physics_frame
		var section = main.get_node("Enemies/CaptivityRoom")
		var enemy = section._enemies[0]
		var movement = enemy.get_node("EnemyMovement")
		if trial >= 4:
			var close_distances := [70.0, 69.0, 50.0, 40.0]
			enemy.global_position = player.global_position + Vector2(close_distances[trial - 4], 0)
		for frame in range(240):
			await physics_frame
			if hits > 0:
				break
		check(hits > 0, "Naturally spawned enemy must hit idle player (trial %d)" % trial)
		check(movement.state == movement.State.RECOVERING, "Attacker must enter retreat recovery")
		check(enemy.global_position.distance_to(player.global_position) >= 220.0, "Enemy must teleport away after real room contact")
		check(section.contains_body_position(enemy.global_position, enemy.get_node("CollisionShape2D")), "Retreat must stay within the starting room")
		var retreat_position: Vector2 = enemy.global_position
		for frame in range(4):
			await physics_frame
		check(enemy.global_position == retreat_position, "Attacker must pause after retreat")
		check(not main.has_node("CosmosFlower"), "Power-up flower must not be placed on the map")
		main.queue_free()
		await process_frame
	Engine.time_scale = 1.0
	print("Actual map contact checks: ", "PASS" if failures == 0 else "FAIL", " (8 natural/close-range encounters)")
	quit(failures)
