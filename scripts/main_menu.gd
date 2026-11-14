extends Control


@onready var click_sound = $"click sound"


func _on_play_button_pressed():
	print("you pressed play wow")
	click_sound.play()
	await click_sound.finished
	get_tree().change_scene_to_file("res://Scenes/cutscene.tscn")
	

func _on_quit_button_pressed():
	print("You pressed quit >:C")
	click_sound.play()
	await click_sound.finished
	get_tree().quit()
