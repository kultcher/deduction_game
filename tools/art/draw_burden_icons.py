#!/usr/bin/env python3
"""Draws assets/ui/roles/unrequited.png and ill_omened.png in the role icons' ink-and-gold stamp
style (Limner, Nov 21). Run from any directory: python3 tools/art/draw_burden_icons.py
Writes the icons, plus sheet.png comparing them with existing icons, into the current directory."""
import math
import os
from PIL import Image, ImageDraw
INK = (13, 21, 30, 255); GOLD = (210, 150, 60, 255); CREAM = (235, 207, 170, 255)
S = 1200; OUT = 300
def heart(cx, cy, r, n=200):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + x * r / 16, cy + y * r / 16))
    return pts
def rot(pts, ang, ox, oy):
    a = math.radians(ang); c, s = math.cos(a), math.sin(a)
    return [(ox + (x - ox) * c - (y - oy) * s, oy + (x - ox) * s + (y - oy) * c) for x, y in pts]
def crack_line(top, bottom, n=7, amp=38):
    pts = []
    for i in range(n + 1):
        t = i / n; y = top[1] + (bottom[1] - top[1]) * t
        x = top[0] + (bottom[0] - top[0]) * t + (amp if i % 2 else -amp) * (0 if i in (0, n) else 1)
        pts.append((x, y))
    return pts
def mask_side(pts_heart, crack, left=True):
    """The heart's half on one side of the crack (as a polygon mask image)."""
    m = Image.new('L', (S, S), 0); d = ImageDraw.Draw(m); d.polygon(pts_heart, fill=255)
    side = Image.new('L', (S, S), 0); sd = ImageDraw.Draw(side)
    poly = ([(0, -50)] + crack + [(0, S + 50)]) if left else ([(S, -50)] + crack + [(S, S + 50)])
    sd.polygon(poly, fill=255)
    from PIL import ImageChops
    return ImageChops.multiply(m, side)

def unrequited():
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    cx, cy, r = 560, 520, 360
    outer = heart(cx, cy, r); inner = heart(cx, cy + 22, r - 84)
    crack = crack_line((cx + 10, cy - r * 0.45), (cx - 6, cy + r * 1.05))
    for left, ang, dx, dy in [(True, 0, 0, 0), (False, 16, 46, 64)]:
        layer = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
        d.polygon(outer, fill=INK); d.polygon(inner, fill=CREAM)
        # a gold shine on the left lobe only
        if left:
            d.arc((cx - r * 0.78, cy - r * 0.62, cx - r * 0.18, cy + r * 0.02), 200, 270, fill=GOLD, width=34)
        m = mask_side(outer, crack, left)
        half = Image.new('RGBA', (S, S), (0, 0, 0, 0)); half.paste(layer, (0, 0), m)
        # the crack's own edge, inked
        ImageDraw.Draw(half).line(crack, fill=INK, width=30, joint='curve')
        half = Image.composite(half, Image.new('RGBA', (S, S), (0, 0, 0, 0)), m.point(lambda v: 255 if v else 0).filter(__import__('PIL.ImageFilter', fromlist=['x']).MaxFilter(31)))
        if ang:
            half = half.rotate(-ang, resample=Image.BICUBIC, center=(cx, cy + r * 0.9), translate=(dx, dy))
        img.alpha_composite(half)
    # a gold tear falling from the drooping half
    d = ImageDraw.Draw(img); tx, ty = cx + 300, cy + 450
    d.ellipse((tx - 80, ty - 40, tx + 80, ty + 120), fill=INK)
    d.polygon([(tx - 72, ty + 20), (tx, ty - 170), (tx + 72, ty + 20)], fill=INK)
    d.ellipse((tx - 54, ty - 16, tx + 54, ty + 94), fill=GOLD)
    d.polygon([(tx - 46, ty + 26), (tx, ty - 120), (tx + 46, ty + 26)], fill=GOLD)
    return img

def ill_omened():
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    cx, cy = 600, 560          # upside down: the closed curve on top, the open ends below
    R_out, R_in = 400, 210
    # The shoe: a thick arch, flat-ish heels at the bottom.
    d.pieslice((cx - R_out, cy - R_out, cx + R_out, cy + R_out), 180, 360, fill=INK)
    d.rectangle((cx - R_out, cy, cx - R_in, cy + 300), fill=INK)
    d.rectangle((cx + R_in, cy, cx + R_out, cy + 300), fill=INK)
    d.pieslice((cx - R_in, cy - R_in, cx + R_in, cy + R_in), 180, 360, fill=(0, 0, 0, 0))
    # A cream inlay band along the shoe.
    Rm1, Rm2 = R_out - 62, R_in + 62
    d.arc((cx - (Rm1 + Rm2) / 2, cy - (Rm1 + Rm2) / 2, cx + (Rm1 + Rm2) / 2, cy + (Rm1 + Rm2) / 2), 180, 360, fill=CREAM, width=int(Rm1 - Rm2))
    mid = (Rm1 + Rm2) / 2; w = Rm1 - Rm2
    d.rectangle((cx - mid - w / 2, cy, cx - mid + w / 2, cy + 250), fill=CREAM)
    d.rectangle((cx + mid - w / 2, cy, cx + mid + w / 2, cy + 250), fill=CREAM)
    # Gold nail holes round the band.
    for a in [200, 235, 270, 305, 340]:
        r = math.radians(a); x = cx + mid * math.cos(r); y = cy + mid * math.sin(r)
        hole = [(-18, -30), (18, -30), (18, 30), (-18, 30)]
        c, s = math.cos(r + math.pi / 2), math.sin(r + math.pi / 2)
        d.polygon([(x + px * c - py * s, y + px * s + py * c) for px, py in hole], fill=GOLD)
    for sx in (-1, 1):
        for y in (cy + 70, cy + 180):
            d.rectangle((cx + sx * mid - 18, y - 30, cx + sx * mid + 18, y + 30), fill=GOLD)
    # Gold sparks spilling from the open ends: the luck running out.
    for (x, y, rr) in [(cx - mid - 30, cy + 410, 62), (cx - mid + 70, cy + 520, 44), (cx - mid - 20, cy + 600, 30),
                       (cx + mid + 30, cy + 420, 56), (cx + mid - 60, cy + 540, 38)]:
        pts = []
        for k in range(8):
            a = math.pi / 4 * k; rad = rr * (1.0 if k % 2 == 0 else 0.42)
            pts.append((x + math.cos(a) * rad, y + math.sin(a) * rad))
        d.polygon(pts, fill=GOLD)
    return img

for name, fn in [('unrequited', unrequited), ('ill_omened', ill_omened)]:
    im = fn()
    bb = im.getbbox(); pad = 40
    im = im.crop((max(0, bb[0] - pad), max(0, bb[1] - pad), min(S, bb[2] + pad), min(S, bb[3] + pad)))
    side = max(im.size); sq = Image.new('RGBA', (side, side), (0, 0, 0, 0)); sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    sq.resize((OUT, OUT), Image.LANCZOS).save(name + '.png')
# A contact sheet next to existing icons, on the sheet's paper, plain and violet-tinted.
import numpy as np
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'ui', 'roles') + os.sep   # the repository's own icons, wherever it's checked out
names = ['delusional', 'marked', 'lovers', 'unrequited', 'ill_omened']
sheet = Image.new('RGBA', (5 * 160, 2 * 160), (240, 227, 196, 255))
for i, n in enumerate(names):
    p = (n + '.png') if n in ('unrequited', 'ill_omened') else R + n + '.png'
    ic = Image.open(p).convert('RGBA').resize((140, 140), Image.LANCZOS)
    sheet.alpha_composite(ic, (i * 160 + 10, 10))
    a = np.array(ic).astype(np.float32); lum = (a[..., :3] * [0.299, 0.587, 0.114]).sum(2) / 255
    ink = 1 - np.clip((lum - 0.18) / 0.24, 0, 1); tint = np.array([107, 56, 153], np.float32)
    a[..., :3] = a[..., :3] * (1 - ink[..., None]) + tint * ink[..., None]
    sheet.alpha_composite(Image.fromarray(a.astype(np.uint8)), (i * 160 + 10, 170))
sheet.convert('RGB').save('sheet.png')
