extends ColorRect

const SPACE_AMBIENCE: AudioStreamOggVorbis = preload("res://sound affects/ambience/space_echo.ogg")

var _ambience: AudioStreamPlayer

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		AudioManager.stop_all_audio()
		var stream := SPACE_AMBIENCE.duplicate() as AudioStreamOggVorbis
		stream.loop = true
		_ambience = AudioStreamPlayer.new()
		_ambience.name = "SpaceAmbience"
		_ambience.stream = stream
		_ambience.bus = &"Master"
		_ambience.volume_db = 6.0
		add_child(_ambience)
		_ambience.play()
	$BackToMenu.grab_focus()


func _on_back_to_menu_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if error != OK:
		push_error("Could not return to the main menu: " + error_string(error))


func _exit_tree() -> void:
	if is_instance_valid(_ambience):
		_ambience.stop()
