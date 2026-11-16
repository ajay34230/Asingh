# Bucket List

Ideas saved for later, in the order Ajay and Claude agreed to tackle them. Tick an item off (and add a line to
`docs/phase1/PHASE_1_REPORT.md`) when it's done.

## Graphics improvements (saved 2026-11-14)

Phone budget: Ajay's phone (Adreno 650) runs Low at about 20–24 fps, so everything here has to be cheap to draw
on Low. Expensive extras should only be turned on for Medium or High.

Suggested order: start with 1 and 2 together, since they cover most of what's on screen at any moment.

- [ ] **1. Ground and sand.** The dunes look flat and plasticky up close. Add:
  - wind ripples, and darker sand in the hollows;
  - footprints and hoof marks;
  - greener grass around the village.
- [ ] **2. Lighting and sky.** Add:
  - warmer sunrise and sunset colours;
  - soft shadow at the base of walls and under trees;
  - a proper sun glow, and moving cloud shadows on the ground.
- [ ] **3. Trees and plants.** Some trees look grainy at a distance. Use smoother leaves that sway in the wind.
- [ ] **4. Buildings.** Worn plaster, cracks and stains on walls, and shading where walls meet the ground, so
  houses stop looking like plain boxes.
- [ ] **5. Water.** Reflections, ripples and shoreline foam for the pond.
- [ ] **6. Characters and animals.** Smoother shading on the animals (the horse and bull look blocky), and better
  faces and clothes for people.
- [x] **7. Health bars.** Enemy, monster and ghost health shown as one small single bar (no text or block
  characters), green when full, turning yellow and then red as health drops. Keep the 20 m limit.
- [x] **8. Distance fog and sandstorms for FPS.** When FPS drops, bring in a dust haze that shortens the view
  (40 to 60 m; 15 m only in a rare heavy sandstorm), so far things are not drawn. Mission enemies stay drawn
  past the fog with a red marker. Low-detail models far away for imported 3D models.
- [ ] **9. Better fighting (player feedback 2026-11-17).** Fight animations and styles look very bad, and enemies
  are dumb. Plan in phases: (a) use the captured Mixamo/UAL combat clips for every strike, block, dodge and hit
  reaction instead of code poses; (b) enemy AI: circle and spacing, take turns attacking (no dog-piling or idle
  waiting), block and dodge, flank, retreat when hurt, use cover for archers; (c) combos, counters on a parry,
  finishers, and weight (hit-stop, knockback, camera).
