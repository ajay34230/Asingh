/**
 * Palette, procedural canvas textures and shared PBR materials.
 * Materials are created once and reused by every mesh that needs them.
 */
import * as THREE from '../../vendor/three/three.module.js';

export const PALETTE = Object.freeze({
  red: { main: '#b8202c', deep: '#7e1119', light: '#e0444c', token: '#d62839' },
  green: { main: '#1d8c3d', deep: '#0f5a25', light: '#43b861', token: '#2bb34a' },
  yellow: { main: '#e7a81b', deep: '#a8730c', light: '#f7cd55', token: '#f5b700' },
  blue: { main: '#1f5bbf', deep: '#133c86', light: '#4f8ce6', token: '#2a6fdb' },
  ivory: '#f2ead7',
  ivoryDeep: '#d9cba8',
  gold: '#d9a441',
  goldDeep: '#8f6320',
  foundation: '#7d1a22',
  background: '#2a120c',
});

/** Seeded-looking but stable pseudo-random so textures are identical on every run. */
function makeRandom(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function canvasTexture(size, draw, { repeat = 1, srgb = true } = {}) {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  draw(canvas.getContext('2d'), size);
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(repeat, repeat);
  tex.anisotropy = 4;
  if (srgb) tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

/** Polished marble: base colour, soft clouds, veins and optional gold diamond inlay. */
export function marbleTexture({ base, vein, inlay = null, seed = 1, repeat = 1, size = 512 }) {
  return canvasTexture(size, (ctx, s) => {
    const rnd = makeRandom(seed);
    ctx.fillStyle = base;
    ctx.fillRect(0, 0, s, s);

    for (let i = 0; i < 90; i++) {
      const x = rnd() * s;
      const y = rnd() * s;
      const radius = 20 + rnd() * 90;
      const g = ctx.createRadialGradient(x, y, 0, x, y, radius);
      g.addColorStop(0, vein);
      g.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.globalAlpha = 0.05;
      ctx.fillStyle = g;
      ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
    }

    ctx.strokeStyle = vein;
    for (let i = 0; i < 9; i++) {
      ctx.globalAlpha = 0.16 + rnd() * 0.12;
      ctx.lineWidth = 1 + rnd() * 2.5;
      ctx.beginPath();
      let x = rnd() * s;
      let y = rnd() * s;
      ctx.moveTo(x, y);
      for (let k = 0; k < 4; k++) {
        const nx = x + (rnd() - 0.5) * s * 0.6;
        const ny = y + (rnd() - 0.5) * s * 0.6;
        ctx.bezierCurveTo(x + (rnd() - 0.5) * 120, y + (rnd() - 0.5) * 120, nx - 40, ny + 40, nx, ny);
        x = nx;
        y = ny;
      }
      ctx.stroke();
    }

    if (inlay) {
      ctx.globalAlpha = 0.5;
      ctx.strokeStyle = inlay;
      ctx.lineWidth = 3;
      const step = s / 4;
      for (let i = -4; i <= 8; i++) {
        ctx.beginPath();
        ctx.moveTo(i * step, 0);
        ctx.lineTo(i * step + s, s);
        ctx.moveTo(i * step + s, 0);
        ctx.lineTo(i * step, s);
        ctx.stroke();
      }
      ctx.globalAlpha = 0.9;
      ctx.fillStyle = inlay;
      for (let i = 0; i <= 4; i++) {
        for (let j = 0; j <= 4; j++) {
          ctx.beginPath();
          ctx.arc(i * step, j * step, 5, 0, Math.PI * 2);
          ctx.fill();
        }
      }
    }
    ctx.globalAlpha = 1;
  }, { repeat });
}

/** Soft radial glow used for the lotus halo and the dice halo. */
export function glowTexture() {
  return canvasTexture(256, (ctx, s) => {
    const g = ctx.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    g.addColorStop(0, 'rgba(255,220,130,1)');
    g.addColorStop(0.35, 'rgba(255,190,80,0.45)');
    g.addColorStop(1, 'rgba(255,160,40,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, s, s);
  });
}

/** Creates every shared material. `quality` only affects texture resolution. */
export function createMaterials({ quality = 'high' } = {}) {
  const texSize = quality === 'low' ? 256 : 512;

  const gold = new THREE.MeshStandardMaterial({
    color: PALETTE.gold, metalness: 1, roughness: 0.26,
    emissive: new THREE.Color('#8a5200'), emissiveIntensity: 0.0,
  });
  const goldDark = new THREE.MeshStandardMaterial({ color: PALETTE.goldDeep, metalness: 1, roughness: 0.4 });
  const marbleWhite = new THREE.MeshPhysicalMaterial({
    color: '#ffffff',
    map: marbleTexture({ base: '#f6f1e4', vein: '#b9ab8c', seed: 11, size: texSize }),
    roughness: 0.32, clearcoat: 0.35, clearcoatRoughness: 0.35,
  });
  const ivoryTile = new THREE.MeshPhysicalMaterial({
    color: '#ffffff',
    map: marbleTexture({ base: PALETTE.ivory, vein: '#b49f78', seed: 23, size: texSize, repeat: 0.8 }),
    roughness: 0.36, clearcoat: 0.45, clearcoatRoughness: 0.3,
  });
  const foundation = new THREE.MeshStandardMaterial({
    color: '#ffffff',
    map: marbleTexture({ base: PALETTE.foundation, vein: '#b33a2a', inlay: '#c9953b', seed: 31, size: texSize, repeat: 0.25 }),
    roughness: 0.55,
  });

  const floors = {};
  const laneTiles = {};
  const tokens = {};
  const flagCloth = {};
  for (const color of ['red', 'green', 'yellow', 'blue']) {
    floors[color] = new THREE.MeshPhysicalMaterial({
      color: '#ffffff',
      map: marbleTexture({
        base: PALETTE[color].main, vein: PALETTE[color].light, inlay: PALETTE.gold,
        seed: 40 + color.length * 7, size: texSize, repeat: 1 / 6,
      }),
      roughness: 0.38, clearcoat: 0.5, clearcoatRoughness: 0.25,
    });
    laneTiles[color] = new THREE.MeshPhysicalMaterial({
      color: PALETTE[color].main, roughness: 0.32, clearcoat: 0.5, clearcoatRoughness: 0.25,
    });
    tokens[color] = new THREE.MeshPhysicalMaterial({
      color: PALETTE[color].token, roughness: 0.28, metalness: 0.05, clearcoat: 0.8, clearcoatRoughness: 0.15,
    });
    flagCloth[color] = new THREE.MeshStandardMaterial({ color: PALETTE[color].main, roughness: 0.7, side: THREE.DoubleSide });
  }

  const ruby = new THREE.MeshPhysicalMaterial({
    color: '#c1121f', roughness: 0.08, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.05,
    emissive: new THREE.Color('#5a0008'), emissiveIntensity: 0.4,
  });
  const emeraldStone = new THREE.MeshPhysicalMaterial({ color: '#1f9d55', roughness: 0.1, clearcoat: 1 });
  const sapphireStone = new THREE.MeshPhysicalMaterial({ color: '#1d4ed8', roughness: 0.1, clearcoat: 1 });
  const lanternGlow = new THREE.MeshStandardMaterial({
    color: '#ffd27a', emissive: new THREE.Color('#ffb020'), emissiveIntensity: 0.8, roughness: 0.4,
  });
  const foliage = new THREE.MeshStandardMaterial({ color: '#2f8f3a', roughness: 0.8, flatShading: true });
  const foliageDark = new THREE.MeshStandardMaterial({ color: '#1d6a2a', roughness: 0.85, flatShading: true });
  const petalPink = new THREE.MeshStandardMaterial({ color: '#f472b6', roughness: 0.6 });
  const petalRed = new THREE.MeshStandardMaterial({ color: '#e11d48', roughness: 0.6 });
  const petalWhite = new THREE.MeshStandardMaterial({ color: '#fff7ed', roughness: 0.6 });
  const pot = new THREE.MeshStandardMaterial({ color: '#e8d3a3', roughness: 0.6 });
  const poleMat = new THREE.MeshStandardMaterial({ color: '#e9dcc0', roughness: 0.5 });
  const dark = new THREE.MeshStandardMaterial({ color: '#1a0c08', roughness: 0.9 });
  const pip = new THREE.MeshPhysicalMaterial({ color: '#c1121f', roughness: 0.2, clearcoat: 0.6 });
  const dice = new THREE.MeshPhysicalMaterial({
    color: '#fffdf6', roughness: 0.22, clearcoat: 0.9, clearcoatRoughness: 0.1,
  });
  const burst = new THREE.MeshBasicMaterial({
    color: '#ffd76a', transparent: true, opacity: 0.8, depthWrite: false, blending: THREE.AdditiveBlending,
  });

  return {
    gold, goldDark, marbleWhite, ivoryTile, foundation, floors, laneTiles, tokens, flagCloth,
    ruby, emeraldStone, sapphireStone, lanternGlow, foliage, foliageDark, petalPink, petalRed,
    petalWhite, pot, poleMat, dark, pip, dice, burst,
  };
}
