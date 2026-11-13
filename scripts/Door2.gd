extends Area2D

@export var locked: bool = false

@onready var side_c: Marker2D = $SideC
@onready var side_d: Marker2D = $SideD


func _ready() -> void:
	add_to_group("doors")


func try_teleport(player: CharacterBody2D) -> bool:
	if locked or not overlaps_body(player):
		return false

	var distance_c := player.global_position.distance_squared_to(
		side_c.global_position
	)
	var distance_d := player.global_position.distance_squared_to(
		side_d.global_position
	)

	if distance_c < distance_d:
		player.teleport_to(side_d.global_position)
	else:
		player.teleport_to(side_c.global_position)

	return true
