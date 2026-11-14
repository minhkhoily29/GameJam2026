# Godot gameplay checks

Run from the repository root with Godot 4.7:

```
godot --headless --path . --script res://tests/combat_smoke.gd
godot --headless --path . --script res://tests/enemy_contact_smoke.gd
godot --headless --path . --script res://tests/section_spawning_smoke.gd
```

Each script exits with a nonzero status on failure. These use real game scenes
and physics, disable the UDP controller in the test scene, and need no hardware.

- Combat: actual projectile impacts, two normal hits / one powered hit, flower
  collection, fire-rate limiting, thin-wall blocking, expiry and teleport lockout.
- Contact: natural approaches and close-range attacks, knockback/retreat recovery,
  retreat placement within the starting room, and absence of a placed flower.
- Sections: 32 seeded room batches, room-size counts, safe placement, repeat-entry
  behavior, wave replacement without stacking and astronaut animation frames.
