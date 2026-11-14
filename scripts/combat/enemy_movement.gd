extends Node
## Movement component for a human enemy CharacterBody2D.
enum State { CHASING, WINDUP, CHARGING, RECOVERING }

@export_category("Chase")
@export var normal_speed: float = 200.0
@export var stop_distance: float = 70.0
@export var detection_range: float = 300.0
@export var disengage_range: float = 360.0
@export var separation_distance: float = 130.0
@export var separation_strength: float = 0.8
@export_category("Charge")
@export var charge_speed: float = 420.0
@export var charge_range: float = 260.0
@export var charge_windup: float = 0.45
@export var charge_duration: float = 0.65
@export var recovery_duration: float = 0.6
@export var charge_cooldown: float = 2.5
@export_category("Teleport near player")
@export var teleport_attempts: int = 60
@export var teleport_cooldown: float = 5.0
@export var teleport_trigger_distance: float = 240.0
@export var teleport_min_distance: float = 100.0
@export var teleport_max_distance: float = 150.0
@export var teleport_min_displacement: float = 80.0
@export var hit_recovery_duration: float = 1.2

var player: Node2D
var enemy: CharacterBody2D
var state: State = State.CHASING
var _state_time: float = 0.0
var _charge_timer: float = 0.0
var _teleport_timer: float = 0.0
var _teleport_retry_timer: float = 0.0
var _charge_direction := Vector2.ZERO
var _sprite: AnimatedSprite2D
var _collision: CollisionShape2D
var _slash_playing: bool = false
var _engaged: bool = false


func _ready() -> void:
	enemy = get_parent() as CharacterBody2D
	if enemy == null:
		push_error("EnemyMovement requires a CharacterBody2D parent.")
		set_physics_process(false)
		return
	_sprite = enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite != null and _sprite.sprite_frames != null:
		_sprite.sprite_frames = _sprite.sprite_frames.duplicate() as SpriteFrames
		for animation_name in [&"slash", &"teleport"]:
			if _sprite.sprite_frames.has_animation(animation_name):
				_sprite.sprite_frames.set_animation_loop(animation_name, false)
		_sprite.animation_finished.connect(_on_animation_finished)
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
	_teleport_timer = maxf(_teleport_timer - delta, 0.0)
	_teleport_retry_timer = maxf(_teleport_retry_timer - delta, 0.0)
	var offset := player.global_position - enemy.global_position
	var visible_player := _has_clear_path(enemy.global_position, player.global_position)
	if _engaged:
		_engaged = offset.length() <= maxf(disengage_range, detection_range) and visible_player
	else:
		_engaged = offset.length() <= detection_range and visible_player
	if not _engaged:
		state = State.CHASING
		_state_time = 0.0
		_slash_playing = false
		_update_sprite()
		return
	if state in [State.CHASING, State.CHARGING] and _teleport_timer <= 0.0 and _teleport_retry_timer <= 0.0:
		if offset.length() <= teleport_trigger_distance and _has_clear_path(enemy.global_position, player.global_position):
			var minimum := maxf(teleport_min_distance, 1.0)
			if _teleport_to_clear_spot(minimum, maxf(teleport_max_distance, minimum), teleport_attempts):
				_teleport_timer = maxf(teleport_cooldown, 0.0)
				offset = player.global_position - enemy.global_position
				_charge_direction = offset.normalized()
				state = State.CHARGING
				_state_time = maxf(charge_duration, 0.0)
				_play_slash()
				AudioManager.play_sfx(&"knife_slash", enemy.global_position)
			else:
				# Retry later if the room is too crowded; keep chasing meanwhile.
				_teleport_retry_timer = 0.5
	match state:
		State.CHASING:
			# Stopping distance only pauses the chase; it must never block attacking.
			if offset.length() <= charge_range and not offset.is_zero_approx() and _charge_timer <= 0.0 and _has_clear_path(enemy.global_position, player.global_position):
				# Lock aim before the warning so the player can dodge.
				_charge_direction = offset.normalized()
				state = State.WINDUP
				_state_time = maxf(charge_windup, 0.0)
			elif offset.length() > stop_distance:
				enemy.velocity = (offset.normalized() + _separation_push() * separation_strength).normalized() * normal_speed
		State.WINDUP:
			if _state_time <= 0.0:
				state = State.CHARGING
				_state_time = maxf(charge_duration, 0.0)
				_play_slash()
				AudioManager.play_sfx(&"knife_slash", enemy.global_position)
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
	# Keep the hit callback without triggering an extra teleport.
	# Always give breathing room, after a successful attack.
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
		if _near_other_enemy(destination):
			continue
		if destination.distance_to(enemy.global_position) < teleport_min_displacement:
			continue
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
		_play_teleport_effect()
		enemy.global_position = destination
		enemy.reset_physics_interpolation()
		_play_teleport_effect(true)
		AudioManager.play_sfx(&"enemy_teleport", destination)
		return true
	return false


func _separation_push() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == enemy or not other is Node2D or other.is_queued_for_deletion():
			continue
		var away := enemy.global_position - (other as Node2D).global_position
		var distance := away.length()
		if distance > 0.01 and distance < separation_distance:
			push += away / distance * (1.0 - distance / separation_distance)
	return push.limit_length()


func _near_other_enemy(destination: Vector2) -> bool:
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != enemy and other is Node2D and not other.is_queued_for_deletion():
			if destination.distance_to((other as Node2D).global_position) < separation_distance:
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
	if _slash_playing:
		return
	if enemy.velocity.is_zero_approx():
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("idle"):
			_sprite.play("idle")
		else:
			_sprite.pause()
	elif _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("walk"):
		_sprite.play("walk")

func _play_slash() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation("slash"):
		return
	_slash_playing = true
	if absf(_charge_direction.x) > 0.01:
		_sprite.flip_h = _charge_direction.x < 0.0
	_sprite.stop()
	_sprite.play("slash", 1.0, false)


func _on_animation_finished() -> void:
	if _sprite.animation == &"slash":
		_slash_playing = false
		_update_sprite()


func _play_teleport_effect(reverse: bool = false) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation("teleport"):
		return
	# Animate departure/arrival independently so the enemy can charge immediately.
	var effect := AnimatedSprite2D.new()
	effect.name = "TeleportArrivalEffect" if reverse else "TeleportEffect"
	effect.sprite_frames = _sprite.sprite_frames
	effect.centered = _sprite.centered
	effect.offset = _sprite.offset
	effect.flip_h = _sprite.flip_h
	effect.flip_v = _sprite.flip_v
	effect.z_index = enemy.z_index + _sprite.z_index
	enemy.get_parent().add_child(effect)
	effect.global_transform = _sprite.global_transform
	effect.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	if reverse:
		effect.play("teleport", -1.0, true)
	else:
		effect.play("teleport", 1.0, false)
