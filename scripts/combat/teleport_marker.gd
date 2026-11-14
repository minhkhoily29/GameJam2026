extends Node2D
var elapsed: float = 0.0
func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
func _draw() -> void:
	var pulse := (sin(elapsed * 30.0) + 1.0) * 0.5
	var radius := 30.0 + pulse * 5.0
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.22, 0.04, 0.25))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.08, 0.02, 0.01), 8.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.75, 0.1), 4.0, true)
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(direction * 13.0, direction * 42.0, Color(1.0, 0.9, 0.55), 3.0, true)
