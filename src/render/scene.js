/**
 * Renderer, lighting, environment, camera fitting and quality presets.
 */
import * as THREE from '../../vendor/three/three.module.js';
import { PALETTE } from './materials.js';
import { BOARD_ASPECT_X } from '../game/layout.js';

export const QUALITY_PRESETS = Object.freeze({
  low: { label: 'Low', maxPixelRatio: 1, shadows: false, shadowMapSize: 512, antialias: false, confetti: 60, sparks: 8 },
  medium: { label: 'Medium', maxPixelRatio: 1.5, shadows: true, shadowMapSize: 1024, antialias: true, confetti: 110, sparks: 12 },
  high: { label: 'High', maxPixelRatio: 2, shadows: true, shadowMapSize: 2048, antialias: true, confetti: 160, sparks: 16 },
});

/** Board extents used for camera fitting (foundation half-size plus dice height). */
const FIT_HALF = 8.75;
const FIT_HEIGHT = 2.4;

export function createScene(canvas, quality) {
  const preset = QUALITY_PRESETS[quality] ?? QUALITY_PRESETS.medium;

  const renderer = new THREE.WebGLRenderer({
    canvas,
    antialias: preset.antialias,
    powerPreference: 'high-performance',
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, preset.maxPixelRatio));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.02;
  renderer.shadowMap.enabled = preset.shadows;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(PALETTE.background);

  scene.environment = buildEnvironment(renderer);

  const hemi = new THREE.HemisphereLight('#fff1d6', '#3a2418', 0.85);
  scene.add(hemi);

  const key = new THREE.DirectionalLight('#ffe7bf', 2.1);
  key.position.set(-9, 7.5, 7);  // low angle: long shadows show pavilion and token height from straight above
  key.castShadow = preset.shadows;
  key.shadow.mapSize.set(preset.shadowMapSize, preset.shadowMapSize);
  key.shadow.camera.left = -11;
  key.shadow.camera.right = 11;
  key.shadow.camera.top = 11;
  key.shadow.camera.bottom = -11;
  key.shadow.camera.near = 2;
  key.shadow.camera.far = 40;
  key.shadow.bias = -0.0008;
  key.shadow.normalBias = 0.02;
  scene.add(key);
  scene.add(key.target);

  const fill = new THREE.DirectionalLight('#ffd9a0', 0.45);
  fill.position.set(9, 8, -6);
  scene.add(fill);

  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 200);
  const target = new THREE.Vector3(0, 0.4, 0);
  // Straight top-down: the board is seen flat, with no tilt or perspective wrap.
  const elevation = THREE.MathUtils.degToRad(90);
  camera.up.set(0, 0, -1); // keeps the top of the screen pointing at the far (red/green) edge

  const view = { camera, target, elevation, distance: 30 };

  const resize = () => {
    const width = window.innerWidth;
    const height = window.innerHeight;
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    fitCamera(view);
  };

  return { renderer, scene, camera, target, view, key, preset, resize, quality };
}

/** Smallest distance at which every corner of the board volume stays inside the view. */
export function fitCamera(state) {
  const { camera, target, elevation } = state;
  const dir = new THREE.Vector3(0, Math.sin(elevation), Math.cos(elevation));
  const corners = [];
  const halfX = FIT_HALF * BOARD_ASPECT_X;
  for (const x of [-halfX, halfX]) {
    for (const y of [0, FIT_HEIGHT]) {
      for (const z of [-FIT_HALF, FIT_HALF]) corners.push(new THREE.Vector3(x, y, z));
    }
  }
  const fits = (distance) => {
    camera.position.copy(target).addScaledVector(dir, distance);
    camera.lookAt(target);
    camera.updateMatrixWorld();
    return corners.every((corner) => {
      const p = corner.clone().project(camera);
      // Symmetric margin keeps the board centred and leaves room for the HUD.
      return Math.abs(p.x) <= 0.94 && Math.abs(p.y) <= 0.86;
    });
  };
  let lo = 8;
  let hi = 90;
  for (let i = 0; i < 28; i++) {
    const mid = (lo + hi) / 2;
    if (fits(mid)) hi = mid;
    else lo = mid;
  }
  state.distance = hi;
  fits(hi);
  camera.lookAt(target);
  return hi;
}

/** Soft studio environment, so gold and clearcoat have something to reflect. */
function buildEnvironment(renderer) {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 128;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createLinearGradient(0, 0, 0, 128);
  gradient.addColorStop(0, '#fff6e2');
  gradient.addColorStop(0.45, '#e9d4ad');
  gradient.addColorStop(0.55, '#8a6a46');
  gradient.addColorStop(1, '#2a1a10');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 256, 128);
  const tex = new THREE.CanvasTexture(canvas);
  tex.mapping = THREE.EquirectangularReflectionMapping;
  tex.colorSpace = THREE.SRGBColorSpace;

  const envScene = new THREE.Scene();
  const sphere = new THREE.Mesh(
    new THREE.SphereGeometry(50, 32, 16),
    new THREE.MeshBasicMaterial({ map: tex, side: THREE.BackSide }),
  );
  envScene.add(sphere);
  const pmrem = new THREE.PMREMGenerator(renderer);
  const env = pmrem.fromScene(envScene, 0.04).texture;
  pmrem.dispose();
  return env;
}

/** Converts a pointer event to normalised device coordinates. */
export function pointerToNdc(event, canvas, out) {
  const rect = canvas.getBoundingClientRect();
  out.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  out.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
  return out;
}
