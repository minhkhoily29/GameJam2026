extends Node2D

var facing_direction := Vector2.RIGHT


func _ready() -> void:
	position = get_viewport_rect().size / 2.0


func update_aim(raw_x: int, raw_y: int) -> void:
	var stick := Vector2(
		(raw_x - 2048) / 2048.0,
		(raw_y - 2048) / 2048.0
	)

	if stick.length() > 0.2:
		facing_direction = stick.normalized()
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 15.0, Color.WHITE)
	draw_line(
		Vector2.ZERO,
		facing_direction * 35.0,
		Color.RED,
		4.0
	)


func shoot() -> void:
	print("Shoot! Direction: ", facing_direction)
