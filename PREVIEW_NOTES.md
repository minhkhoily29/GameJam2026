# Temporary desktop preview controls

The game is intended to use the ESP controller. Normal launches do not accept
keyboard/mouse gameplay input. The existing UDP update_aim(), shoot(), and
try_door_teleport() entry points remain the production controls.

For the current hardware-free local preview only, launch Godot with user arguments:

```
godot --path . res://scenes/main.tscn -- --desktop-preview
```

This temporarily enables WASD/arrows, Space/left-click, E for doors, and R after
death. Before the next merge, remove the desktop preview flag and keyboard/mouse
input handlers from Player.gd, and delete this note. Keep the ESP input functions.
