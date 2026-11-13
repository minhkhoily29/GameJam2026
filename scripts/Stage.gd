extends Node2D

signal stage_cleared
signal stage_started(stage_number: int)

enum State { FIGHTING, CLEARED, IN_ROOM }

@export var enemy_scene: PackedScene
@export var starting_enemies: int = 3
@export var extra_enemies_per_stage: int = 1

@onready var enemies: Node2D = $Enemies
@onready var spawn_points: Node2D = $SpawnPoints

var state: State = State.FIGHTING
var stage_number: int = 0
var enemies_remaining: int = 0
var active_room: Node = null


func _ready() -> void:
	if enemy_scene == null or spawn_points.get_child_count() == 0:
		push_error("Assign an enemy scene and add spawn points.")
		return

	_start_next_stage()


func _start_next_stage() -> void:
	state = State.FIGHTING
	active_room = null
	stage_number += 1

	enemies_remaining = (
		starting_enemies
		+ (stage_number - 1) * extra_enemies_per_stage
	)

	var points := spawn_points.get_children()
	points.shuffle()

	for i in range(enemies_remaining):
		var enemy = enemy_scene.instantiate()
		var spawn_point = points[i % points.size()]

		enemy.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)

		enemies.add_child(enemy)
		enemy.global_position = spawn_point.global_position

	stage_started.emit(stage_number)
	print("Stage ", stage_number, ": ", enemies_remaining, " enemies")


func _on_enemy_died() -> void:
	enemies_remaining -= 1

	if enemies_remaining == 0:
		state = State.CLEARED
		stage_cleared.emit()
		print("Stage cleared. Enter a room.")


func can_enter_room() -> bool:
	return state == State.CLEARED


func enter_room(room: Node) -> void:
	if not can_enter_room():
		return

	active_room = room
	state = State.IN_ROOM
	print("Room entered. Leaving will start the next stage.")


func exit_room(room: Node) -> void:
	if state != State.IN_ROOM or room != active_room:
		return

	# Lock the transition immediately to prevent duplicate waves.
	state = State.FIGHTING
	call_deferred("_start_next_stage")
