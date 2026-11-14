# Godot gameplay checks

Run from the repository root with Godot 4.7:

```
godot --headless --path . --script res://tests/combat_smoke.gd
godot --headless --path . --script res://tests/enemy_contact_smoke.gd
godot --headless --path . --script res://tests/section_spawning_smoke.gd
godot --headless --path . --script res://tests/audio_smoke.gd
godot --path . --script res://tests/audio_playback_smoke.gd
```

Each script exits with a nonzero status on failure. These use real game scenes
and physics, disable the UDP controller in the test scene, and need no hardware.

- Combat: actual projectile impacts, two normal hits / one powered hit, flower
  collection, fire-rate limiting, thin-wall blocking, expiry and teleport lockout.
- Contact: natural approaches and close-range attacks, knockback/retreat recovery,
  retreat placement within the starting room, and absence of a placed flower.
- Sections: 32 seeded room batches, room-size counts, safe placement, repeat-entry
  behavior, wave replacement without stacking and astronaut animation frames.
- Audio: imported sound lengths and event routing for snot, knife charges, player
  hit/death, door travel, walking, pickups and map ambience. Wall impacts are
  silent. Run audio_smoke.gd without --headless to check actual audio playback.
- Audio playback: plays all ten cues through the real audio device, checks
  finished-player cleanup, spatial cues, the 32-voice limit, ambience looping
  beyond its five-second source, and map ownership. The stress burst is muted.
