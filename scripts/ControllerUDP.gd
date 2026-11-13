extends Node

var udp := PacketPeerUDP.new()

var x: int = 2048
var y: int = 2048
var button_pressed: bool = false
var joystick_pressed: bool = false
var tilted: bool = false

@onready var player = get_parent()


func _ready() -> void:
	var error := udp.bind(5005, "127.0.0.1")

	if error != OK:
		push_error("UDP bind failed: " + error_string(error))
		set_process(false)
		return

	print("Listening for controller on UDP port 5005")


func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var message := udp.get_packet().get_string_from_utf8().strip_edges()
		var fields := message.split(",")

		if fields.size() != 5:
			continue

		var valid := true
		for field in fields:
			if not field.is_valid_int():
				valid = false
				break

		if not valid:
			continue

		var new_x := int(fields[0])
		var new_y := int(fields[1])
		var new_button := int(fields[2])
		var new_joystick := int(fields[3])
		var new_tilt := int(fields[4])

		if new_x < 0 or new_x > 4095 or new_y < 0 or new_y > 4095:
			continue

		if new_button not in [0, 1] or new_joystick not in [0, 1] or new_tilt not in [0, 1]:
			continue

		var was_pressed := button_pressed

		x = new_x
		y = new_y
		button_pressed = new_button == 1
		joystick_pressed = new_joystick == 1
		tilted = new_tilt == 1

		player.update_aim(x, y)

		# Fire once per press, rather than once per packet.
		if button_pressed and not was_pressed:
			player.shoot()


func _exit_tree() -> void:
	udp.close()
