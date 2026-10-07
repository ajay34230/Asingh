"""Generates the placeholder editorial imagery (procedural fabric studies) in
multiple widths and formats (AVIF + WebP + JPEG fallback) for srcset delivery.
Run: python3 tools/gen_images.py
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "img")
os.makedirs(OUT, exist_ok=True)

PRODUCTS = {
    # slug: (base colour, accent colour, motif)
    "noor-lehenga":    ("#7a1f3d", "#e9c46a", "floral"),
    "zarina-anarkali": ("#14463c", "#d9b779", "paisley"),
    "mehr-saree":      ("#b5532f", "#f2d9a0", "stripe"),
    "ishani-suit":     ("#2c3a6b", "#e8d5b5", "buti"),
    "rani-sharara":    ("#c23a6e", "#f6e3b4", "floral"),
    "saanvi-kurta":    ("#e8d9c0", "#8a5a3c", "buti"),
    "aarohi-gown":     ("#3d2a55", "#cfae6b", "paisley"),
    "meera-saree":     ("#1d5b6b", "#f0d9a6", "stripe"),
    "kiara-lehenga":   ("#d98b8b", "#fff1d6", "floral"),
    "tara-palazzo":    ("#a7752e", "#2b1d12", "buti"),
    "devika-anarkali": ("#4f5d3a", "#e7cf94", "paisley"),
    "vanya-dupatta":   ("#8f2a2a", "#f5d98e", "stripe"),
}
WIDTHS = [400, 800, 1200]
BASE_W, BASE_H = 1200, 1500


def hex2rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def fabric(w, h, base, accent, motif, seed, view):
    rng = random.Random(seed)
    base_c, acc_c = hex2rgb(base), hex2rgb(accent)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    # drape: layered sine folds
    f1, f2, f3 = rng.uniform(2.2, 3.4), rng.uniform(5, 8), rng.uniform(11, 16)
    p1, p2, p3 = (rng.uniform(0, 6.28) for _ in range(3))
    zoom = {"full": 1.0, "detail": 2.4, "flat": 0.35}[view]
    xs = x / w * zoom
    ys = y / h * zoom
    fold = (np.sin(xs * f1 * 6.28 + 0.8 * np.sin(ys * 3 + p1) + p1) * 0.5
            + np.sin(xs * f2 * 6.28 + 0.5 * np.sin(ys * 5 + p2) + p2) * 0.28
            + np.sin(xs * f3 * 6.28 + p3) * 0.12)
    shade = 0.78 + 0.22 * fold
    # soft vignette & gradient
    vg = 1 - 0.35 * (((x / w - 0.5) ** 2 + (y / h - 0.45) ** 2) * 2.2)
    img = base_c[None, None, :] * (shade * vg)[..., None]
    # motif layer
    layer = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(layer)
    step = int(w / (7 if view != "detail" else 3.2))
    if view == "flat":
        step = int(w / 14)
    for gy in range(-step, h + step, step):
        for gx in range(-step, w + step, step):
            ox = gx + (step // 2 if (gy // step) % 2 else 0)
            r = step * 0.16
            if motif == "floral":
                for a in range(6):
                    ang = a * math.pi / 3
                    d.ellipse([ox + math.cos(ang) * r - r * .55, gy + math.sin(ang) * r - r * .55,
                               ox + math.cos(ang) * r + r * .55, gy + math.sin(ang) * r + r * .55], fill=255)
                d.ellipse([ox - r * .4, gy - r * .4, ox + r * .4, gy + r * .4], fill=0)
            elif motif == "paisley":
                d.ellipse([ox - r, gy - r * 1.4, ox + r, gy + r * 1.4], fill=255)
                d.ellipse([ox - r * .6, gy - r * .9, ox + r * .6, gy + r * .9], fill=0)
                d.ellipse([ox - r * .2, gy - r * .3, ox + r * .2, gy + r * .3], fill=255)
            elif motif == "buti":
                d.polygon([(ox, gy - r), (ox + r, gy), (ox, gy + r), (ox - r, gy)], fill=255)
                d.ellipse([ox - r * .3, gy - r * .3, ox + r * .3, gy + r * .3], fill=0)
            else:  # stripe
                d.rectangle([ox - step // 2, gy, ox + step // 2, gy + max(3, step // 14)], fill=255)
    layer = layer.filter(ImageFilter.GaussianBlur(0.8))
    m = (np.asarray(layer, dtype=np.float32) / 255.0)[..., None] * 0.85
    # zari sheen on motifs
    sheen = (0.75 + 0.25 * fold)[..., None]
    img = img * (1 - m) + acc_c[None, None, :] * sheen * m
    # border band on the full view (bottom hem)
    if view == "full":
        hem = np.clip((y - h * 0.82) / (h * 0.02), 0, 1)[..., None]
        band = (np.sin(x / w * 90) * 0.5 + 0.5)[..., None]
        img = img * (1 - hem * 0.55) + acc_c[None, None, :] * (0.55 + 0.25 * band) * hem * 0.55
    # grain
    noise = np.random.default_rng(seed).normal(0, 3.0, (h, w, 1)).astype(np.float32)
    img = np.clip(img + noise, 0, 255).astype(np.uint8)
    return Image.fromarray(img, "RGB")


def save_set(im, name, widths, ratio):
    for wd in widths:
        ht = round(wd * ratio)
        r = im.resize((wd, ht), Image.LANCZOS)
        r.save(os.path.join(OUT, f"{name}-{wd}.avif"), quality=48)
        r.save(os.path.join(OUT, f"{name}-{wd}.webp"), quality=74, method=5)
        r.save(os.path.join(OUT, f"{name}-{wd}.jpg"), quality=76, optimize=True, progressive=True)


for i, (slug, (b, a, m)) in enumerate(PRODUCTS.items()):
    for j, view in enumerate(["full", "detail", "flat"]):
        im = fabric(BASE_W, BASE_H, b, a, m, seed=i * 10 + j + 1, view=view)
        save_set(im, f"{slug}-{j + 1}", WIDTHS, BASE_H / BASE_W)

# Hero: art-directed — wide (landscape) and tall (portrait) crops
def hero(w, h, seed):
    base = fabric(w, h, "#3b1022", "#d8b36a", "paisley", seed, "full")
    return base

wide = hero(2560, 1280, 91)
save_set(wide, "hero-wide", [1280, 1920, 2560, 3840], 0.5)
tall = hero(1080, 1350, 92)
save_set(tall, "hero-tall", [480, 800, 1080], 1.25)
# Editorial tiles
for k, (slug, (b, a, m)) in enumerate(list(PRODUCTS.items())[:4]):
    im = fabric(1200, 1200, b, a, m, 200 + k, "detail")
    save_set(im, f"collection-{k + 1}", [400, 800, 1200], 1.0)
print("done", len(os.listdir(OUT)), "files")
