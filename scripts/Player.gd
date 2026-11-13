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
	velocity = move_input * move_speed
	if move_input.x > 0.05:
		sprite.flip_h = false  # Face right
	elif move_input.x < -0.05:
		sprite.flip_h = true   # Face left
	move_and_slide()

	# Animate actual movement, so pushing against a wall stops walking.
	var actual_velocity := get_real_velocity()

	if actual_velocity.length() > 1.0:
		sprite.play(walk_animation)

		# Your alien artwork faces right by default.
		if absf(actual_velocity.x) > 1.0:
			sprite.flip_h = actual_velocity.x < 0.0
	else:
		sprite.stop()
		sprite.frame = 0


func shoot() -> void:
	print("Shoot! Direction: ", facing_direction)
