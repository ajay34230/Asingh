/**
 * Token meshes. Each colour has four pawns that share one body geometry and one
 * material. Each token also has an invisible pick proxy, which makes tapping on
 * a phone reliable without hitting the thin silhouette.
 */
import * as THREE from '../../vendor/three/three.module.js';
import { COLORS, TOKENS_PER_PLAYER, progressPoint, toWorld } from '../game/layout.js';

const TOKEN_SCALE = 0.9;
export const TRACK_Y = 0.16;
export const BASE_Y = 0.15;

function pawnGeometries() {
  const profile = [
    [0, 0], [0.31, 0], [0.33, 0.05], [0.27, 0.12], [0.17, 0.2], [0.13, 0.3],
    [0.2, 0.36], [0.22, 0.41], [0.14, 0.46], [0, 0.48],
  ].map(([x, y]) => new THREE.Vector2(x, y));
  return {
    body: new THREE.LatheGeometry(profile, 24),
    head: new THREE.SphereGeometry(0.17, 20, 14),
    collar: new THREE.TorusGeometry(0.3, 0.035, 8, 28),
    ring: new THREE.RingGeometry(0.36, 0.44, 32),
    pick: new THREE.CylinderGeometry(0.4, 0.4, 0.9, 10),
  };
}

export class Token {
  constructor(color, index, geo, materials) {
    this.color = color;
    this.index = index;
    this.root = new THREE.Group();
    this.root.name = `token-${color}-${index}`;
    this.progress = 0;

    const body = new THREE.Mesh(geo.body, materials.tokens[color]);
    body.castShadow = true;
    body.receiveShadow = true;
    const head = new THREE.Mesh(geo.head, materials.tokens[color]);
    head.position.y = 0.6;
    head.castShadow = true;
    const collar = new THREE.Mesh(geo.collar, materials.gold);
    collar.rotation.x = -Math.PI / 2;
    collar.position.y = 0.05;
    this.model = new THREE.Group();
    this.model.add(body, head, collar);
    this.model.scale.setScalar(TOKEN_SCALE);
    this.root.add(this.model);

    this.marker = new THREE.Mesh(geo.ring, materials.gold);
    this.marker.rotation.x = -Math.PI / 2;
    this.marker.position.y = 0.02;
    this.marker.visible = false;
    this.root.add(this.marker);

    this.pick = new THREE.Mesh(geo.pick, new THREE.MeshBasicMaterial({ visible: false }));
    this.pick.position.y = 0.45;
    this.pick.userData.token = this;
    this.root.add(this.pick);

    this.highlighted = false;
    this.phase = index * 1.3;
  }

  /** Places the token at a world position (x, z) with its base at height y. */
  setPosition(x, y, z) {
    this.root.position.set(x, y, z);
  }

  placeAtProgress(progress) {
    this.progress = progress;
    const { gx, gy } = progressPoint(this.color, progress, this.index);
    const { x, z } = toWorld(gx, gy);
    this.setPosition(x, progress === 0 ? BASE_Y : TRACK_Y, z);
  }

  setHighlight(on) {
    this.highlighted = on;
    this.marker.visible = on;
  }

  /** Idle bob for highlighted tokens; a gentle breathing for the rest. */
  animate(time) {
    const lift = this.highlighted ? 0.12 + 0.06 * Math.sin(time * 5 + this.phase) : 0;
    this.model.position.y = lift;
    if (this.highlighted) {
      this.marker.scale.setScalar(1 + 0.08 * Math.sin(time * 5 + this.phase));
    }
  }
}

/** Creates all 16 tokens and returns them grouped by colour. */
export function createTokens(materials) {
  const geo = pawnGeometries();
  const byColor = {};
  const all = [];
  for (const color of COLORS) {
    byColor[color] = [];
    for (let i = 0; i < TOKENS_PER_PLAYER; i++) {
      const token = new Token(color, i, geo, materials);
      byColor[color].push(token);
      all.push(token);
    }
  }
  return { byColor, all, geo };
}
