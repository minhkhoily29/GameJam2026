extends CharacterBody2D

@export var max_health: int = 3
var health: int = 3
var is_dead: bool = false
var has_final_key: bool = false
signal final_key_collected
signal health_changed(current_health: int, maximum_health: int)
signal died

@export var move_speed: float = 250.0
@export var deadzone: float = 0.2
@export var invert_y: bool = false
@export var walk_animation: StringName = &"default"
@export_category("Enemy knockback")
@export var knockback_speed: float = 460.0
@export var knockback_duration: float = 0.22
@export var knockback_deceleration: float = 1500.0
@export var enemy_hit_cooldown: float = 0.65
@export var hit_flash_duration: float = 0.2

signal hit_by_enemy(source_position: Vector2)

var facing_direction := Vector2.RIGHT
var move_input := Vector2.ZERO
var _knockback_velocity := Vector2.ZERO
var _knockback_time: float = 0.0
var _enemy_hit_timer: float = 0.0
var _hit_flash_time: float = 0.0
var _footstep_time: float = 0.0
var _cosmos_time_left: float = 0.0
var _pre_cosmos_speed: float = 0.0
var _pre_cosmos_damage: float = 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var snot_attack: Weapon = get_node_or_null("SnotAttack") as Weapon


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	print("Player health: ", health, "/", max_health)


func heal(amount: int = 1) -> void:
	if is_dead or amount <= 0:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	print("Player health: ", health, "/", max_health)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play_sfx(&"player_death")
	velocity = Vector2.ZERO
	move_input = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	set_physics_process(false)
	sprite.self_modulate = Color.WHITE
	sprite.stop()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("die"):
		# Play once and hold the final frame, even if Loop is enabled in the editor.
		sprite.sprite_frames.set_animation_loop("die", false)
		sprite.play("die", 1.0, false)
	died.emit()
	print("Game over: player has no health remaining.")


# Called by ControllerUDP when a controller packet arrives.
func update_aim(raw_x: int, raw_y: int) -> void:
	if is_dead:
		return
	var stick := Vector2(
		(raw_x - 2048) / 2048.0,
		(raw_y - 2048) / 2048.0
	)

	if invert_y:
		stick.y = -stick.y

	var strength := minf(stick.length(), 1.0)

	if strength <= deadzone:
		move_input = Vector2.ZERO
		return

	facing_direction = stick.normalized()

	# Smoothly scale movement outside the deadzone.
	var adjusted_strength := (strength - deadzone) / (1.0 - deadzone)
	move_input = facing_direction * adjusted_strength


func _physics_process(delta: float) -> void:
	_footstep_time = maxf(_footstep_time - delta, 0.0)
	_update_cosmos_buff(delta)
	_enemy_hit_timer = maxf(_enemy_hit_timer - delta, 0.0)
	_hit_flash_time = maxf(_hit_flash_time - delta, 0.0)
	sprite.self_modulate = Color(1.0, 0.25, 0.25) if _hit_flash_time > 0.0 else Color.WHITE
	if is_dead or is_teleporting:
		velocity = Vector2.ZERO
		return
	if _knockback_time > 0.0:
		velocity = _knockback_velocity
		_knockback_time = maxf(_knockback_time - delta, 0.0)
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_deceleration * delta)
	else:
		velocity = move_input * move_speed
	if move_input.x > 0.05:
		sprite.flip_h = false  # Face right
	elif move_input.x < -0.05:
		sprite.flip_h = true   # Face left
	move_and_slide()
	for index in range(get_slide_collision_count()):
		var body := get_slide_collision(index).get_collider() as Node2D
		if body != null and body.is_in_group("enemies"):
			receive_enemy_hit(body.global_position, body)
	if is_dead:
		return
	var actual_velocity := get_real_velocity()

	if actual_velocity.length() > 1.0:
		sprite.play(walk_animation)
		if _knockback_time <= 0.0 and _footstep_time <= 0.0:
			AudioManager.play_sfx(&"footstep")
			_footstep_time = clampf(85.0 / actual_velocity.length(), 0.23, 0.5)
	else:
		sprite.play("idle")
		_footstep_time = 0.0


func receive_enemy_hit(source_position: Vector2, attacker: Node2D = null) -> bool:
	if is_dead or is_teleporting or _enemy_hit_timer > 0.0:
		return false
	var direction := source_position.direction_to(global_position)
	if direction.is_zero_approx():
		direction = -facing_direction.normalized()
		if direction.is_zero_approx():
			direction = Vector2.LEFT
	_knockback_velocity = direction * knockback_speed
	_knockback_time = maxf(knockback_duration, 0.0)
	_enemy_hit_timer = maxf(enemy_hit_cooldown, knockback_duration)
	_hit_flash_time = maxf(hit_flash_duration, 0.0)
	if _hit_flash_time > 0.0:
		sprite.self_modulate = Color(1.0, 0.25, 0.25)
	health = maxi(health - 1, 0)
	if health > 0:
		AudioManager.play_sfx(&"player_hit")
	health_changed.emit(health, max_health)
	print("Player health: ", health, "/", max_health)
	hit_by_enemy.emit(source_position)
	if is_instance_valid(attacker) and attacker.has_method("on_player_hit"):
		attacker.on_player_hit(self)
	if health == 0:
		_die()
	return true
		
func collect_final_key() -> bool:
	if is_dead:
		return false
	has_final_key = true
	final_key_collected.emit()
	print("Key collected! Tilt near the final door to open it.")
	return true


func try_door_teleport() -> void:
	if is_dead or is_teleporting:
		return
	for final_door in get_tree().get_nodes_in_group("final_doors"):
		if final_door.try_open(self):
			return
	for door in get_tree().get_nodes_in_group("doors"):
		if door.try_teleport(self):
			return
var is_teleporting: bool = false


func teleport_to(destination: Vector2) -> void:
	if is_dead or is_teleporting:
		return

	if not sprite.sprite_frames.has_animation("teleport"):
		push_error("Missing animation named 'teleport'.")
		return

	if sprite.sprite_frames.get_animation_loop("teleport"):
		push_error("Turn off Loop for the teleport animation.")
		return

	is_teleporting = true
	AudioManager.play_sfx(&"door_slide")
	velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	_knockback_time = 0.0

	# Play from the first frame.
	sprite.stop()
	sprite.play("teleport", 1.0, false)
	await sprite.animation_finished

	global_position = destination
	AudioManager.play_sfx(&"door_slide")
	$Camera2D.reset_smoothing()

	# Play backward from the last frame.
	sprite.stop()
	sprite.play("teleport", -1.0, true)
	await sprite.animation_finished

	sprite.play("idle")
	is_teleporting = false
	
func shoot() -> void:
	if is_dead or is_teleporting or not is_instance_valid(snot_attack):
		return

	var nearest_enemy: Enemy = null
	var nearest_distance_squared: float = INF

	for node in get_tree().get_nodes_in_group("enemies"):
		var candidate := node as Enemy
		if not is_instance_valid(candidate):
			continue
		if candidate.is_queued_for_deletion() or candidate.health <= 0:
			continue
		# Other rooms pause their enemies; don't aim at those inactive enemies.
		if not candidate.can_process():
			continue

		var distance_squared := global_position.distance_squared_to(candidate.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_enemy = candidate

	var aim_direction := facing_direction
	if nearest_enemy != null:
		var shot_origin := snot_attack.global_position
		if is_instance_valid(snot_attack.muzzle):
			shot_origin = snot_attack.muzzle.global_position
		var target_direction := shot_origin.direction_to(nearest_enemy.global_position)
		if not target_direction.is_zero_approx():
			aim_direction = target_direction

	if snot_attack.fire(aim_direction):
		facing_direction = aim_direction
		if absf(aim_direction.x) > 0.05:
			sprite.flip_h = aim_direction.x < 0.0


# Another flower refreshes the five-second duration without stacking multipliers.
func apply_cosmos_buff(damage_up: float = 2.0, speed_up: float = 2.0) -> void:
	if is_dead:
		return
	heal(1)
	if _cosmos_time_left <= 0.0:
		_pre_cosmos_speed = move_speed
		if is_instance_valid(snot_attack):
			_pre_cosmos_damage = snot_attack.damage_multiplier

	_cosmos_time_left = 5.0
	move_speed = maxf(move_speed, _pre_cosmos_speed * maxf(speed_up, 1.0))
	if is_instance_valid(snot_attack):
		snot_attack.damage_multiplier = maxf(
			snot_attack.damage_multiplier,
			_pre_cosmos_damage * maxf(damage_up, 1.0)
		)


func _update_cosmos_buff(delta: float) -> void:
	if _cosmos_time_left <= 0.0:
		return

	_cosmos_time_left = maxf(_cosmos_time_left - delta, 0.0)
	if _cosmos_time_left <= 0.0:
		move_speed = _pre_cosmos_speed
		if is_instance_valid(snot_attack):
			snot_attack.damage_multiplier = _pre_cosmos_damage
