extends SceneTree
var failures: int = 0
var deaths: int = 0
var damage_events: Array[int] = []
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func spawn_enemy(arena: Node2D, point: Vector2) -> CharacterBody2D:
	var enemy = load("res://scenes/human_enemy.tscn").instantiate()
	enemy.position = point
	arena.add_child(enemy)
	enemy.get_node("EnemyMovement").set_physics_process(false)
	enemy.died.connect(func(): deaths += 1)
	enemy.damaged.connect(func(health: int): damage_events.append(health))
	return enemy
func bullets(arena: Node) -> Array:
	return arena.get_children().filter(func(child): return child is Projectile)
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
	player.set_physics_process(false)
	var weapon = player.get_node("SnotAttack")
	var enemy = spawn_enemy(arena, Vector2(180, 6))
	await frames(3)
	player.shoot()
	player.shoot()
	check(bullets(arena).size() == 1, "Fire rate must reject duplicate shots in the same instant")
	await frames(22)
	check(is_instance_valid(enemy) and enemy.health == 1, "First normal bullet must leave enemy at one health")
	check(damage_events == [1], "One projectile must damage only once")
	player.shoot()
	await frames(22)
	check(not is_instance_valid(enemy) and deaths == 1, "Second normal bullet must kill enemy exactly once")
	# Test the real collectible callback, rather than granting damage directly.
	var flower = load("res://scenes/cosmos_flower.tscn").instantiate()
	flower.position = Vector2.ZERO
	arena.add_child(flower)
	await frames(5)
	check(not is_instance_valid(flower), "Flower should collect when touching the player")
	check(weapon.damage_multiplier == 2.0, "Power-up must double weapon damage")
	enemy = spawn_enemy(arena, Vector2(180, 6))
	await frames(3)
	player.shoot()
	check(bullets(arena).size() == 1 and bullets(arena)[0].damage == 2, "Powered bullet must carry two damage")
	await frames(22)
	check(not is_instance_valid(enemy) and deaths == 2, "Powered shot must kill a fresh enemy in one hit")
	# A very thin wall must absorb a shot before an enemy behind it.
	var wall := StaticBody2D.new()
	wall.position = Vector2(80, 6)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2, 100)
	collision.shape = shape
	wall.add_child(collision)
	arena.add_child(wall)
	enemy = spawn_enemy(arena, Vector2(180, 6))
	await frames(3)
	player.shoot()
	await frames(22)
	check(enemy.health == 2, "Bullets must not pass through thin walls")
	check(bullets(arena).is_empty(), "Wall impact must consume the bullet")
	wall.free()
	enemy.free()
	player.is_teleporting = true
	player.shoot()
	check(bullets(arena).is_empty(), "Player must not shoot during door teleport")
	player.is_teleporting = false
	player.facing_direction = Vector2.LEFT
	player.shoot()
	await frames(85)
	check(bullets(arena).is_empty(), "Missed shots must expire")
	check(deaths == 2, "Deaths should be counted only once per enemy")
	arena.queue_free()
	await process_frame
	print("Snot combat checks: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)

