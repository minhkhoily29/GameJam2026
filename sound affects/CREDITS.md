# Sound sources and game events

Gameplay theme: `music/Intense background battle music.wav`, looped on the Music
bus while a map is active.

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
| opengameart/enemy_teleport_02_immediate.wav | Trimmed from teleport_02.ogg, https://opengameart.org/content/50-cc0-sci-fi-sfx | rubberduck, CC0 |
| kenney/player_hit.ogg | impactPunch_medium_000.ogg, https://kenney.nl/assets/impact-sounds | Kenney, CC0 |
| ambience/space_echo.ogg | Space Echo, https://opengameart.org/content/space-echo | Centurion_of_war, CC0 |
| extraction_countdown.mp3 | Blasting Off Spaceship Flyby 04, https://sfxmint.com/sounds/spaceship-flyby-04 | SFXMint, CC0 |
| extraction_victory.wav | Original synthesized five-second victory fanfare created for this project | Original project audio |

Wet impacts were converted from FLAC to 16-bit PCM WAV and peak-normalized to
0.8. Snot impact onset was shortened by 59 ms. The active knife WAV removes
76 ms of lead-in from its source. Space Echo loops on the ending scene's Ambience
bus. The slowed spaceship blast-off cue fills the five-second extraction hold.
The synthesized victory fanfare runs on the Music bus under the blast-off cue
through extraction and stops if the hold is interrupted.
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
  fixed normal pitch and no distance falloff. The source recording was removed
  after preparing the active clip.
  The active WAV skips 0.8 seconds of quiet buildup, keeps the warp through 1.5
  seconds of the original, and applies short boundary fades. This lines the audible
  cue up with the jump instead of a later attack.
  Background reduction holds for 0.65 seconds across the audible warp.
- foot steps.ogg: only while the player actually walks, not idle or knocked back.
- background noise.ogg: looping ship ambience, stopped when the map closes.
- flower_pickup.wav: derived from its source recording with 1.416 seconds of
  leading silence and 1.075 seconds of trailing silence removed; plays immediately
  on successful collection.

Knife slash plays when an astronaut starts charging. Accepted nonfatal player
hits have a separate impact; lethal hits use the slime death cue. Each snot bullet
triggers one shot sound and at most one wet enemy impact. Wall hits are silent.
Enemy death adds an airy sci-fi vanish cue to its final snot hit, once per kill
at -2 dB on SFX without distance attenuation. The active enemy_vanish.wav is an
original 0.65-second synthesized descending sweep with fading noise particles,
made for this project and peak-normalized to 0.80.

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
| Extraction countdown / victory fanfare | +2 dB / +14 dB on Music bus (-18 dB bus level) |
| Low-health warning loop | -16 dB |

Footsteps, shots, and door slides use a Routine bus feeding SFX. During important
cues this bus drops by 5 dB, including sounds already playing. Music briefly
drops by 4 dB; the existing 8 dB low-health/power-up reduction takes precedence.
Overlapping cues extend one hold instead of stacking gain reductions or dropping
events. Levels recover after the cue hold, and stopping SFX clears the hold.
Power-up and enemy vanish playback gains remain at their approved levels.

Player state loops are in scripts/audio/player_state_audio.gd. At 1 HP an electronic
two-tone warning loops at -16 dB on SFX until healing or death. The active
low_health_warning.wav is an original synthesized 1.2-second loop made for this
project, with two clear alert notes and a gap between repetitions. It replaces
the earlier heartbeat cue with a more prominent alarm.
The existing brief damage flash is unchanged.
Music is reduced by 8 dB during low health or a cosmos power-up. Overlapping
states share one reduction; normal music returns when both end, on death, or on scene exit.
The ship engine ambience is silent while the low-health warning is active,
and resumes when healing stops the warning. Death and scene exit clear the pause.
A fast synthesized arcade power-up loop (-11 dB on SFX, with the SFX bus at -2 dB) runs
only during the five-second cosmos buff, above the Music bus at -18 dB;
another flower refreshes the timer without restarting or stacking the loop.
Expiry, death, and scene exit stop it. The active power_up_hyper.wav is an original
four-second synthesized loop made for this project, with eight bouncy arpeggio
notes per second and alternating stereo motion. Its RMS level matches the earlier
soft pulse, and the playback gain is unchanged.
