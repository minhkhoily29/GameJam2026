extends Node

## Share this instance between the key pickup and final-door interaction.
## Visual pickup/door scenes can connect these signals to their animations.
signal escape_key_collected
signal final_door_exploded

var has_key: bool = false
var is_final_door_open: bool = false


func collected_escape_key() -> void:
	if has_key:
		return
	has_key = true
	AudioManager.play_sfx(&"key_pickup")
	escape_key_collected.emit()


func check_collected_key() -> bool:
	return has_key


func try_explode_final_door() -> bool:
	if not has_key or is_final_door_open:
		return false
	is_final_door_open = true
	AudioManager.play_sfx(&"final_door_explosion")
	final_door_exploded.emit()
	return true
