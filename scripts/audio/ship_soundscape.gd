extends Node
## Scope looping ship ambience to the running map.
func _ready() -> void:
	AudioManager.start_ambience()

func _exit_tree() -> void:
	AudioManager.stop_ambience()
	if AudioManager._ambience_users == 0:
		AudioManager.stop_all_sfx()
