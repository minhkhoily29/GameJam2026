extends CharacterBody2D

@export var move_speed: float = 250.0
@export var deadzone: float = 0.2
@export var invert_y: bool = false
@export var walk_animation: StringName = &"default"

var facing_direction := Vector2.RIGHT
var move_input := Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


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


func _physics_process(_delta: float) -> void:
	if is_teleporting:
		velocity = Vector2.ZERO
		return
	velocity = move_input * move_speed
	if move_input.x > 0.05:
		sprite.flip_h = false  # Face right
	elif move_input.x < -0.05:
		sprite.flip_h = true   # Face left
	move_and_slide()
	var actual_velocity := get_real_velocity()

	if actual_velocity.length() > 1.0:
		sprite.play(walk_animation)
	else:
		sprite.play("idle")
		
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
	print("Shoot! Direction: ", facing_direction)
	
func apply_cosmos_buff(
	damage_multiplier: float,
	speed_multiplier: float
) -> void:
	move_speed *= speed_multiplier
	$Weapon.damage_multiplier *= damage_multiplier

	print(
		"Flower collected! Speed: ", move_speed,
		" Damage multiplier: ", $Weapon.damage_multiplier
	)
