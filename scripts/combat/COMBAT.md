# Shrimp snot attack

The shrimp spits projectiles directly through its SnotAttack child; no held item
or gunshot sound is used. `Player.shoot()` remains the controller-facing entry point.

- Controller button: spit in the last joystick-facing direction.
- Left-click: aim at the pointer and spit.
- Space: spit in the current facing direction.
- Fire rate: at most five shots per second.

Human enemies start with two health. Normal snot deals one damage, so two hits
kill. Collecting the cosmos flower doubles damage to two, so one powered hit
kills. Damage is stored on each projectile when it is fired. Repeated pickups do
not stack damage or speed; the buff lasts for the current map run. The existing
flower's speed multiplier is also applied. The collectible scene is available for
later placement; no power-up flower is currently placed on the map.

`scenes/snot_bullet.tscn` uses a small green-tinted version of the existing flower
PNG as temporary projectile art. Replace Sprite2D.texture and adjust its scale
when the snot PNG is ready. Player attack animation can be added to `shoot()`
after a successful fire; current walk/idle and door teleport animations remain.

Projectiles sweep a seven-pixel radius to detect thin walls and enemies, ignore
the shooter, stop on the first impact, and expire after 1.25 seconds. They deal
damage only to enemies. Taking a hit briefly flashes the astronaut or shrimp red.
Enemy death still emits `died`, letting the room spawner count remaining enemies
and emit `section_cleared`. Player health/damage is not introduced by this change;
enemy contact still uses the existing bounce-back behavior.
