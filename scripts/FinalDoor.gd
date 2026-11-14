extends Area2D

signal opened

@export var explosion_animation: StringName = &"default"
@export var final_frame_hold: float = 1.0
# Assign an existing wall's door-blocking shape here if it is outside this node.
@export var blocker_shape: CollisionShape2D

var opening: bool = false
@onready var sprite: AnimatedSprite2D = $ExplodeDoor


func _ready() -> void:
	add_to_group("final_doors")
	collision_layer = 0
	collision_mask = 1
	sprite.stop()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(explosion_animation):
		sprite.sprite_frames.set_animation_loop(explosion_animation, false)
		sprite.animation = explosion_animation
		sprite.frame = 0


func try_open(player: CharacterBody2D) -> bool:
	if not overlaps_body(player):
		return false
	if opening:
		return true
	if player.is_dead or player.is_teleporting:
		return false
	if not player.has_final_key:
		AudioManager.play_locked_door()
		print("Find the key before opening this door.")
		return true
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(explosion_animation):
		push_error("Final door is missing its explosion animation.")
		return true
	if sprite.sprite_frames.get_frame_count(explosion_animation) == 0:
		push_error("Final door explosion has no frames.")
		return true
	opening = true
	_explode()
	return true


func _explode() -> void:
	sprite.sprite_frames.set_animation_loop(explosion_animation, false)
	sprite.speed_scale = 1.0
	sprite.play(explosion_animation, 1.0, false)
	await sprite.animation_finished
	# Non-looping playback leaves the sprite on its final frame.
	if final_frame_hold > 0.0:
		await get_tree().create_timer(final_frame_hold, false).timeout
	if is_instance_valid(blocker_shape):
		blocker_shape.set_deferred("disabled", true)
	opened.emit()
	queue_free()

