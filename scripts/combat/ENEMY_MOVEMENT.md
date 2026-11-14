# Human enemy movement and spawning

The green alien/shrimp is the player; humans are enemies.

`scenes/human_enemy.tscn` is the reusable enemy scene. Its AnimatedSprite2D uses
`assets/astronaut_enemy.png`: eight 500x500 walking frames at 12 FPS, scaled to
0.28. The first frame is the idle pose. It faces its movement direction.
The collision body remains independent of the art.

Main/Enemies contains four section areas matching the existing map: CaptivityRoom,
CargoRoom, MessHall and ObservationRoom. Each uses `enemy_section.gd` and a
CollisionPolygon2D to define its boundary. Adjust those polygons as the map changes.

CaptivityRoom and CargoRoom each spawn one human enemy. MessHall and
ObservationRoom each spawn a random batch of 3-4 enemies. They are scattered
across clear positions within that section. Placement checks
the full collision body against walls and other bodies, leaves at least 140 pixels
from the player and 100 pixels between spawn centers, and keeps enemies within
the section. Counts and spacing are adjustable in the section's Inspector.

Each section spawns a wave on the first entry and again when the player returns
after entering a different section. Staying in the room or briefly stepping into
the corridor and back does not spawn more waves. On return, any surviving enemies
from the previous wave are replaced so the room stays within its configured count.
Enemies pause outside the current section and cannot chase or teleport into another.
If edited bounds leave insufficient safe space, placement warns rather than
spawning enemies inside walls. The spawner exposes `section_spawned(count)` and
`section_cleared` signals for teammates to connect to progression. The existing
Stage.gd wave system is not attached; avoid enabling both spawners on this map.

Each enemy has its own EnemyMovement child. Inspector settings control:

- Chase speed and stopping distance.
- Charge range, warning duration, speed, duration, recovery and cooldown.
- Retreat teleport distance and pause duration after hitting the player.

Enemies chase the player group. They pause before charging,
lock a charge direction,
then rush along that direction, allowing the player to dodge. A collision ends the
charge. Enemies never teleport during normal approach or pursuit. On each accepted
contact hit, the player is knocked back and the attacker immediately teleports
240-400 pixels away, then pauses for 1.2 seconds before resuming. Retreat checks
the full collision shape and rejects destinations outside the section or across
walls/closed doors. If no safe spot exists, the attacker stays put and still pauses.
Hits rejected by the player's cooldown or door teleport do not trigger retreat.

Enemy body contact knocks the player away at 460 pixels/second, slowing over
0.22 seconds before movement control resumes. The shrimp flashes red for 0.2
seconds when hit; enemies also flash red when struck by snot. A shared 0.65-second hit cooldown
prevents enemies from repeatedly bouncing the player while touching. Knockback
uses collision sliding and stops at walls; door teleporting ignores enemy hits.
The player's Inspector exposes knockback speed, duration, slowing and cooldown.
The `hit_by_enemy(source_position)` signal is available for later health integration.

Movement uses CharacterBody2D collision sliding. It does not navigate mazes around
obstacles; the existing map has no navigation mesh. This component adds movement,
not contact damage or player health.
