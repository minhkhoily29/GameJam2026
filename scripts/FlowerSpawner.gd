extends Node2D

@export var flower_scene: PackedScene


func _ready() -> void:
	if flower_scene == null:
		push_error("Assign Flower Scene on FlowerSpawner.")
		return

	for point in get_children():
		if point is Marker2D:
			var flower = flower_scene.instantiate()
			flower.position = point.position
			add_child(flower)
