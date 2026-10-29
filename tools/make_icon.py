#!/usr/bin/env python3
"""Draws the app icon (own artwork): a golden twelve-ray sun rising behind the sealed Sun Gate
between two stone pylons, over desert dunes and a starry dusk sky. Outputs icon.png (512),
and adaptive-icon layers (432). Run: python3 tools/make_icon.py"""
import math, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 2048  # supersampled canvas


def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sky():
    im = Image.new("RGB", (S, S))
    px = im.load()
    top, mid, hor = (22, 18, 56), (150, 60, 90), (255, 170, 80)
    for y in range(S):
        t = y / (S * 0.72)
        c = lerp(top, mid, t / 0.6) if t < 0.6 else lerp(mid, hor, min(1.0, (t - 0.6) / 0.4))
        for x in range(S):
            px[x, y] = c
    d = ImageDraw.Draw(im)
    random.seed(4)
    for _ in range(140):
        x, y = random.randrange(S), random.randrange(int(S * 0.38))
        r = random.choice([2, 3, 3, 4, 6])
        a = 255 - int(y / (S * 0.38) * 170)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 245, 220))
    return im


def glow(size, cx, cy, r, col, strength):
    g = Image.new("RGB", (size, size), (0, 0, 0))
    d = ImageDraw.Draw(g)
    for i in range(40, 0, -1):
        k = i / 40
        c = tuple(int(v * (1 - k) ** 1.6 * strength) for v in col)
        rr = r * (0.2 + k * 1.3)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=c)
    return g.filter(ImageFilter.GaussianBlur(40))


def draw_foreground(include_dunes=True):
    """RGBA layer: sun, gate, pylons, dunes (everything except the sky)."""
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(fg)
    cx, cy = S // 2, int(S * 0.47)
    # sun rays (12)
    for k in range(12):
        a = k * math.tau / 12 + math.pi / 12
        w = 0.085
        p = [(cx, cy),
             (cx + math.cos(a - w) * S * 0.62, cy + math.sin(a - w) * S * 0.62),
             (cx + math.cos(a + w) * S * 0.62, cy + math.sin(a + w) * S * 0.62)]
        d.polygon(p, fill=(255, 205, 90, 120 if k % 2 else 170))
    # sun disc with rings
    for r, col in [(0.30, (255, 190, 80)), (0.255, (255, 214, 110)), (0.21, (255, 236, 160))]:
        rr = S * r
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col + (255,))
    # gate: pylons and lintel
    stone, stone_dk, stone_lt = (118, 88, 62), (70, 50, 38), (170, 132, 96)
    gw, gh = S * 0.38, S * 0.40
    gx0, gx1, gy1 = cx - gw / 2, cx + gw / 2, S * 0.88
    gy0 = gy1 - gh
    pw = S * 0.11
    for x0 in (gx0 - pw, gx1):
        d.rectangle([x0, gy0 - S * 0.04, x0 + pw, gy1], fill=stone)
        d.rectangle([x0, gy0 - S * 0.04, x0 + pw * 0.28, gy1], fill=stone_lt)
        d.rectangle([x0 + pw * 0.8, gy0 - S * 0.04, x0 + pw, gy1], fill=stone_dk)
        d.rectangle([x0 - S * 0.012, gy0 - S * 0.07, x0 + pw + S * 0.012, gy0 - S * 0.04], fill=stone_lt)
    d.rectangle([gx0 - pw, gy0 - S * 0.115, gx1 + pw, gy0 - S * 0.07], fill=stone)
    d.rectangle([gx0 - pw - S * 0.015, gy0 - S * 0.145, gx1 + pw + S * 0.015, gy0 - S * 0.115], fill=stone_lt)
    # door with glowing seams and three golden seal discs
    d.rectangle([gx0, gy0, gx1, gy1], fill=(44, 30, 24))
    for i, c in enumerate([(255, 196, 90), (255, 160, 60)]):
        d.rectangle([cx - S * 0.006 - i * S * 0.0, gy0, cx + S * 0.006, gy1], fill=(255, 190, 80))
    for k in (1, 2, 3):
        y = gy0 + gh * k / 4
        d.rectangle([gx0, y - S * 0.006, gx1, y + S * 0.006], fill=(196, 140, 70))
    for dx in (-0.13, 0.0, 0.13):
        r = S * 0.043
        x, y = cx + S * dx * 0.9, gy0 + gh * 0.5
        d.ellipse([x - r * 1.5, y - r * 1.5, x + r * 1.5, y + r * 1.5], fill=(255, 190, 80, 90))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 218, 110), outline=(150, 90, 30), width=8)
        d.ellipse([x - r * 0.4, y - r * 0.4, x + r * 0.4, y + r * 0.4], fill=(180, 110, 40))
    # stairs
    for i in range(5):
        y = gy1 + i * S * 0.012
        d.rectangle([gx0 - pw - i * S * 0.03, y, gx1 + pw + i * S * 0.03, y + S * 0.012], fill=lerp(stone_lt, stone_dk, i / 5) + (255,))
    # dunes
    if include_dunes:
        for base, col, amp, ph in [(0.80, (210, 140, 78), 0.05, 0.0), (0.86, (170, 104, 62), 0.045, 1.7), (0.93, (110, 66, 48), 0.05, 3.1)]:
            pts = [(0, S)]
            for x in range(0, S + 16, 16):
                y = S * base + math.sin(x / S * 5.2 + ph) * S * amp + math.sin(x / S * 11 + ph) * S * amp * 0.25
                pts.append((x, y))
            pts.append((S, S))
            # dunes are painted under the gate first
            layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
            ImageDraw.Draw(layer).polygon(pts, fill=col + (255,))
            if base < 0.9:
                fg = Image.alpha_composite(layer, fg)
            else:
                fg = Image.alpha_composite(fg, layer)
    return fg


def compose():
    bg = sky()
    cx, cy = S // 2, int(S * 0.47)
    g = glow(S, cx, cy, S * 0.4, (255, 150, 60), 1.0)
    bg = ImageChops.add(bg, g)
    fg = draw_foreground()
    out = bg.convert("RGBA")
    out = Image.alpha_composite(out, fg)
    return bg, fg, out.convert("RGB")


bg, fg, full = compose()
full.resize((512, 512), Image.LANCZOS).save("icon.png")
full.resize((192, 192), Image.LANCZOS).save("icon_192.png")
# adaptive icon layers: foreground is inset into the 66% safe zone
bg.resize((432, 432), Image.LANCZOS).save("icon_adaptive_bg.png")
inset = Image.new("RGBA", (S, S), (0, 0, 0, 0))
small = fg.resize((int(S * 0.72), int(S * 0.72)), Image.LANCZOS)
inset.paste(small, ((S - small.width) // 2, (S - small.height) // 2), small)
inset.resize((432, 432), Image.LANCZOS).save("icon_adaptive_fg.png")
print("icons written")
