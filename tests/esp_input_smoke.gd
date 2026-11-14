extends SceneTree
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func run_checks() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var main = load("res://scenes/main.tscn").instantiate()
	var player = main.get_node("CharacterBody2D")
	main.remove_child(player)
	player.get_node("ControllerUDP").free()
	main.free()
	player.position = Vector2.ZERO
	arena.add_child(player)
	check(not player.has_method("_unhandled_input"), "Desktop keyboard/mouse gameplay handler must be removed")
	check(not player.has_method("_update_keyboard_movement"), "Keyboard movement override must be removed")
	player.update_aim(4095, 2048)
	await frames(3)
	check(player.position.x > 0.0 and player.facing_direction.x > 0.99, "ESP joystick values must move and face right")
	player.update_aim(2048, 2048)
	await frames(2)
	var stopped: Vector2 = player.position
	await frames(3)
	check(player.position.is_equal_approx(stopped), "Neutral ESP joystick must stop movement")
	player.update_aim(4095, 4095)
	check(player.move_input.length() <= 1.001, "ESP diagonal movement must remain normalized")
	player.update_aim(2048, 2048)
	player.shoot()
	check(arena.get_children().any(func(child): return child is Projectile), "ESP shoot callback must still spit")
	check(player.has_method("try_door_teleport"), "ESP door callback must remain available")
	arena.queue_free()
	await process_frame
	print("ESP-only input checks: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
