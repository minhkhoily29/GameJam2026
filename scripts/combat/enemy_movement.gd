extends Node
## Movement component for a human enemy CharacterBody2D.
enum State { CHASING, WINDUP, CHARGING, RECOVERING }

@export_category("Chase")
@export var normal_speed: float = 120.0
@export var stop_distance: float = 70.0
@export_category("Charge")
@export var charge_speed: float = 420.0
@export var charge_range: float = 360.0
@export var charge_windup: float = 0.45
@export var charge_duration: float = 0.65
@export var recovery_duration: float = 0.6
@export var charge_cooldown: float = 2.5
@export_category("Retreat after hitting player")
@export var teleport_attempts: int = 60
@export var retreat_min_distance: float = 240.0
@export var retreat_max_distance: float = 400.0
@export var hit_recovery_duration: float = 1.2

var player: Node2D
var enemy: CharacterBody2D
var state: State = State.CHASING
var _state_time: float = 0.0
var _charge_timer: float = 0.0
var _charge_direction := Vector2.ZERO
var _sprite: AnimatedSprite2D
var _collision: CollisionShape2D


func _ready() -> void:
	enemy = get_parent() as CharacterBody2D
	if enemy == null:
		push_error("EnemyMovement requires a CharacterBody2D parent.")
		set_physics_process(false)
		return
	_sprite = enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_collision = enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_charge_timer = maxf(charge_cooldown, 0.0)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			enemy.velocity = Vector2.ZERO
			state = State.CHASING
			_update_sprite()
			return
	_charge_timer = maxf(_charge_timer - delta, 0.0)
	_state_time = maxf(_state_time - delta, 0.0)
	enemy.velocity = Vector2.ZERO
	var offset := player.global_position - enemy.global_position
	match state:
		State.CHASING:
			# Stopping distance only pauses the chase; it must never block attacking.
			if offset.length() <= charge_range and not offset.is_zero_approx() and _charge_timer <= 0.0 and _has_clear_path(enemy.global_position, player.global_position):
				# Lock aim before the warning so the player can dodge.
				_charge_direction = offset.normalized()
				state = State.WINDUP
				_state_time = maxf(charge_windup, 0.0)
			elif offset.length() > stop_distance:
				enemy.velocity = offset.normalized() * normal_speed
		State.WINDUP:
			if _state_time <= 0.0:
				state = State.CHARGING
				_state_time = maxf(charge_duration, 0.0)
		State.CHARGING:
			if _state_time <= 0.0:
				_begin_recovery()
			else:
				enemy.velocity = _charge_direction * charge_speed
		State.RECOVERING:
			if _state_time <= 0.0:
				state = State.CHASING
	var section: Node = enemy.get_meta("spawn_section") if enemy.has_meta("spawn_section") else null
	if is_instance_valid(section) and _collision != null:
		if not section.contains_body_position(enemy.global_position + enemy.velocity * delta, _collision):
			enemy.velocity = Vector2.ZERO
			if state == State.CHARGING:
				_begin_recovery()
	enemy.move_and_slide()
	for index in range(enemy.get_slide_collision_count()):
		var body := enemy.get_slide_collision(index).get_collider() as Node2D
		if body != null and body.is_in_group("player") and body.has_method("receive_enemy_hit"):
			if body.receive_enemy_hit(enemy.global_position, enemy):
				break
	if state == State.CHARGING and enemy.get_slide_collision_count() > 0:
		_begin_recovery()
	_update_sprite()


func _begin_recovery() -> void:
	state = State.RECOVERING
	_state_time = maxf(recovery_duration, 0.0)
	_charge_timer = maxf(charge_cooldown, 0.0)
	enemy.velocity = Vector2.ZERO


func retreat_after_hit(target: Node2D) -> void:
	player = target
	var minimum := maxf(retreat_min_distance, stop_distance + 1.0)
	_teleport_to_clear_spot(minimum, maxf(retreat_max_distance, minimum), teleport_attempts)
	# Always give breathing room, including when a cramped room has no safe spot.
	_begin_recovery()
	_state_time = maxf(hit_recovery_duration, recovery_duration)
	_update_sprite()


func _teleport_to_clear_spot(minimum: float, maximum: float, attempts: int) -> bool:
	if not is_instance_valid(player) or _collision == null or _collision.shape == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _collision.shape
	query.collision_mask = enemy.collision_mask
	query.exclude = [enemy.get_rid()]
	query.margin = 4.0
	# Random placement first, then cover the ring systematically. Small rooms can
	# have only a narrow strip of valid retreat space that random samples miss.
	var random_attempts := maxi(attempts, 0)
	for attempt in range(random_attempts + 320):
		var angle: float
		var radius: float
		if attempt < random_attempts:
			angle = randf() * TAU
			radius = randf_range(minimum, maximum)
		else:
			var sample_index := attempt - random_attempts
			angle = float(sample_index % 64) * TAU / 64.0
			radius = lerpf(minimum, maximum, floorf(sample_index / 64.0) / 4.0)
		var destination := player.global_position + Vector2.RIGHT.rotated(angle) * radius
		var section: Node = enemy.get_meta("spawn_section") if enemy.has_meta("spawn_section") else null
		if is_instance_valid(section) and not section.contains_body_position(destination, _collision):
			continue
		# Check the entire body, including the collision shape's offset.
		query.transform = _collision.global_transform
		query.transform.origin += destination - enemy.global_position
		if not enemy.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		# Stay on the player's side of walls and closed doors.
		if not _has_clear_path(player.global_position, destination):
			continue
		enemy.global_position = destination
		enemy.reset_physics_interpolation()
		return true
	return false


func _has_clear_path(origin: Vector2, destination: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(origin, destination, enemy.collision_mask)
	ray.exclude = [enemy.get_rid()]
	if player is CollisionObject2D:
		ray.exclude = [enemy.get_rid(), (player as CollisionObject2D).get_rid()]
	return enemy.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _update_sprite() -> void:
	if _sprite == null:
		return
	if absf(enemy.velocity.x) > 0.01:
		_sprite.flip_h = enemy.velocity.x < 0.0
	if enemy.velocity.is_zero_approx():
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("idle"):
			_sprite.play("idle")
		else:
			_sprite.pause()
	elif _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("walk"):
		_sprite.play("walk")
