/**
 * Palace architecture for each courtyard: domed chhatri pavilion, arches,
 * columns, steps, lanterns, potted plants and a flag. Everything stays inside
 * the courtyard, so nothing can obstruct the track.
 *
 * Geometry is built once and shared; the four courtyards use the same meshes
 * with different transforms.
 */
import * as THREE from '../../vendor/three/three.module.js';
import { COLORS, courtyardCentre, toWorld } from '../game/layout.js';
import { roundedRectShape, flatExtrude } from './geometry.js';

const FLOOR_TOP = 0.15;

/** Shared geometry for every pavilion. */
function pavilionGeometry() {
  const domeProfile = [
    [0, 0], [0.46, 0.02], [0.6, 0.2], [0.6, 0.42], [0.42, 0.62], [0.22, 0.78], [0.1, 0.9], [0, 0.97],
  ].map(([x, y]) => new THREE.Vector2(x, y));
  return {
    platform: new THREE.BoxGeometry(2.1, 0.14, 2.1),
    step: new THREE.BoxGeometry(1.2, 0.07, 0.3),
    column: new THREE.CylinderGeometry(0.075, 0.09, 0.72, 12),
    capital: new THREE.BoxGeometry(0.22, 0.07, 0.22),
    drum: new THREE.CylinderGeometry(0.86, 0.9, 0.16, 20),
    dome: new THREE.LatheGeometry(domeProfile, 24),
    finialStem: new THREE.CylinderGeometry(0.035, 0.05, 0.3, 8),
    finialBall: new THREE.SphereGeometry(0.075, 12, 8),
    arch: new THREE.TorusGeometry(0.42, 0.045, 8, 18, Math.PI),
    lantern: new THREE.SphereGeometry(0.1, 12, 10),
    railBar: new THREE.BoxGeometry(2.0, 0.035, 0.035),
  };
}

function plantGeometry() {
  const potProfile = [
    [0, 0], [0.22, 0], [0.28, 0.12], [0.3, 0.24], [0.26, 0.3], [0.22, 0.3],
  ].map(([x, y]) => new THREE.Vector2(x, y));
  return {
    pot: new THREE.LatheGeometry(potProfile, 14),
    leaf: new THREE.IcosahedronGeometry(0.2, 0),
    bloom: new THREE.SphereGeometry(0.06, 8, 6),
  };
}

/** Pennant geometry: a subdivided plane whose vertices ripple over time. */
function flagGeometry() {
  const geo = new THREE.PlaneGeometry(0.62, 0.4, 8, 3);
  geo.translate(0.31, 0, 0);
  return geo;
}

function buildPavilion(geo, materials) {
  const group = new THREE.Group();
  const add = (g, m, x, y, z, cast = true) => {
    const mesh = new THREE.Mesh(g, m);
    mesh.position.set(x, y, z);
    mesh.castShadow = cast;
    mesh.receiveShadow = true;
    group.add(mesh);
    return mesh;
  };

  add(geo.platform, materials.marbleWhite, 0, FLOOR_TOP + 0.07, 0);
  // Steps on the front edge (+z, which faces the board centre once rotated).
  add(geo.step, materials.marbleWhite, 0, FLOOR_TOP + 0.035, 1.2);
  add(geo.step, materials.marbleWhite, 0, FLOOR_TOP + 0.105, 1.08);

  const colTop = FLOOR_TOP + 0.14 + 0.36;
  for (const [x, z] of [[-0.8, -0.8], [0.8, -0.8], [-0.8, 0.8], [0.8, 0.8]]) {
    add(geo.column, materials.marbleWhite, x, colTop, z);
    add(geo.capital, materials.gold, x, colTop + 0.395, z);
  }
  // Gold rail along the back edge.
  add(geo.railBar, materials.gold, 0, FLOOR_TOP + 0.3, -1.0);

  // Arches on the front and back pairs of columns.
  add(geo.arch, materials.marbleWhite, 0, FLOOR_TOP + 0.14, 0.8, true);
  add(geo.arch, materials.marbleWhite, 0, FLOOR_TOP + 0.14, -0.8, true);

  const drumY = FLOOR_TOP + 0.14 + 0.72 + 0.08;
  add(geo.drum, materials.gold, 0, drumY, 0);
  add(geo.dome, materials.marbleWhite, 0, drumY + 0.08, 0);

  const domeTop = drumY + 0.08 + 0.97;
  add(geo.finialStem, materials.gold, 0, domeTop + 0.15, 0);
  add(geo.finialBall, materials.gold, 0, domeTop + 0.34, 0);

  add(geo.lantern, materials.lanternGlow, 0, FLOOR_TOP + 0.5, 0.95, false);
  return group;
}

function buildPlant(geo, materials) {
  const group = new THREE.Group();
  const pot = new THREE.Mesh(geo.pot, materials.pot);
  pot.castShadow = true;
  group.add(pot);

  const foliage = new THREE.Group();
  const leaves = [
    [0, 0.5, 0, 0.42, materials.foliage],
    [0.18, 0.42, 0.1, 0.3, materials.foliageDark],
    [-0.16, 0.44, -0.1, 0.3, materials.foliage],
    [0.05, 0.62, -0.1, 0.26, materials.foliage],
  ];
  for (const [x, y, z, s, m] of leaves) {
    const leaf = new THREE.Mesh(geo.leaf, m);
    leaf.position.set(x, y, z);
    leaf.scale.setScalar(s / 0.2);
    leaf.castShadow = true;
    foliage.add(leaf);
  }
  const blooms = [materials.petalPink, materials.petalRed, materials.petalWhite];
  [[0.2, 0.7, 0.14], [-0.18, 0.66, 0.12], [0.02, 0.8, 0.02], [-0.12, 0.56, -0.2], [0.24, 0.56, -0.12]].forEach(([x, y, z], i) => {
    const bloom = new THREE.Mesh(geo.bloom, blooms[i % blooms.length]);
    bloom.position.set(x, y, z);
    foliage.add(bloom);
  });
  foliage.userData.sway = Math.random() * Math.PI * 2;
  group.add(foliage);
  group.userData.foliage = foliage;
  return group;
}

/** Builds the pavilion, plants and flag for one courtyard, facing the board centre. */
function buildCourtyardDecor(color, shared, materials) {
  const group = new THREE.Group();
  const { gx, gy } = courtyardCentre(color);
  const centre = toWorld(gx, gy);
  group.position.set(centre.x, 0, centre.z);

  // Snap to the nearest quarter turn so the square platform stays axis-aligned.
  const quarter = Math.PI / 2;
  const toBoard = Math.round(Math.atan2(-centre.x, -centre.z) / quarter) * quarter;
  const pavilion = buildPavilion(shared.pavilion, materials);
  pavilion.rotation.y = toBoard;
  group.add(pavilion);

  for (const sx of [-2.4, 2.4]) {
    const plant = buildPlant(shared.plant, materials);
    plant.position.set(sx, FLOOR_TOP, 0);
    plant.rotation.y = sx * 0.3;
    group.add(plant);
    group.userData.plants = [...(group.userData.plants ?? []), plant];
  }

  // Flag on a pole at the back edge of the courtyard, away from the token spots.
  const flag = new THREE.Group();
  const pole = new THREE.Mesh(shared.pole, materials.poleMat);
  pole.position.y = 1.0;
  pole.castShadow = true;
  flag.add(pole);
  const cloth = new THREE.Mesh(shared.flag, materials.flagCloth[color]);
  cloth.position.set(0.0, 1.9, 0);
  cloth.castShadow = true;
  flag.add(cloth);
  group.userData.cloth = cloth;
  const ball = new THREE.Mesh(shared.finialBall, materials.gold);
  ball.position.y = 2.1;
  flag.add(ball);
  flag.position.set(0, FLOOR_TOP, -2.45);
  group.add(flag);

  return group;
}

/**
 * Builds all four courtyard palaces and returns an update hook that animates
 * flags, plants and lanterns.
 */
export function buildPalaces(materials) {
  const shared = {
    pavilion: pavilionGeometry(),
    plant: plantGeometry(),
    flag: flagGeometry(),
    pole: new THREE.CylinderGeometry(0.03, 0.035, 2.2, 8),
    finialBall: new THREE.SphereGeometry(0.08, 10, 8),
  };
  const root = new THREE.Group();
  root.name = 'palaces';
  const decors = {};
  for (const color of COLORS) {
    const decor = buildCourtyardDecor(color, shared, materials);
    decors[color] = decor;
    root.add(decor);
  }

  // All four flags share one geometry, so the ripple is computed once per frame.
  const clothBase = shared.flag.attributes.position.array.slice();
  const clothPos = shared.flag.attributes.position;

  const update = (time) => {
    for (let i = 0; i < clothPos.count; i++) {
      const x = clothBase[i * 3];
      clothPos.setZ(i, Math.sin(time * 4 + x * 5) * 0.035 * x);
    }
    clothPos.needsUpdate = true;
    for (const color of COLORS) {
      for (const plant of decors[color].userData.plants || []) {
        const foliage = plant.userData.foliage;
        foliage.rotation.z = Math.sin(time * 1.3 + foliage.userData.sway) * 0.035;
      }
    }
    materials.lanternGlow.emissiveIntensity = 0.7 + 0.25 * Math.sin(time * 2.2);
  };

  return { group: root, update, decors };
}
