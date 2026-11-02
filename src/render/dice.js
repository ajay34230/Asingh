/**
 * The 3D dice that sits on the centre lotus. Its rotation is a presentation of
 * a result that was already decided by the game's RNG: the animation tumbles
 * and then settles with the decided face pointing up.
 */
import * as THREE from '../../vendor/three/three.module.js';
import { roundedBoxGeometry } from './geometry.js';
import { easeOutCubic } from './effects.js';

const SIZE = 1.04;
const HOVER_Y = 1.2;
const UP = new THREE.Vector3(0, 1, 0);

/** Local face normal that must point up for each value. Opposite faces sum to 7. */
const FACE_NORMAL = {
  1: new THREE.Vector3(0, 1, 0),
  6: new THREE.Vector3(0, -1, 0),
  2: new THREE.Vector3(0, 0, 1),
  5: new THREE.Vector3(0, 0, -1),
  3: new THREE.Vector3(1, 0, 0),
  4: new THREE.Vector3(-1, 0, 0),
};

const PIP_LAYOUT = {
  1: [[0, 0]],
  2: [[-1, -1], [1, 1]],
  3: [[-1, -1], [0, 0], [1, 1]],
  4: [[-1, -1], [1, -1], [-1, 1], [1, 1]],
  5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]],
  6: [[-1, -1], [-1, 0], [-1, 1], [1, -1], [1, 0], [1, 1]],
};

export class Dice {
  constructor(scene, materials, tweens) {
    this.tweens = tweens;
    this.pivot = new THREE.Group();
    this.pivot.name = 'dice';
    this.pivot.position.set(0, HOVER_Y, 0);
    scene.add(this.pivot);

    const body = new THREE.Mesh(roundedBoxGeometry(SIZE, 0.16, 4), materials.dice);
    body.castShadow = true;
    body.receiveShadow = true;
    this.pivot.add(body);
    this.body = body;

    // Pips: one InstancedMesh holding all face dots, positioned per face value.
    const pipGeo = new THREE.SphereGeometry(0.095, 14, 10);
    const pipInst = new THREE.InstancedMesh(pipGeo, materials.pip, 21);
    const dummy = new THREE.Object3D();
    let n = 0;
    const half = SIZE / 2;
    for (const value of [1, 2, 3, 4, 5, 6]) {
      const normal = FACE_NORMAL[value];
      const u = new THREE.Vector3().crossVectors(normal, Math.abs(normal.y) > 0.5 ? new THREE.Vector3(1, 0, 0) : UP).normalize();
      const v = new THREE.Vector3().crossVectors(normal, u).normalize();
      for (const [x, y] of PIP_LAYOUT[value]) {
        const pos = normal.clone().multiplyScalar(half + 0.005)
          .addScaledVector(u, x * 0.23).addScaledVector(v, y * 0.23);
        dummy.position.copy(pos);
        dummy.updateMatrix();
        pipInst.setMatrixAt(n++, dummy.matrix);
      }
    }
    pipInst.castShadow = false;
    this.pivot.add(pipInst);

    this.shown = 1;
    this.busy = false;
    this.rollId = 0;
    this.setFace(1, 0);
  }

  /** Orientation that shows `value` on top, with a yaw of `quarterTurns` * 90 degrees. */
  faceQuaternion(value, quarterTurns = 0) {
    const map = new THREE.Quaternion().setFromUnitVectors(FACE_NORMAL[value], UP);
    const yaw = new THREE.Quaternion().setFromAxisAngle(UP, quarterTurns * Math.PI / 2);
    return yaw.multiply(map);
  }

  setFace(value, quarterTurns = 0) {
    this.pivot.quaternion.copy(this.faceQuaternion(value, quarterTurns));
    this.shown = value;
  }

  /**
   * Rolls the dice to show `value`. Resolves when the dice has settled.
   * The value is decided by the caller (the game); this only presents it.
   */
  roll(value, rng = Math.random) {
    if (this.busy) return Promise.resolve();
    this.busy = true;
    const id = ++this.rollId;

    const from = this.pivot.quaternion.clone();
    const yaw = Math.floor(rng() * 4);
    const to = this.faceQuaternion(value, yaw);
    const axis = new THREE.Vector3(rng() - 0.5, rng() - 0.5, rng() - 0.5).normalize();
    const spin = new THREE.Quaternion();
    const tumbleSeconds = 1.1;
    const settleSeconds = 0.55;
    const total = tumbleSeconds + settleSeconds;

    return this.tweens.run(total, (_, raw) => {
      const sec = raw * total;
      const e = easeOutCubic(Math.min(sec / tumbleSeconds, 1));
      // Slerp to the target while spinning about a random axis; the spin is a whole number of turns at both ends.
      const turns = 4 * Math.PI * (1 - e);
      spin.setFromAxisAngle(axis, turns);
      this.pivot.quaternion.copy(from).slerp(to, e);
      this.pivot.quaternion.premultiply(spin);

      const lift = Math.sin(Math.PI * Math.min(sec / tumbleSeconds, 1)) * 0.9;
      let bounce = 0;
      if (sec > tumbleSeconds) {
        const b = (sec - tumbleSeconds) / settleSeconds;
        bounce = 0.16 * Math.abs(Math.sin(Math.PI * b * 1.5)) * (1 - b);
      }
      this.pivot.position.y = HOVER_Y + lift + bounce;
    }).then(() => {
      if (id !== this.rollId) return; // superseded by cancel() or a newer roll
      this.pivot.position.y = HOVER_Y;
      this.setFace(value, yaw);
      this.busy = false;
    });
  }

  /** Abandons any roll in flight, e.g. when a new game starts. */
  cancel() {
    this.rollId++;
    this.busy = false;
    this.pivot.position.y = HOVER_Y;
  }

  /** Gentle idle bob while waiting for the player. */
  animate(time) {
    if (this.busy) return;
    this.pivot.position.y = HOVER_Y + Math.sin(time * 1.8) * 0.035;
  }
}
