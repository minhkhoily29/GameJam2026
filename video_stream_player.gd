extends VideoStreamPlayer

var _leaving: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_finished()


func _on_finished() -> void:
	if _leaving:
		return
	_leaving = true
	var error := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		_leaving = false
		push_error("Could not start gameplay: " + error_string(error))
