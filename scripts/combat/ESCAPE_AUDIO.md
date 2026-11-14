# Escape audio integration

Use one node with `escape_condition.gd` shared by the key pickup and final door.
The script provides the event state and audio hooks; it does not place either
object in the current map.

On confirmed key pickup, call `collected_escape_key()`. It sets `has_key`, plays
`key_pickup` once, and emits `escape_key_collected`. Repeated pickup calls are
ignored. `check_collected_key()` reports whether the key has been collected.

On the player's final-door interaction, call `try_explode_final_door()`. It returns
false until the key is collected and after the door has already opened. On the
first accepted interaction it plays `final_door_explosion`, sets
`is_final_door_open`, emits `final_door_exploded`, and returns true. Connect that
signal to the final-door animation/blocker removal when those scenes are added.

The explosion reuses the project's lowFrequency_explosion_000.ogg at -3 dB,
through the SFX bus (-2 dB), with fixed pitch 1.0. It is intentionally a low,
loud boom. The audio manager owns playback so removing the door node will
not cut off the sound. Balance levels in scripts/audio/audio_manager.gd.
