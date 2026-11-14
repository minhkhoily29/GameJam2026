extends ColorRect


func _ready() -> void:
	$BackToMenu.grab_focus()


func _on_back_to_menu_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if error != OK:
		push_error("Could not return to the main menu: " + error_string(error))
