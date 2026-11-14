extends SceneTree
var failures := 0
var audio: Node
var events: Array[StringName] = []
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	audio = root.get_node("AudioManager")
	audio.sound_played.connect(func(event: StringName): events.append(event))
	for event in audio.SOUNDS:
		var stream: AudioStream = audio.SOUNDS[event][0]
		check(stream != null and stream.get_length() > 0.0, "Audio must import and have duration: %s" % event)
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var source = load("res://scenes/main.tscn").instantiate()
	var player = source.get_node("CharacterBody2D")
	source.remove_child(player)
	player.get_node("ControllerUDP").free()
	source.free()
	player.position = Vector2.ZERO
	arena.add_child(player)
	player.set_physics_process(false)
	var enemy = load("res://scenes/human_enemy.tscn").instantiate()
	enemy.position = Vector2(180, 6)
	arena.add_child(enemy)
	var movement = enemy.get_node("EnemyMovement")
	movement.set_physics_process(false)
	movement._teleport_timer = 999.0
	movement.state = movement.State.WINDUP
	movement._state_time = 0.0
	await frames(2)
	movement._physics_process(0.016)
	check(events.count(&"knife_slash") == 1, "Charge start must make one knife slash")
	check(movement._teleport_to_clear_spot(100.0, 150.0, 60), "Enemy should find a clear teleport destination")
	check(events.count(&"enemy_teleport") == 1, "Successful enemy teleport must make exactly one cue")
	await frames(2)
	player.shoot()
	player.shoot()
	check(events.count(&"snot_shoot") == 1, "Rejected rapid shot must stay silent")
	if DisplayServer.get_name() != "headless":
		check(not audio._voices.is_empty() and audio._voices[-1].playing, "Snot sound must start actual audio playback")
	await frames(22)
	check(events.count(&"snot_hit") == 1, "One actual projectile hit must make one wet impact")
	while is_instance_valid(enemy):
		player.shoot()
		await frames(22)
	check(events.count(&"enemy_death") == 1, "Enemy death must make one cue before deletion")
	var shots_before: int = events.count(&"snot_shoot")
	player.is_teleporting = true
	player.shoot()
	check(events.count(&"snot_shoot") == shots_before, "Blocked shots must be silent")
	player.is_teleporting = false
	# Walking makes footsteps; standing still does not.
	player.move_input = Vector2.LEFT
	player.set_physics_process(true)
	await frames(8)
	check(events.count(&"footstep") > 0, "Actual walking must make footsteps")
	player.move_input = Vector2.ZERO
	await frames(2)
	var steps_before: int = events.count(&"footstep")
	await frames(20)
	check(events.count(&"footstep") == steps_before, "Idle player must stay silent")
	player.set_physics_process(false)
	# Walls still stop bullets, but do not have impact sounds.
	var wall := StaticBody2D.new()
	wall.position = player.position + Vector2(80, 6)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2, 120)
	collision.shape = shape
	wall.add_child(collision)
	arena.add_child(wall)
	await frames(2)
	player.facing_direction = Vector2.RIGHT
	player.shoot()
	var events_after_shot := events.size()
	await frames(22)
	check(events.size() == events_after_shot, "Wall impacts must stay silent")
	wall.free()
	var flower = load("res://scenes/CosmosFlower.tscn").instantiate()
	flower.position = player.position
	arena.add_child(flower)
	await frames(5)
	check(events.count(&"flower_pickup") == 1 and not is_instance_valid(flower), "Pickup must make one cue and disappear")
	await player.teleport_to(player.position + Vector2(20, 0))
	check(events.count(&"door_slide") == 2, "Door travel must use slime at departure and arrival")
	check(player.receive_enemy_hit(player.position + Vector2(100, 0)), "Hit must be accepted")
	check(not player.receive_enemy_hit(player.position + Vector2(100, 0)), "Cooldown must reject a repeated hit")
	check(events.count(&"player_hit") == 1, "Only accepted nonfatal hits should sound")
	player._enemy_hit_timer = 0.0
	player.health = 1
	player.receive_enemy_hit(player.position + Vector2(100, 0))
	player._die()
	check(events.count(&"player_death") == 1, "Death must make slime exactly once")
	# The map owns the lifetime of the ambience loop.
	var map := Node2D.new()
	var sections := Node2D.new()
	sections.name = "Enemies"
	map.add_child(sections)
	var section := Node.new()
	section.add_user_signal("section_cleared")
	sections.add_child(section)
	var soundscape := Node.new()
	soundscape.set_script(load("res://scripts/audio/ship_soundscape.gd"))
	map.add_child(soundscape)
	arena.add_child(map)
	section.emit_signal("section_cleared")
	check(audio._ambience_users == 1, "Map must start ship ambience")
	map.queue_free()
	await process_frame
	check(audio._ambience_users == 0, "Closing the map must release ambience")
	arena.queue_free()
	await process_frame
	# Let the audio thread release stopped playback before the test exits.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.15).timeout
	print("Audio event checks: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
