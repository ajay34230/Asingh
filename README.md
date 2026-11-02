# Royal India Ludo

A 3D Ludo board styled after a Royal India palace: four domed courtyards, a
gold lotus medallion at the centre, and a dice you tap on the board to roll. It
is built for landscape phones and runs offline against bots or with friends
passing the device.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design.

## Run it

Modules need to be served over HTTP (not opened from `file://`):

```sh
npm run serve          # python3 -m http.server on http://localhost:8080
```

Then open <http://localhost:8080/index.html>. For a phone on the same network,
use your computer's LAN address on port 8080 and rotate the device to landscape.

Optional URL parameters:

| parameter | values                 | purpose                          |
|-----------|------------------------|----------------------------------|
| `mode`    | `solo`, `duel`, `pass` | 1 you + 3 bots, 1 you + 1 bot, 4 humans |
| `quality` | `low`, `medium`, `high`| graphics preset                  |
| `seed`    | any integer            | deterministic dice sequence      |

## How to play

- Tap the dice to roll.
- Tap a highlighted token to move it. If only one move is legal, it is played for you.
- A 6 brings a token out of the courtyard and gives a bonus roll.
- Land on an opponent outside a star or start square to send it home.
- Reach the centre with an exact roll. Three 6s in a row forfeit the turn.

## Tests

```sh
npm test               # board topology and rules (node --test, no dependencies)
node tests/e2e/play.mjs        # plays real turns in headless Chromium (needs Playwright)
node tests/e2e/screenshot.mjs  # screenshots at desktop and phone sizes
```

## Layout

```
index.html, style.css      page and HUD
src/game/                  pure rules, board topology, AI (no three.js)
src/render/                Three.js scene, board, palaces, tokens, dice, effects
src/app/                   turn controller and HUD
vendor/three/              vendored Three.js r160 (MIT)
tests/                     unit tests and browser tests
docs/ARCHITECTURE.md       design notes and known limits
```

## Android

This is a web app with a PWA manifest set to landscape and fullscreen. It can be
wrapped as a Trusted Web Activity or a Capacitor/WebView app. No APK is included.
