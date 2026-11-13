extends Area2D

@export var locked: bool = false

@onready var side_a: Marker2D = $SideA
@onready var side_b: Marker2D = $SideB


func _ready() -> void:
	add_to_group("doors")


func try_teleport(player: CharacterBody2D) -> bool:
	if locked or not overlaps_body(player):
		return false

	var distance_a := player.global_position.distance_squared_to(
		side_a.global_position
	)
	var distance_b := player.global_position.distance_squared_to(
		side_b.global_position
	)

	if distance_a < distance_b:
		player.teleport_to(side_b.global_position)
	else:
		player.teleport_to(side_a.global_position)

	return true
