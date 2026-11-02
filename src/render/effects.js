/**
 * Tween scheduler plus lightweight effects (capture bursts and victory
 * confetti). Everything here is frame-driven from the render loop, so the
 * game logic never depends on timers or animation callbacks.
 */
import * as THREE from '../../vendor/three/three.module.js';
import { PALETTE } from './materials.js';

export const easeOutCubic = (t) => 1 - (1 - t) ** 3;
export const easeInOutQuad = (t) => (t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2);

export class Tweens {
  constructor() {
    this.items = [];
  }

  /**
   * Runs `update(t)` for `duration` seconds with t going 0 -> 1, then resolves.
   * `update` receives the already-eased value when `ease` is given.
   */
  run(duration, update, ease = (t) => t) {
    return new Promise((resolve) => {
      this.items.push({ elapsed: 0, duration, update, ease, resolve });
    });
  }

  wait(seconds) {
    return this.run(seconds, () => {});
  }

  update(dt) {
    if (this.items.length === 0) return;
    const remaining = [];
    for (const item of this.items) {
      item.elapsed += dt;
      const raw = Math.min(item.elapsed / item.duration, 1);
      item.update(item.ease(raw), raw);
      if (raw >= 1) item.resolve();
      else remaining.push(item);
    }
    this.items = remaining;
  }

  clear() {
    for (const item of this.items) item.resolve();
    this.items = [];
  }
}

/** Expanding golden ring plus sparkles, used for captures and home entry. */
export class SparkBurst {
  constructor(scene, count = 14) {
    this.group = new THREE.Group();
    scene.add(this.group);
    this.ring = new THREE.Mesh(
      new THREE.RingGeometry(0.2, 0.32, 36),
      new THREE.MeshBasicMaterial({ color: '#ffd76a', transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide }),
    );
    this.ring.rotation.x = -Math.PI / 2;
    this.group.add(this.ring);

    this.particles = new THREE.InstancedMesh(
      new THREE.OctahedronGeometry(0.06, 0),
      new THREE.MeshBasicMaterial({ color: '#fff1b8', transparent: true, opacity: 1, depthWrite: false }),
      count,
    );
    this.particles.count = 0;
    this.group.add(this.particles);
    this.velocities = [];
    this.life = 0;
    this.dummy = new THREE.Object3D();
    this.active = false;
  }

  fire(x, y, z, tweens) {
    this.group.position.set(x, y, z);
    this.life = 0;
    this.active = true;
    this.ring.material.opacity = 0.9;
    this.velocities = [];
    const n = this.particles.instanceMatrix.count;
    this.particles.count = n;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2;
      this.velocities.push(new THREE.Vector3(Math.cos(a) * 1.4, 1.2 + Math.random() * 1.2, Math.sin(a) * 1.4));
    }
    return tweens.run(0.7, (t) => {
      this.life = t;
      this.ring.scale.setScalar(1 + t * 3.2);
      this.ring.material.opacity = 0.9 * (1 - t);
      this.particles.material.opacity = 1 - t;
      for (let i = 0; i < n; i++) {
        const v = this.velocities[i];
        this.dummy.position.set(v.x * t * 0.9, v.y * t * 0.5 - 2.2 * t * t, v.z * t * 0.9);
        this.dummy.scale.setScalar(1 - t * 0.6);
        this.dummy.updateMatrix();
        this.particles.setMatrixAt(i, this.dummy.matrix);
      }
      this.particles.instanceMatrix.needsUpdate = true;
    }).then(() => {
      this.ring.material.opacity = 0;
      this.particles.count = 0;
      this.active = false;
    });
  }
}

/** Victory confetti: one InstancedMesh, simulated on the CPU. */
export class Confetti {
  constructor(scene, count = 160) {
    this.count = count;
    const geo = new THREE.PlaneGeometry(0.12, 0.07);
    this.mesh = new THREE.InstancedMesh(geo, new THREE.MeshBasicMaterial({ side: THREE.DoubleSide }), count);
    this.mesh.visible = false;
    this.mesh.frustumCulled = false;
    scene.add(this.mesh);
    this.parts = [];
    this.dummy = new THREE.Object3D();
    const palette = [PALETTE.red.light, PALETTE.green.light, PALETTE.yellow.light, PALETTE.blue.light, '#ffffff', PALETTE.gold];
    const tint = new THREE.Color();
    for (let i = 0; i < count; i++) {
      this.mesh.setColorAt(i, tint.set(palette[i % palette.length]));
    }
    this.mesh.instanceColor.needsUpdate = true;
    this.timer = 0;
  }

  start() {
    this.timer = 4;
    this.mesh.visible = true;
    this.parts = [];
    for (let i = 0; i < this.count; i++) {
      this.parts.push({
        p: new THREE.Vector3((Math.random() - 0.5) * 6, 5 + Math.random() * 3, (Math.random() - 0.5) * 6),
        v: new THREE.Vector3((Math.random() - 0.5) * 1.2, -(0.8 + Math.random() * 0.6), (Math.random() - 0.5) * 1.2),
        spin: Math.random() * 10,
      });
    }
  }

  stop() {
    this.timer = 0;
    this.mesh.visible = false;
  }

  update(dt, time) {
    if (this.timer <= 0) return;
    this.timer -= dt;
    for (let i = 0; i < this.count; i++) {
      const part = this.parts[i];
      if (!part) continue;
      part.v.y -= 0.9 * dt;
      part.p.addScaledVector(part.v, dt);
      if (part.p.y < 0.2) {
        part.p.y = 0.2;
        part.v.y = Math.abs(part.v.y) * 0.25;
      }
      this.dummy.position.copy(part.p);
      this.dummy.rotation.set(time * 3 + part.spin, time * 2 + part.spin, 0);
      this.dummy.updateMatrix();
      this.mesh.setMatrixAt(i, this.dummy.matrix);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
    if (this.timer <= 0) this.mesh.visible = false;
  }
}
