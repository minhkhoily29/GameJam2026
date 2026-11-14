extends SceneTree
var failures := 0
var audio: Node
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func pause(seconds: float) -> void:
	await create_timer(seconds).timeout
func run_checks() -> void:
	audio = root.get_node("AudioManager")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	var ambience_bus := AudioServer.get_bus_index(&"Ambience")
	check(sfx_bus > 0 and ambience_bus > 0 and sfx_bus != ambience_bus, "Ambience and SFX need separate buses")
	check(AudioServer.get_bus_volume_db(ambience_bus) <= -30.0, "Ship ambience must remain quiet")
	for event in audio.SOUNDS:
		var stream: AudioStream = audio.SOUNDS[event][0]
		check(stream != null and stream.get_length() > 0.0 and stream.get_length() < 4.0, "Invalid or excessively long cue: %s" % event)
	check(not audio.SOUNDS.has(&"snot_wall") and not audio.SOUNDS.has(&"wall_impact"), "Wall sounds must remain removed")
	seed(714)
	var expected_random := randf()
	seed(714)
	audio.play_sfx(&"snot_shoot")
	check(randf() == expected_random, "Audio pitch must not change gameplay randomness")
	audio.stop_all_sfx()
	await pause(0.15)
	if DisplayServer.get_name() != "headless":
		print("Audio output: ", AudioServer.output_device)
		for event in audio.SOUNDS:
			var voice = audio.play_sfx(event)
			check(is_instance_valid(voice) and voice.playing, "Cue must start playback: %s" % event)
			check(voice.bus == &"SFX", "Cue must use SFX bus: %s" % event)
			check(voice.volume_db + AudioServer.get_bus_volume_db(sfx_bus) <= -7.0, "Cue must retain mixing headroom: %s" % event)
			var length: float = voice.stream.get_length() / voice.pitch_scale
			await pause(length + 0.12)
			check(not is_instance_valid(voice), "Finished cue must release its player: %s" % event)
			check(audio._voices.is_empty(), "Finished cue must leave no active voices: %s" % event)
			print("Playback/release PASS: ", event)
		for event in [&"snot_hit", &"knife_slash", &"enemy_teleport"]:
			var spatial = audio.play_sfx(event, Vector2(400, 250))
			check(spatial is AudioStreamPlayer2D and spatial.playing, "World cue must use spatial playback")
			check(spatial.global_position == Vector2(400, 250), "Spatial cue must keep its source position")
			await pause(spatial.stream.get_length() / spatial.pitch_scale + 0.12)
			check(not is_instance_valid(spatial), "Spatial playback must release")
		# Mute only this test process during voice stress, avoiding a loud burst.
		var was_muted := AudioServer.is_bus_mute(sfx_bus)
		AudioServer.set_bus_mute(sfx_bus, true)
		var oldest = audio.play_sfx(&"flower_pickup")
		for i in range(audio.MAX_VOICES + 8):
			audio.play_sfx(&"flower_pickup")
		check(audio._voices.size() == audio.MAX_VOICES, "Concurrent voices must stay capped")
		await process_frame
		check(not is_instance_valid(oldest), "Voice stealing must release the oldest player")
		await pause(0.8)
		check(audio._voices.is_empty(), "Stress playback must fully drain")
		AudioServer.set_bus_mute(sfx_bus, was_muted)
		audio.start_ambience()
		audio.start_ambience()
		var ambience = audio._ambience
		var music = audio._music
		check(is_instance_valid(music) and music.playing and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Main theme must start and loop")
		check(music.bus == &"Music", "Music must have its own mix bus")
		check(ambience.playing and ambience.stream.loop, "Ambience must loop")
		audio.stop_ambience()
		check(is_instance_valid(ambience) and ambience.playing, "One remaining map must retain ambience")
		check(is_instance_valid(music) and music.playing, "One remaining map must retain the theme")
		await pause(5.2)
		check(ambience.playing, "Ambience must continue beyond its five-second source")
		audio.stop_ambience()
		await pause(0.15)
		check(not is_instance_valid(ambience) and audio._ambience_users == 0, "Last map must release ambience")
		check(not is_instance_valid(music), "Closing the last map must release the theme")
	else:
		print("Headless asset/routing checks only; use a visible run for playback lifecycle checks.")
	audio.stop_all_sfx()
	await pause(0.15)
	print("Audio playback/lifecycle checks: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
