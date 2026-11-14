extends CharacterBody2D

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

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var snot_attack: Weapon = get_node_or_null("SnotAttack") as Weapon
@onready var _base_move_speed: float = move_speed


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var aim := global_position.direction_to(get_global_mouse_position())
		if not aim.is_zero_approx():
			facing_direction = aim
		shoot()
	elif event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		shoot()


# Called by ControllerUDP when a controller packet arrives.
func update_aim(raw_x: int, raw_y: int) -> void:
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
	_enemy_hit_timer = maxf(_enemy_hit_timer - delta, 0.0)
	_hit_flash_time = maxf(_hit_flash_time - delta, 0.0)
	sprite.self_modulate = Color(1.0, 0.25, 0.25) if _hit_flash_time > 0.0 else Color.WHITE
	if is_teleporting:
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
	var actual_velocity := get_real_velocity()

	if actual_velocity.length() > 1.0:
		sprite.play(walk_animation)
	else:
		sprite.play("idle")


func receive_enemy_hit(source_position: Vector2, attacker: Node2D = null) -> bool:
	if is_teleporting or _enemy_hit_timer > 0.0:
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
	hit_by_enemy.emit(source_position)
	if is_instance_valid(attacker) and attacker.has_method("on_player_hit"):
		attacker.on_player_hit(self)
	return true
		
func try_door_teleport() -> void:
	if is_teleporting:
		return
	for door in get_tree().get_nodes_in_group("doors"):
		if door.try_teleport(self):
			return
var is_teleporting: bool = false


func teleport_to(destination: Vector2) -> void:
	if is_teleporting:
		return

	if not sprite.sprite_frames.has_animation("teleport"):
		push_error("Missing animation named 'teleport'.")
		return

	if sprite.sprite_frames.get_animation_loop("teleport"):
		push_error("Turn off Loop for the teleport animation.")
		return

	is_teleporting = true
	velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	_knockback_time = 0.0

	# Play from the first frame.
	sprite.stop()
	sprite.play("teleport", 1.0, false)
	await sprite.animation_finished

	global_position = destination
	$Camera2D.reset_smoothing()

	# Play backward from the last frame.
	sprite.stop()
	sprite.play("teleport", -1.0, true)
	await sprite.animation_finished

	sprite.play("idle")
	is_teleporting = false
	
func shoot() -> void:
	if is_teleporting:
		return
	if snot_attack != null:
		snot_attack.fire(facing_direction)


func apply_cosmos_buff(damage_up: float = 2.0, speed_up: float = 2.0) -> void:
	if snot_attack != null:
		snot_attack.damage_multiplier = maxf(snot_attack.damage_multiplier, maxf(damage_up, 1.0))
	move_speed = maxf(move_speed, _base_move_speed * maxf(speed_up, 1.0))
