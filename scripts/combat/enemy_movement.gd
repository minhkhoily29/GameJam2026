extends Node
## Movement component for a human enemy CharacterBody2D.
enum State { CHASING, WINDUP, CHARGING, RECOVERING, TELEPORT_WARNING }

const CHASE_CELL_SIZE := 32.0
const CHASE_PATH_PADDING := 160.0
const CHASE_REPATH_INTERVAL := 0.6

@export_category("Chase")
@export var normal_speed: float = 270.0
@export var stop_distance: float = 70.0
@export var detection_range: float = 520.0
@export var disengage_range: float = 650.0
@export var separation_distance: float = 130.0
@export var separation_strength: float = 0.8
@export var acceleration: float = 1200.0
@export var deceleration: float = 1600.0
@export_category("Charge")
@export var charge_speed: float = 540.0
@export var charge_range: float = 380.0
@export var charge_windup: float = 0.45
@export var charge_duration: float = 0.8
@export var recovery_duration: float = 0.6
@export var charge_cooldown: float = 2.5
@export_category("Teleport near player")
@export var teleport_attempts: int = 60
@export var teleport_cooldown: float = 3.0
@export var teleport_warning_duration: float = 0.55
@export var teleport_min_distance: float = 170.0
@export var teleport_max_distance: float = 230.0
@export var teleport_min_displacement: float = 80.0

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
var _teleport_destination := Vector2.ZERO
var _landing_marker: Node2D
var _attack_warning: Label
var _chase_path := PackedVector2Array()
var _chase_goal := Vector2.ZERO
var _repath_time: float = 0.0


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
	_attack_warning = Label.new()
	_attack_warning.name = "AttackWarning"
	_attack_warning.text = "!"
	_attack_warning.position = Vector2(-18, -111)
	_attack_warning.size = Vector2(36, 48)
	_attack_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attack_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_warning.z_index = 9
	_attack_warning.add_theme_font_size_override("font_size", 42)
	_attack_warning.add_theme_color_override("font_color", Color(1.0, 0.79, 0.15))
	_attack_warning.add_theme_color_override("font_outline_color", Color(0.14, 0.05, 0.02))
	_attack_warning.add_theme_constant_override("outline_size", 9)
	_attack_warning.hide()
	enemy.add_child.call_deferred(_attack_warning)
	_teleport_timer = maxf(teleport_cooldown, 0.0)


func _physics_process(delta: float) -> void:
	_teleport_timer = maxf(_teleport_timer - delta, 0.0)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.get("is_dead") == true:
		_clear_landing_marker()
		enemy.velocity = Vector2.ZERO
		state = State.CHASING
		_slash_playing = false
		_update_sprite()
		return
	_charge_timer = maxf(_charge_timer - delta, 0.0)
	_state_time = maxf(_state_time - delta, 0.0)
	_repath_time = maxf(_repath_time - delta, 0.0)
	var desired_velocity := Vector2.ZERO
	_teleport_retry_timer = maxf(_teleport_retry_timer - delta, 0.0)
	var offset := player.global_position - enemy.global_position
	var visible_player := _has_clear_path(enemy.global_position, player.global_position)
	if _engaged:
		_engaged = offset.length() <= maxf(disengage_range, detection_range)
	else:
		_engaged = offset.length() <= detection_range and (visible_player or _player_in_spawn_section())
	if state != State.TELEPORT_WARNING:
		_try_warned_teleport()
	if not _engaged and state != State.TELEPORT_WARNING:
		_chase_path.clear()
		_clear_landing_marker()
		state = State.CHASING
		_state_time = 0.0
		_slash_playing = false
		_move_smoothly(Vector2.ZERO, delta)
		_update_sprite()
		return
	match state:
		State.TELEPORT_WARNING:
			if _state_time <= 0.0:
				_finish_warned_teleport()
				if state == State.CHARGING:
					desired_velocity = _charge_direction * charge_speed
		State.CHASING:
			# Stopping distance only pauses the chase; it must never block attacking.
			if offset.length() <= charge_range and not offset.is_zero_approx() and _charge_timer <= 0.0 and visible_player:
				# Lock aim before the warning so the player can dodge.
				_charge_direction = offset.normalized()
				state = State.WINDUP
				_state_time = maxf(charge_windup, 0.0)
			else:
				desired_velocity = _chase_velocity(offset)
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
				desired_velocity = _charge_direction * charge_speed
		State.RECOVERING:
			if _state_time <= 0.0:
				state = State.CHASING
	_move_smoothly(desired_velocity, delta)
	for index in range(enemy.get_slide_collision_count()):
		var body := enemy.get_slide_collision(index).get_collider() as Node2D
		if body != null and body.is_in_group("player") and body.has_method("receive_enemy_hit"):
			if body.receive_enemy_hit(enemy.global_position, enemy):
				break
	if state == State.CHARGING and enemy.get_slide_collision_count() > 0:
		_begin_recovery()
	_update_sprite()


func _move_smoothly(target_velocity: Vector2, delta: float) -> void:
	if state == State.CHARGING:
		enemy.velocity = target_velocity
	else:
		var rate := deceleration if target_velocity.length_squared() < enemy.velocity.length_squared() else acceleration
		enemy.velocity = enemy.velocity.move_toward(target_velocity, maxf(rate, 0.0) * delta)
	# Spawn areas are not invisible movement barriers. Physical walls and closed
	# doors constrain pursuit, including when the player steps into a passage.
	enemy.move_and_slide()


func _player_in_spawn_section() -> bool:
	var section = enemy.get_meta("spawn_section", null) if enemy.has_meta("spawn_section") else null
	if not is_instance_valid(section):
		return false
	var region := section.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	return region != null and Geometry2D.is_point_in_polygon(region.to_local(player.global_position), region.polygon)


func _chase_velocity(offset: Vector2) -> Vector2:
	if _can_walk_to(player.global_position):
		_chase_path.clear()
		_repath_time = 0.0
		if offset.length() <= stop_distance:
			return Vector2.ZERO
		var direction := offset.normalized()
		var steered := (direction + _separation_push() * separation_strength).normalized()
		if not _can_walk_to(enemy.global_position + steered * 48.0):
			steered = direction
		var speed := normal_speed * clampf((offset.length() - stop_distance) / 90.0, 0.15, 1.0)
		return steered * speed

	while not _chase_path.is_empty() and enemy.global_position.distance_to(_chase_path[0]) < 10.0:
		_chase_path.remove_at(0)
	var blocked := not _chase_path.is_empty() and not _can_walk_to(_chase_path[0])
	if _repath_time <= 0.0 and (_chase_path.is_empty() or blocked or _chase_goal.distance_to(player.global_position) > CHASE_CELL_SIZE):
		_repath_time = CHASE_REPATH_INTERVAL
		_chase_goal = player.global_position
		_chase_path = _find_chase_path(_chase_goal)
	if _chase_path.is_empty() or not _can_walk_to(_chase_path[0]):
		return Vector2.ZERO
	return enemy.global_position.direction_to(_chase_path[0]) * normal_speed


func _movement_query() -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _collision.shape
	query.transform = _collision.global_transform
	# Plan around solid map geometry. Body collisions and separation handle crowds.
	query.collision_mask = enemy.collision_mask & ~enemy.collision_layer
	query.exclude = [enemy.get_rid()]
	if player is CollisionObject2D:
		query.exclude = [enemy.get_rid(), (player as CollisionObject2D).get_rid()]
	query.margin = 2.0
	return query


func _can_walk_to(destination: Vector2) -> bool:
	if _collision == null or _collision.shape == null:
		return _has_clear_path(enemy.global_position, destination)
	var query := _movement_query()
	query.motion = destination - enemy.global_position
	var fractions := enemy.get_world_2d().direct_space_state.cast_motion(query)
	return fractions[0] >= 1.0


func _find_chase_path(destination: Vector2) -> PackedVector2Array:
	if _collision == null or _collision.shape == null:
		return PackedVector2Array()

	var bounds := Rect2(enemy.global_position, Vector2.ZERO).expand(destination).grow(CHASE_PATH_PADDING)
	var grid := AStarGrid2D.new()
	grid.offset = bounds.position
	grid.cell_size = Vector2.ONE * CHASE_CELL_SIZE
	grid.region = Rect2i(Vector2i.ZERO, Vector2i((bounds.size / CHASE_CELL_SIZE).ceil()) + Vector2i.ONE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()

	var query := _movement_query()
	var space := enemy.get_world_2d().direct_space_state
	var shape_offset := _collision.global_position - enemy.global_position
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			var cell := Vector2i(x, y)
			query.transform.origin = grid.get_point_position(cell) + shape_offset
			if not space.intersect_shape(query, 1).is_empty():
				grid.set_point_solid(cell)

	var start := _closest_chase_cell(grid, enemy.global_position, true)
	var finish := _closest_chase_cell(grid, destination, false)
	if not grid.region.has_point(start) or not grid.region.has_point(finish):
		return PackedVector2Array()
	return grid.get_point_path(start, finish, true)


func _closest_chase_cell(grid: AStarGrid2D, position: Vector2, check_route: bool) -> Vector2i:
	var center := Vector2i(((position - grid.offset) / grid.cell_size).round())
	var closest := Vector2i(-1, -1)
	var closest_distance := INF
	for y in range(center.y - 2, center.y + 3):
		for x in range(center.x - 2, center.x + 3):
			var cell := Vector2i(x, y)
			if not grid.region.has_point(cell) or grid.is_point_solid(cell):
				continue
			var point := grid.get_point_position(cell)
			var distance := position.distance_squared_to(point)
			if distance < closest_distance and (not check_route or _can_walk_to(point)):
				closest = cell
				closest_distance = distance
	return closest


func _begin_recovery() -> void:
	_clear_landing_marker()
	state = State.RECOVERING
	_state_time = maxf(recovery_duration, 0.0)
	_charge_timer = maxf(charge_cooldown, 0.0)
	enemy.velocity = Vector2.ZERO


func retreat_after_hit(target: Node2D) -> void:
	player = target
	_clear_landing_marker()
	_chase_path.clear()
	_repath_time = 0.0
	state = State.CHASING
	_state_time = 0.0
	_charge_timer = maxf(charge_cooldown, 0.0)
	enemy.velocity = Vector2.ZERO

	_try_warned_teleport()
	_update_sprite()


func _try_warned_teleport() -> void:
	# A ready teleport stays available until the player enters this enemy's room.
	if enemy.has_meta("spawn_section") and not _player_in_spawn_section():
		return
	if _teleport_timer > 0.0 or _teleport_retry_timer > 0.0:
		return
	var minimum := maxf(teleport_min_distance, 1.0)
	if not _teleport_to_clear_spot(minimum, maxf(teleport_max_distance, minimum), teleport_attempts):
		_teleport_retry_timer = 0.5
		return
	state = State.TELEPORT_WARNING
	_state_time = maxf(teleport_warning_duration, 0.05)
	enemy.velocity = Vector2.ZERO
	_slash_playing = false
	_show_landing_marker()


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
		# Check the entire body, including the collision shape's offset.
		query.transform = _collision.global_transform
		query.transform.origin += destination - enemy.global_position
		if not enemy.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		# Stay on the player's side of walls and closed doors.
		if not _has_clear_path(player.global_position, destination):
			continue
		_teleport_destination = destination
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
	# Other enemies should not hide the player from an astronaut's vision.
	var vision_mask := enemy.collision_mask & ~enemy.collision_layer
	var ray := PhysicsRayQueryParameters2D.create(origin, destination, vision_mask)
	ray.exclude = [enemy.get_rid()]
	if player is CollisionObject2D:
		ray.exclude = [enemy.get_rid(), (player as CollisionObject2D).get_rid()]
	return enemy.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _update_sprite() -> void:
	_attack_warning.visible = state == State.WINDUP or state == State.TELEPORT_WARNING
	if _sprite == null:
		return
	if absf(enemy.velocity.x) > 10.0:
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

func _show_landing_marker() -> void:
	_clear_landing_marker()
	_landing_marker = Node2D.new()
	_landing_marker.set_script(preload("res://scripts/combat/teleport_marker.gd"))
	_landing_marker.name = "TeleportLandingMarker"
	enemy.add_child(_landing_marker)
	_landing_marker.top_level = true
	_landing_marker.global_position = _teleport_destination
	_landing_marker.z_index = 8


func _clear_landing_marker() -> void:
	if is_instance_valid(_landing_marker):
		_landing_marker.queue_free()
	_landing_marker = null


func _finish_warned_teleport() -> void:
	_clear_landing_marker()
	_chase_path.clear()
	# The player or another enemy may have moved onto the advertised spot.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _collision.shape
	query.transform = _collision.global_transform
	query.transform.origin += _teleport_destination - enemy.global_position
	query.collision_mask = enemy.collision_mask
	query.exclude = [enemy.get_rid()]
	query.margin = 4.0
	var blocked := not enemy.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
	var left_room := enemy.has_meta("spawn_section") and not _player_in_spawn_section()
	var too_close := player.global_position.distance_to(_teleport_destination) < teleport_min_distance * 0.75
	if blocked or left_room or too_close or not _has_clear_path(player.global_position, _teleport_destination):
		state = State.CHASING
		_teleport_retry_timer = 0.5
		return
	_execute_teleport()
	_engaged = true
	_charge_direction = enemy.global_position.direction_to(player.global_position)
	state = State.CHARGING
	_state_time = maxf(charge_duration, 0.0)
	enemy.velocity = _charge_direction * charge_speed
	_play_slash()
	AudioManager.play_sfx(&"knife_slash", enemy.global_position)


func _execute_teleport() -> void:
	_play_teleport_effect()
	enemy.global_position = _teleport_destination
	enemy.reset_physics_interpolation()
	_play_teleport_effect(true)
	# Every completed teleport gets a cue, independent of hits and camera distance.
	AudioManager.play_sfx(&"enemy_teleport")
	_teleport_timer = maxf(teleport_cooldown, 0.0)
	_teleport_retry_timer = 0.0
