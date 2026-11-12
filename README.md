# Asingh

## Ludo Battle Bots

A Ludo game where the pieces are robots. Landing on a rival starts an automatic fight, and the winner keeps the square.

- Open `index.html` in a browser to play. You are Red; the other three teams are bots. Tick **Autopilot** to let a bot play for you.
- Four robot classes (Striker, Guardian, Marksman, Saboteur), each with three skills it chooses between on its own.
- `game.html` is the source. Run `./build.sh` to regenerate `index.html` from it.

The fight engine (`simulate`), the skill-picking logic (`choose`) and the board bot (`pickMove`) sit between the `/*ENGINE*/` markers in `game.html` and have no DOM dependencies.
