/**
 * Shared geometry helpers. Every shape is built once and instanced or reused,
 * which keeps the board cheap enough for mid-range Android GPUs.
 */
import * as THREE from '../../vendor/three/three.module.js';

/** Centred rounded rectangle path. */
export function roundedRectShape(w, h, radius) {
  const shape = new THREE.Shape();
  const x = -w / 2;
  const y = -h / 2;
  const r = Math.min(radius, w / 2, h / 2);
  shape.moveTo(x + r, y);
  shape.lineTo(x + w - r, y);
  shape.quadraticCurveTo(x + w, y, x + w, y + r);
  shape.lineTo(x + w, y + h - r);
  shape.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  shape.lineTo(x + r, y + h);
  shape.quadraticCurveTo(x, y + h, x, y + h - r);
  shape.lineTo(x, y + r);
  shape.quadraticCurveTo(x, y, x + r, y);
  return shape;
}

/** Centred square with chamfered corners (octagonal courtyard floor). */
export function chamferedSquareShape(size, chamfer) {
  const h = size / 2;
  const c = chamfer;
  const shape = new THREE.Shape();
  shape.moveTo(-h + c, -h);
  shape.lineTo(h - c, -h);
  shape.lineTo(h, -h + c);
  shape.lineTo(h, h - c);
  shape.lineTo(h - c, h);
  shape.lineTo(-h + c, h);
  shape.lineTo(-h, h - c);
  shape.lineTo(-h, -h + c);
  shape.closePath();
  return shape;
}

/** A frame: outer shape with a hole cut from it. */
export function frameShape(outer, inner) {
  outer.holes.push(inner);
  return outer;
}

/**
 * Extrudes a 2D shape into a flat slab that lies on the XZ plane,
 * base at y = 0 and top at y = height. Shape +y maps to world -Z.
 * Bevel is applied symmetrically, so the footprint is the shape plus `bevel`.
 */
export function flatExtrude(shape, height, { bevel = 0, curveSegments = 10 } = {}) {
  const depth = Math.max(height - 2 * bevel, 0.001);
  const geo = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: bevel > 0,
    bevelThickness: bevel,
    bevelSize: bevel,
    bevelSegments: bevel > 0 ? 2 : 0,
    curveSegments,
  });
  geo.translate(0, 0, bevel);
  geo.rotateX(-Math.PI / 2);
  geo.computeVertexNormals();
  return geo;
}

/** Rounded box with a true rounded silhouette (used for the dice). */
export function roundedBoxGeometry(size, radius, segments = 4) {
  const geo = new THREE.BoxGeometry(size, size, size, segments * 2, segments * 2, segments * 2);
  const half = size / 2;
  const inner = half - radius;
  const pos = geo.attributes.position;
  const v = new THREE.Vector3();
  const q = new THREE.Vector3();
  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i);
    q.set(
      THREE.MathUtils.clamp(v.x, -inner, inner),
      THREE.MathUtils.clamp(v.y, -inner, inner),
      THREE.MathUtils.clamp(v.z, -inner, inner),
    );
    const dir = v.clone().sub(q);
    if (dir.lengthSq() > 0) {
      dir.normalize().multiplyScalar(radius);
      v.copy(q).add(dir);
    }
    pos.setXYZ(i, v.x, v.y, v.z);
  }
  geo.computeVertexNormals();
  return geo;
}

export function starShape(outer, inner, points = 5) {
  const shape = new THREE.Shape();
  for (let i = 0; i < points * 2; i++) {
    const radius = i % 2 === 0 ? outer : inner;
    const a = (i / (points * 2)) * Math.PI * 2 + Math.PI / 2;
    const x = Math.cos(a) * radius;
    const y = Math.sin(a) * radius;
    if (i === 0) shape.moveTo(x, y);
    else shape.lineTo(x, y);
  }
  shape.closePath();
  return shape;
}

/** Arrow pointing towards +y in shape space. */
export function arrowShape() {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0.36);
  shape.lineTo(0.26, -0.02);
  shape.lineTo(0.09, -0.02);
  shape.lineTo(0.09, -0.36);
  shape.lineTo(-0.09, -0.36);
  shape.lineTo(-0.09, -0.02);
  shape.lineTo(-0.26, -0.02);
  shape.closePath();
  return shape;
}

/** Lotus petal pointing towards +y, base at origin. */
export function petalShape(length, width) {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0);
  shape.bezierCurveTo(width, length * 0.25, width * 0.9, length * 0.8, 0, length);
  shape.bezierCurveTo(-width * 0.9, length * 0.8, -width, length * 0.25, 0, 0);
  return shape;
}

/** Degrees to radians shorthand. */
export const deg = (d) => (d * Math.PI) / 180;
