# Feature list and status

Based on a survey of popular Ludo apps (sources below): private rooms with codes, AI bots
with difficulty levels, house-rule options, cosmetic themes, chat and team modes.

## Implemented and tested (Godot 4.3)
| Feature | Where | Test |
|---|---|---|
| Standard rules, captures, safe squares, exact finish | `rules_engine.gd` | `run_tests.gd` |
| House rules: six to start, three-sixes penalty, capture bonus, home bonus, quick end | `rules_engine.gd` (`DEFAULT_RULES`) | `run_tests.gd` (house-rule tests) |
| Modes: Play vs AI, Pass and play (2 to 4 players), Quick play | `menu.gd`, `main.gd` | click test; demo |
| AI difficulty: Easy, Normal, Hard, Expert | `ai_controller.gd` | difficulty tests (games finish, moves legal) |
| Main menu, game setup, settings, how to play | `menu.gd` | screenshots (`docs/screenshots/godot-*.png`) |
| Settings: graphics level, camera tilt, animation speed, FPS readout, music, SFX, mute, vibration | `game_settings.gd`, `menu.gd` | manual (screenshot); not on device |
| Pause menu: resume, settings, how to play, restart, quit to menu | `hud.gd`, `main.gd` | not yet on screen |
| Results panel: rankings, rematch, main menu | `hud.gd` | not yet on screen |
| Sound and visual effects | `audio_manager.gd`, `effects_manager.gd` | demo; screenshot |

## Not implemented
- Online multiplayer, private rooms, room codes, friends, matchmaking, presence, reconnection:
  these need a server and accounts. The menu shows the entry disabled.
- Profiles, progression, XP, leaderboards, achievements, daily rewards, missions, shop,
  currency, rewarded ads, battle pass: need accounts and a server; not started.
- Cosmetic themes, custom dice and pins: not built.
- Chat, emoji, voice, team (2 v 2) modes: not built.
- Tutorial (interactive): only the written How to play page exists.
- Hindi language: shown as "coming soon".

## Sources
- Ludo Rivals (Apple App Store): https://apps.apple.com/us/app/ludo-rivals/id6478646614
- Ludo with Friends (room IDs, four players): https://games.tribuneindia.com/en/game/ludo-with-friends/SkhljT2fdgb
- Ludo Online Multiplayer Game (custom boards, 2v2): https://apps.apple.com/us/app/-/id1557033331
- Ludo Playground (AI opponents, avatars, daily rewards): https://apps.apple.com/us/app/-/id6747632452
- Foony Ludo (Easy, Medium, Hard bots; room settings): https://foony.com/games/ludo
- Ludo vs AI in browser: https://classicludo.lovable.app/play/ludo-vs-ai
