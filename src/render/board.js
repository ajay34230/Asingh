/**
 * Board foundation, track tiles, courtyard floors, centre triangles, lotus
 * medallion, safe-square stars and home-lane arrows.
 *
 * Track tiles are InstancedMesh (one draw call for all 72 cells). Everything
 * is positioned from layout.js so the visuals always match the rules.
 */
import * as THREE from '../../vendor/three/three.module.js';
import {
  RING, PLAYERS, COLORS, GRID_SIZE, SAFE_RING_INDICES, CENTER_CELL, toWorld, RING_LENGTH,
  BOARD_ASPECT_X,
} from '../game/layout.js';
import {
  flatExtrude, roundedRectShape, chamferedSquareShape, frameShape, starShape, arrowShape,
  petalShape, deg,
} from './geometry.js';
import { PALETTE, glowTexture } from './materials.js';

const FOUNDATION_SIZE = 17.4;
const TILE_HEIGHT = 0.16;
const FLOOR_HEIGHT = 0.12;

/** Direction (world XZ) from a courtyard-style cell toward the board centre. */
function arrowYawFor(dx, dz) {
  // arrowShape points to world -Z by default; yaw is measured about +Y.
  return Math.atan2(-dx, -dz);
}

/** Triangle in world XZ coordinates, returned as a shape in flatExtrude's convention (shape y = -Z). */
function worldTriangle(points) {
  const shape = new THREE.Shape();
  points.forEach(([x, z], i) => (i === 0 ? shape.moveTo(x, -z) : shape.lineTo(x, -z)));
  shape.closePath();
  return shape;
}

function buildFoundation(materials) {
  const group = new THREE.Group();

  const slabShape = roundedRectShape(FOUNDATION_SIZE - 0.24, FOUNDATION_SIZE - 0.24, 0.6);
  const slab = new THREE.Mesh(flatExtrude(slabShape, 1.0, { bevel: 0.12, curveSegments: 14 }), materials.foundation);
  slab.position.y = -1.0;
  slab.receiveShadow = true;
  group.add(slab);

  const goldRim = (outer, inner, y) => {
    const shape = frameShape(roundedRectShape(outer, outer, 0.35), roundedRectShape(inner, inner, 0.3));
    const mesh = new THREE.Mesh(flatExtrude(shape, 0.05, { bevel: 0.01 }), materials.gold);
    mesh.position.y = y;
    mesh.receiveShadow = true;
    return mesh;
  };
  group.add(goldRim(17.0, 16.6, 0.0));
  group.add(goldRim(16.2, 15.9, 0.0));
  group.add(goldRim(15.3, 15.0, 0.0));
  group.add(goldRim(15.0, 14.7, 0.0));
  return group;
}

/** Gold beads along the outer rim and small lotus ornaments at the four corners. */
function buildOrnaments(materials) {
  const group = new THREE.Group();
  const dummy = new THREE.Object3D();

  const beadGeo = new THREE.SphereGeometry(0.1, 12, 8);
  const beadCount = Math.floor((4 * 16.2) / 0.42);
  const beads = new THREE.InstancedMesh(beadGeo, materials.gold, beadCount);
  const half = 16.8 / 2;
  let n = 0;
  const perimeterStep = (4 * 16.8) / beadCount;
  for (let i = 0; i < beadCount; i++) {
    let s = i * perimeterStep;
    let x = 0;
    let z = 0;
    const side = Math.floor(s / 16.8);
    const t = (s - side * 16.8) - half;
    if (side === 0) { x = t; z = -half; }
    else if (side === 1) { x = half; z = t; }
    else if (side === 2) { x = -t; z = half; }
    else { x = -half; z = -t; }
    dummy.position.set(x, 0.07, z);
    dummy.updateMatrix();
    beads.setMatrixAt(n++, dummy.matrix);
  }
  beads.count = n;
  beads.castShadow = false;
  group.add(beads);

  const lobeGeo = new THREE.SphereGeometry(0.11, 10, 8);
  const gemGeo = new THREE.IcosahedronGeometry(0.2, 0);
  const ringGeo = new THREE.TorusGeometry(0.34, 0.06, 8, 24);
  const corners = [[-8.12, -8.12], [8.12, -8.12], [8.12, 8.12], [-8.12, 8.12]];
  corners.forEach(([x, z]) => {
    const ring = new THREE.Mesh(ringGeo, materials.gold);
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(x, 0.1, z);
    group.add(ring);
    const gem = new THREE.Mesh(gemGeo, materials.ruby);
    gem.position.set(x, 0.24, z);
    group.add(gem);
    for (let k = 0; k < 8; k++) {
      const a = (k / 8) * Math.PI * 2;
      const lobe = new THREE.Mesh(lobeGeo, materials.gold);
      lobe.position.set(x + Math.cos(a) * 0.48, 0.08, z + Math.sin(a) * 0.48);
      group.add(lobe);
    }
  });
  return group;
}

function buildTiles(materials) {
  const tileShape = roundedRectShape(0.86, 0.86, 0.14);
  const geo = flatExtrude(tileShape, TILE_HEIGHT, { bevel: 0.03, curveSegments: 6 });
  const mesh = new THREE.InstancedMesh(geo, materials.ivoryTile, RING.length + 20);
  mesh.receiveShadow = true;
  mesh.castShadow = false;

  const dummy = new THREE.Object3D();
  const tint = new THREE.Color();
  let n = 0;
  const place = (c, r, colour) => {
    const { x, z } = toWorld(c + 0.5, r + 0.5);
    dummy.position.set(x, 0, z);
    dummy.updateMatrix();
    mesh.setMatrixAt(n, dummy.matrix);
    mesh.setColorAt(n, tint.set(colour));
    n++;
  };

  RING.forEach((cell, index) => {
    const startOf = COLORS.find((color) => PLAYERS[color].start === index);
    place(cell.c, cell.r, startOf ? PALETTE[startOf].light : '#ffffff');
  });
  for (const color of COLORS) {
    for (const [c, r] of PLAYERS[color].lane) place(c, r, PALETTE[color].light);
  }
  mesh.instanceMatrix.needsUpdate = true;
  mesh.instanceColor.needsUpdate = true;
  return mesh;
}

function buildCourtyards(materials) {
  const group = new THREE.Group();
  for (const color of COLORS) {
    const { home } = PLAYERS[color];
    const centre = toWorld(home.c + 3, home.r + 3);

    const floorShape = chamferedSquareShape(5.7, 0.95);
    const floor = new THREE.Mesh(flatExtrude(floorShape, FLOOR_HEIGHT, { bevel: 0.03 }), materials.floors[color]);
    floor.position.set(centre.x, 0, centre.z);
    floor.receiveShadow = true;
    group.add(floor);

    const frame = frameShape(chamferedSquareShape(6.0, 1.05), chamferedSquareShape(5.7, 0.95));
    const trim = new THREE.Mesh(flatExtrude(frame, 0.15, { bevel: 0.03 }), materials.gold);
    trim.position.set(centre.x, 0, centre.z);
    trim.receiveShadow = true;
    group.add(trim);
  }
  return group;
}

function buildCentre(materials) {
  const group = new THREE.Group();
  const triangles = {
    // Each triangle points at its colour's lane.
    green: [[-1.5, -1.5], [1.5, -1.5], [0, 0]],
    yellow: [[1.5, -1.5], [1.5, 1.5], [0, 0]],
    blue: [[1.5, 1.5], [-1.5, 1.5], [0, 0]],
    red: [[-1.5, 1.5], [-1.5, -1.5], [0, 0]],
  };
  for (const [color, pts] of Object.entries(triangles)) {
    const mesh = new THREE.Mesh(
      flatExtrude(worldTriangle(pts), 0.1, { bevel: 0.01 }),
      new THREE.MeshPhysicalMaterial({ color: PALETTE[color].main, roughness: 0.3, clearcoat: 0.6 }),
    );
    mesh.receiveShadow = true;
    group.add(mesh);
  }

  const base = new THREE.Mesh(
    flatExtrude(chamferedSquareShape(1.0, 0.4), 0.02, { bevel: 0.01 }), materials.gold,
  );
  base.position.y = 0.1;
  group.add(base);

  const engraving = new THREE.Mesh(new THREE.TorusGeometry(1.36, 0.035, 8, 64), materials.gold);
  engraving.rotation.x = -Math.PI / 2;
  engraving.position.y = 0.13;
  group.add(engraving);

  const innerRing = new THREE.Mesh(new THREE.TorusGeometry(0.62, 0.05, 8, 48), materials.gold);
  innerRing.rotation.x = -Math.PI / 2;
  innerRing.position.y = 0.14;
  group.add(innerRing);

  // Lotus: two rings of gold petals, lifted at the tips.
  const petalInner = flatExtrude(petalShape(1.0, 0.27), 0.05, { bevel: 0.02 });
  const petalOuter = flatExtrude(petalShape(1.32, 0.3), 0.05, { bevel: 0.02 });
  const dummy = new THREE.Object3D();
  dummy.rotation.order = 'YXZ';
  const addRing = (geo, count, tilt, offset, y) => {
    const inst = new THREE.InstancedMesh(geo, materials.gold, count);
    for (let k = 0; k < count; k++) {
      dummy.position.set(0, y, 0);
      dummy.rotation.set(tilt, offset + (k / count) * Math.PI * 2, 0);
      dummy.updateMatrix();
      inst.setMatrixAt(k, dummy.matrix);
    }
    inst.castShadow = true;
    group.add(inst);
  };
  addRing(petalInner, 8, deg(-62), 0, 0.14);
  addRing(petalOuter, 8, deg(-38), Math.PI / 8, 0.12);

  const gem = new THREE.Mesh(new THREE.IcosahedronGeometry(0.22, 1), materials.ruby);
  gem.position.y = 0.42;
  gem.castShadow = true;
  group.add(gem);
  const cup = new THREE.Mesh(new THREE.SphereGeometry(0.2, 18, 12, 0, Math.PI * 2, 0, Math.PI / 2), materials.gold);
  cup.position.y = 0.2;
  group.add(cup);

  const halo = new THREE.Mesh(
    new THREE.PlaneGeometry(4.4, 4.4),
    new THREE.MeshBasicMaterial({
      map: glowTexture(), transparent: true, opacity: 0.35, depthWrite: false, blending: THREE.AdditiveBlending,
    }),
  );
  halo.rotation.x = -Math.PI / 2;
  halo.position.y = 0.2;
  halo.renderOrder = 2;
  group.add(halo);
  group.userData.halo = halo;
  return group;
}

function buildMarkers(materials) {
  const group = new THREE.Group();

  const starGeo = flatExtrude(starShape(0.3, 0.13), 0.05, { bevel: 0.015 });
  for (const index of SAFE_RING_INDICES) {
    if (COLORS.some((color) => PLAYERS[color].start === index)) continue;
    const cell = RING[index];
    const { x, z } = toWorld(cell.c + 0.5, cell.r + 0.5);
    const star = new THREE.Mesh(starGeo, materials.gold);
    star.position.set(x, TILE_HEIGHT, z);
    star.castShadow = true;
    group.add(star);
  }

  const arrowGeo = flatExtrude(arrowShape(), 0.03, { bevel: 0.01 });
  for (const color of COLORS) {
    const entry = RING[PLAYERS[color].entry];
    const { x, z } = toWorld(entry.c + 0.5, entry.r + 0.5);
    const centreDir = toWorld(CENTER_CELL.c + 0.5, CENTER_CELL.r + 0.5);
    const arrow = new THREE.Mesh(arrowGeo, materials.laneTiles[color]);
    arrow.position.set(x, TILE_HEIGHT, z);
    arrow.rotation.y = arrowYawFor(centreDir.x - x, centreDir.z - z);
    group.add(arrow);
  }
  return group;
}

/**
 * Builds the complete procedural board. Returns the root group and an update hook for
 * ambient animation (lotus halo breathing and gold shimmer).
 */
export function buildBoard(materials) {
  const root = new THREE.Group();
  root.name = 'board';
  root.scale.x = BOARD_ASPECT_X;

  root.add(buildFoundation(materials));
  root.add(buildOrnaments(materials));
  root.add(buildTiles(materials));
  root.add(buildCourtyards(materials));
  const centre = buildCentre(materials);
  root.add(centre);
  root.add(buildMarkers(materials));

  const halo = centre.userData.halo;
  const goldBase = materials.gold.emissive.clone();

  const update = (time) => {
    halo.material.opacity = 0.28 + 0.1 * Math.sin(time * 1.6);
    materials.gold.emissive.copy(goldBase).multiplyScalar(0.5 + 0.5 * Math.sin(time * 1.1));
    materials.gold.emissiveIntensity = 0.12;
  };

  return { group: root, update, tileCount: RING.length + 20, gridSize: GRID_SIZE, ringLength: RING_LENGTH };
}
