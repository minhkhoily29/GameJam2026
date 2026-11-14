# Sound sources and game events

Main theme: `music/alien_vanishing_point.wav`, copied without conversion from the
user-provided `ALIEN_VANISHING_POINT_ALT2.wav` in Downloads. The original download
is unchanged. No creator or license was supplied for this track; this entry does
not claim it is CC0. It loops on the Music bus at -28 dB while a map is active.

New downloads are CC0 (public domain). Original pack names are recorded so the
files can be traced and replaced. Pack license files are included under kenney/.

| Local file | Original source | Creator / license |
| --- | --- | --- |
| opengameart/snot_spit.wav | Actions/Spitting.wav in https://opengameart.org/content/action-sounds | pauliuw, CC0 |
| opengameart/snot_hit.wav | impactsplat01.mp3.flac in https://opengameart.org/content/8-wet-squish-slurp-impacts | Independent.nu, submitted by qubodup, CC0 |
| kenney/knife_slash.wav | knifeSlice.ogg, https://kenney.nl/assets/rpg-audio | Kenney, CC0 |
| kenney/key_pickup.ogg | handleCoins2.ogg, https://kenney.nl/assets/rpg-audio | Kenney, CC0 |
| kenney/player_hit.ogg | impactPunch_medium_000.ogg, https://kenney.nl/assets/impact-sounds | Kenney, CC0 |
| kenney/enemy_death.ogg | impactSoft_heavy_000.ogg, same Impact Sounds pack | Kenney, CC0 |

Wet impacts were converted from FLAC to 16-bit PCM WAV and peak-normalized to
0.8. Snot impact onset was shortened by 59 ms. The active knife WAV removes
76 ms of lead-in from the retained source OGG. No external links or downloads
are needed by the running game.
CC0: https://creativecommons.org/publicdomain/zero/1.0/

Existing project audio is reused unchanged. Its original provenance was not
recorded in this checkout, so no new license claim is made for those files:

- slime for door.ogg: player death, departure/arrival through doors; pitched and
  quieter for enemy teleportation.
- foot steps.ogg: only while the player actually walks, not idle or knocked back.
- background noise.ogg: looping ship ambience, stopped when the map closes.
- flower_pickup.wav: derived from collecting flower.mp3 with 1.416 seconds of
  leading silence and 1.075 seconds of trailing silence removed; plays immediately on successful collection. The
  original MP3 is retained unchanged as a backup.
- lowFrequency_explosion_000.ogg: final-door explosion at -13 dB on SFX, with
  pitch 0.9 for a subdued low-frequency effect.
- gun.ogg: intentionally unused; the shrimp spits rather than fires a gun.

Knife slash plays when an astronaut starts charging. Accepted nonfatal player
hits have a separate impact; lethal hits use the slime death cue. Each snot bullet
triggers one shot sound and at most one wet enemy impact. Wall hits are silent.
Enemy death adds a short body impact to its final snot hit.

Escape audio hooks are in scripts/combat/escape_condition.gd. Collecting the key
plays one key jingle; an accepted final-door explosion plays the bass cue once.
The actual key pickup and final-door scenes are not wired into this map yet.

All routing and levels are in scripts/audio/audio_manager.gd. SFX, Music and
Ambience use separate buses. One-shots live under the audio autoload so freeing enemies,
pickups, or bullets does not truncate them. Simultaneous voices are capped at 32;
pitch variation uses a separate RNG and does not affect seeded spawning. Headless
runs skip opening audio voices.
