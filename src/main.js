/**
 * Entry point: builds the scene, wires input, runs the frame loop.
 *
 * URL parameters (optional, mainly for testing):
 *   ?seed=123      deterministic dice sequence
 *   ?mode=solo     solo | duel | pass
 *   ?quality=low   low | medium | high
 */
import * as THREE from '../vendor/three/three.module.js';
import { createScene, pointerToNdc, QUALITY_PRESETS } from './render/scene.js';
import { createMaterials } from './render/materials.js';
import { buildBoard } from './render/board.js';
import { buildPalaces } from './render/palace.js';
import { createTokens } from './render/tokens.js';
import { Dice } from './render/dice.js';
import { Tweens, SparkBurst, Confetti } from './render/effects.js';
import { createRng, legalMoves } from './game/rules.js';
import { GameController, MODES } from './app/game-controller.js';
import { createHud } from './app/hud.js';
import { COLORS } from './game/layout.js';

const STORE = {
  get(key) {
    try { return window.localStorage.getItem(key); } catch { return null; }
  },
  set(key, value) {
    try { window.localStorage.setItem(key, value); } catch { /* private mode or blocked storage */ }
  },
};

function defaultQuality() {
  const touch = matchMedia('(pointer: coarse)').matches;
  return touch ? 'medium' : 'high';
}

function boot() {
  const params = new URLSearchParams(window.location.search);
  const quality = QUALITY_PRESETS[params.get('quality')] ? params.get('quality')
    : (QUALITY_PRESETS[STORE.get('royalLudo.quality')] ? STORE.get('royalLudo.quality') : defaultQuality());
  const mode = MODES[params.get('mode')] ? params.get('mode')
    : (MODES[STORE.get('royalLudo.mode')] ? STORE.get('royalLudo.mode') : 'solo');
  const rng = params.has('seed') ? createRng(Number(params.get('seed')) || 1) : Math.random;

  const canvas = document.getElementById('scene');
  const view = createScene(canvas, quality);
  const { renderer, scene, camera, key } = view;

  const materials = createMaterials({ quality });
  const board = buildBoard(materials);
  const palaces = buildPalaces(materials);
  const tokens = createTokens(materials);
  scene.add(board.group, palaces.group);
  for (const token of tokens.all) {
    scene.add(token.root);
    token.placeAtProgress(0);
  }

  const tweens = new Tweens();
  const dice = new Dice(scene, materials, tweens);
  const sparks = new SparkBurst(scene);
  const confetti = new Confetti(scene, QUALITY_PRESETS.high.confetti);

  const controller = new GameController({
    tokensByColor: tokens.byColor,
    dice,
    tweens,
    sparks,
    confetti,
    hud: null,
    rng,
  });

  const applyQuality = (name) => {
    const next = QUALITY_PRESETS[name] ?? QUALITY_PRESETS.medium;
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, next.maxPixelRatio));
    renderer.shadowMap.enabled = next.shadows;
    key.castShadow = next.shadows;
    key.shadow.mapSize.set(next.shadowMapSize, next.shadowMapSize);
    if (key.shadow.map) {
      key.shadow.map.dispose();
      key.shadow.map = null;
    }
    STORE.set('royalLudo.quality', name);
    view.quality = name;
    view.resize();
  };

  let currentMode = mode;
  const hud = createHud(document, {
    onNewGame: () => controller.start(currentMode),
    onModeChange: (value) => {
      currentMode = value;
      STORE.set('royalLudo.mode', value);
      controller.start(currentMode);
    },
    onQualityChange: (value) => applyQuality(value),
  });
  controller.hud = hud;
  hud.syncControls({ mode, quality });

  // Resize, then fit the board. Keep the board centred and fully visible.
  view.resize();
  window.addEventListener('resize', () => view.resize());
  window.addEventListener('orientationchange', () => setTimeout(() => view.resize(), 150));

  // Input: a tap on the dice rolls; a tap on a highlighted token moves it.
  const raycaster = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  const pickables = () => [dice.body, ...tokens.all.map((t) => t.pick)];

  const pick = (event) => {
    pointerToNdc(event, canvas, ndc);
    raycaster.setFromCamera(ndc, camera);
    const hits = raycaster.intersectObjects(pickables(), false);
    return hits[0]?.object ?? null;
  };

  canvas.addEventListener('pointerdown', (event) => {
    const target = pick(event);
    if (!target) return;
    if (target === dice.body) {
      controller.requestRoll();
    } else if (target.userData.token) {
      controller.tapToken(target.userData.token);
    }
  });

  canvas.addEventListener('pointermove', (event) => {
    const target = pick(event);
    const hover = target && (target === dice.body
      ? controller.awaitingRoll
      : Boolean(target.userData.token && controller.legalPicks.includes(target.userData.token.index)
        && target.userData.token.color === controller.awaitingPick));
    canvas.style.cursor = hover ? 'pointer' : 'default';
  });

  // Frame loop.
  const clock = { last: performance.now(), time: 0 };
  const frame = (now) => {
    const dt = Math.min(0.05, (now - clock.last) / 1000);
    clock.last = now;
    clock.time += dt;
    const t = clock.time;

    tweens.update(dt);
    board.update(t);
    palaces.update(t);
    for (const token of tokens.all) token.animate(t);
    dice.animate(t);
    confetti.update(dt, t);
    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);

  controller.start(mode);

  // Debug hook for automated tests: screen positions of pickable objects.
  window.royalLudo = {
    describe: () => controller.describe(),
    legal: () => (controller.game && controller.game.phase === 'move' ? legalMoves(controller.game) : []),
    awaiting: () => ({ roll: controller.awaitingRoll, pick: controller.awaitingPick }),
    screenPoint(object3d) {
      const p = new THREE.Vector3();
      object3d.getWorldPosition(p);
      p.project(camera);
      const rect = canvas.getBoundingClientRect();
      return { x: rect.left + ((p.x + 1) / 2) * rect.width, y: rect.top + ((1 - p.y) / 2) * rect.height };
    },
    diceCentre: () => window.royalLudo.screenPoint(dice.body),
    tokenCentre: (color, index) => window.royalLudo.screenPoint(tokens.byColor[color][index].pick),
    colors: COLORS,
    quality: () => view.quality,
  };
}

boot();
