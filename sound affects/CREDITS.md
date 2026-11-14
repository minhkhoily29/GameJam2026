# Sound sources and game events

Main theme: `music/alien_vanishing_point.wav`, copied without conversion from the
user-provided `ALIEN_VANISHING_POINT_ALT2.wav` in Downloads. The original download
is unchanged. No creator or license was supplied for this track; this entry does
not claim it is CC0. It loops on the Music bus at -28 dB while a map is active.

New downloads are CC0 (public domain), except the explosion explicitly credited
under CC BY 3.0 below. Original pack names are recorded so the
files can be traced and replaced. Pack license files are included under kenney/.

| Local file | Original source | Creator / license |
| --- | --- | --- |
| opengameart/snot_spit.wav | Actions/Spitting.wav in https://opengameart.org/content/action-sounds | pauliuw, CC0 |
| opengameart/snot_hit.wav | impactsplat01.mp3.flac in https://opengameart.org/content/8-wet-squish-slurp-impacts | Independent.nu, submitted by qubodup, CC0 |
| opengameart/final_door_grenade.wav | explodemini.wav, https://opengameart.org/content/2-high-quality-explosions | Michel Baradari (apollo-music.de), CC BY 3.0, https://creativecommons.org/licenses/by/3.0/ |
| kenney/knife_slash.wav | knifeSlice.ogg, https://kenney.nl/assets/rpg-audio | Kenney, CC0 |
| kenney/key_pickup.ogg | handleCoins2.ogg, https://kenney.nl/assets/rpg-audio | Kenney, CC0 |
| kenney/door_locked.ogg | metalLatch.ogg, https://kenney.nl/assets/rpg-audio | Kenney, CC0 |
| kenney/enemy_teleport.ogg | forceField_000.ogg, https://kenney.nl/assets/sci-fi-sounds | Kenney, CC0 |
| opengameart/enemy_teleport_02.ogg | teleport_02.ogg, https://opengameart.org/content/50-cc0-sci-fi-sfx | rubberduck, CC0 |
| opengameart/enemy_teleport_02_immediate.wav | Trimmed from the retained rubberduck teleport_02.ogg above | rubberduck, CC0 |
| opengameart/low_health_heartbeat.wav | heartbeat_fast_0.wav, https://opengameart.org/content/heartbeat-sounds | bart, CC0 |
| kenney/power_up_loop.wav | engineCircular_002.ogg, https://kenney.nl/assets/sci-fi-sounds | Kenney, CC0 |
| kenney/player_hit.ogg | impactPunch_medium_000.ogg, https://kenney.nl/assets/impact-sounds | Kenney, CC0 |
| kenney/enemy_death.ogg | impactSoft_heavy_000.ogg, same Impact Sounds pack | Kenney, CC0 |
| kenney/enemy_defeat.wav | Layered impactSoft_heavy_000.ogg and impactMetal_heavy_002.ogg, https://kenney.nl/assets/impact-sounds | Kenney, CC0 |

Wet impacts were converted from FLAC to 16-bit PCM WAV and peak-normalized to
0.8. Snot impact onset was shortened by 59 ms. The active knife WAV removes
76 ms of lead-in from the retained source OGG. No external links or downloads
are needed by the running game.
CC0: https://creativecommons.org/publicdomain/zero/1.0/

Final-door grenade-style explosion: "explodemini.wav" by Michel Baradari,
apollo-music.de, from "2 High Quality Explosions" on OpenGameArt.org, licensed
under CC BY 3.0. Adapted by trimming leading silence and peak-normalizing to 0.90.
The source credit/license notice is in opengameart/LICENSE-EXPLOSIONS.txt.
Preserve this attribution in the game's distributed credits.

Existing project audio is reused unchanged. Its original provenance was not
recorded in this checkout, so no new license claim is made for those files:

- slime for door.ogg: player death and departure/arrival through doors.
- opengameart/enemy_teleport_02_immediate.wav: rubberduck teleport_02 on every successful
  enemy teleport, including approach teleports without a hit. Uses -3 dB on SFX,
  fixed normal pitch and no distance falloff. The Kenney forcefield is retained
  as an unused asset; its license is in LICENSE-SCIFI.txt.
  The active WAV skips 0.8 seconds of quiet buildup, keeps the warp through 1.5
  seconds of the original, and applies short boundary fades. This lines the audible
  cue up with the jump instead of a later attack. The original OGG is retained.
  Background reduction holds for 0.65 seconds across the audible warp.
- foot steps.ogg: only while the player actually walks, not idle or knocked back.
- background noise.ogg: looping ship ambience, stopped when the map closes.
- flower_pickup.wav: derived from collecting flower.mp3 with 1.416 seconds of
  leading silence and 1.075 seconds of trailing silence removed; plays immediately on successful collection. The
  original MP3 is retained unchanged as a backup.
- lowFrequency_explosion_000.ogg: original retained asset, replaced for the final
  door by final_door_grenade.wav at -1 dB on SFX with normal pitch.
- gun.ogg: intentionally unused; the shrimp spits rather than fires a gun.

Knife slash plays when an astronaut starts charging. Accepted nonfatal player
hits have a separate impact; lethal hits use the slime death cue. Each snot bullet
triggers one shot sound and at most one wet enemy impact. Wall hits are silent.
Enemy death adds an airy sci-fi vanish cue to its final snot hit, once per kill
at -2 dB on SFX without distance attenuation. The active enemy_vanish.wav is an
original 0.65-second synthesized descending sweep with fading noise particles,
made for this project and peak-normalized to 0.80. The earlier enemy_defeat.wav
body-and-armour mix and original enemy_death.ogg are retained as unused assets.

Escape audio hooks are in scripts/combat/escape_condition.gd. Collecting the key
plays one key jingle; an accepted final-door explosion plays the bass cue once.
The current map's Player.collect_final_key() plays the pickup cue on the first
collection. FinalDoor._explode() plays the explosion cue at animation start.
These use the current player/door logic directly rather than EscapeCondition.

Locked-door feedback is connected to FinalDoor.gd's missing-key branch. It plays a
quiet, lowered-pitch metal latch, limited to one cue per 600 ms. Successful or
already-opening door interactions do not trigger it.

All routing and levels are in scripts/audio/audio_manager.gd. SFX, Music and
Ambience use separate buses. One-shots live under the audio autoload so freeing enemies,
pickups, or bullets does not truncate them. Simultaneous voices are capped at 32;
pitch variation uses a separate RNG and does not affect seeded spawning. Headless
runs skip opening audio voices.

The mix gives pickups and combat warnings space above repeated movement/attack
sounds. Gains account for the recordings' different source levels; the quiet key
recording needs +8 dB to be comparable to other feedback. Current voice gains:

| Event | Gain before the -2 dB SFX bus |
| --- | --- |
| Footstep | -21 dB |
| Door slide | -13 dB |
| Snot shot / impact | -5 / -11 dB |
| Knife warning / player hit | -4 / -6 dB |
| Enemy teleport / vanish | -3 / -2 dB |
| Flower / key pickup | -6 / +8 dB |
| Locked door | -12 dB |
| Player death / final explosion | -5 / -1 dB |

Footsteps, shots, and door slides use a Routine bus feeding SFX. During important
cues this bus drops by 5 dB, including sounds already playing. Music briefly
drops by 4 dB; the existing 8 dB low-health/power-up reduction takes precedence.
Overlapping cues extend one hold instead of stacking gain reductions or dropping
events. Levels recover after the cue hold, and stopping SFX clears the hold.
Heartbeat, power-up, and enemy vanish playback gains remain at their approved levels.

Player state loops are in scripts/audio/player_state_audio.gd. At 1 HP a heartbeat
loops at +4 dB on SFX until healing or death. The existing brief damage flash is unchanged.
Music is reduced by 8 dB during low health or a cosmos power-up. Overlapping
states share one reduction; normal music returns when both end, on death, or on scene exit.
The ship engine ambience is silent while the low-health heartbeat is active,
and resumes when healing stops the heartbeat. Death and scene exit clear the pause.
A fast synthesized arcade power-up loop (-11 dB on SFX, with the SFX bus at -2 dB) runs
only during the five-second cosmos buff, above the Music bus at -18 dB;
another flower refreshes the timer without restarting or stacking the loop.
Expiry, death, and scene exit stop it. The active power_up_hyper.wav is an original
four-second synthesized loop made for this project, with eight bouncy arpeggio
notes per second and alternating stereo motion. Its RMS level matches the earlier
soft pulse, and the playback gain is unchanged. The earlier power_up_pulse.wav
and Kenney engine-derived power_up_loop.wav are retained as unused assets.
