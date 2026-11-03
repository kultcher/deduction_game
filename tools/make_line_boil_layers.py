#!/usr/bin/env python3
"""Stand-in line layers for the line-boil shader (ui/line_boil.gdshader).

Real use wants hand-drawn ink layers; this fakes them from the existing painted
portraits so the effect can be judged before anyone draws anything:

  <expr>-base.png      the portrait with its ink lines mostly painted out (colour only)
  <expr>-lines-a.png   ink layer, channel-packed: R = outline, G = hatching
  <expr>-lines-b.png   ...the same ink "redrawn": outlines warped and thickened
  <expr>-lines-c.png      differently, hatch strokes placed afresh

Hand-drawn layers can be packed into the same format: outline in red, hatching in
green, black elsewhere (white ink = 1.0). Two or three drawn variants make the boil.

  python3 tools/make_line_boil_layers.py jory:neutral,harsh nisha:neutral,harsh
"""
import math
import os
import sys

import cv2
import numpy as np

SRC = "assets/art/cast_expressions/{id}/{expr}-v1.png"
# Drawn ink, when there is some: ink in alpha on a transparent sheet, registered to SRC.
INK = "assets/art/cast_ink/{id}/{expr}-v1.png"
OUT = "assets/art/line_boil_poc/{id}"
VARIANTS = "abc"


def load(path):
    img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    if img is None:
        raise SystemExit("can't read " + path)
    return img


def extract_outline(bgr, alpha):
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    gray = np.where(alpha > 0.5, gray, 232.0)  # background reads as paper
    kern = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    bh = cv2.morphologyEx(gray, cv2.MORPH_BLACKHAT, kern)
    line = np.clip((bh - 16.0) / 38.0, 0.0, 1.0)
    # The silhouette edge itself, so the cut-out has a drawn contour.
    a8 = (alpha * 255).astype(np.uint8)
    rim = cv2.morphologyEx(a8, cv2.MORPH_GRADIENT, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)))
    rim = rim.astype(np.float32) / 255.0 * 0.9
    return line, rim, gray


def shade_map(gray, alpha):
    a = alpha.astype(np.float32)

    def mean(r):
        k = (2 * r + 1, 2 * r + 1)
        return cv2.blur(gray * a, k) / np.maximum(cv2.blur(a, k), 1e-3)

    here = mean(3)
    around = (mean(26) + mean(13)) * 0.5
    shade = np.clip((around - here - 0.015 * 255) * 12.0 / 255.0, 0.0, 1.0)
    return cv2.GaussianBlur(shade, (0, 0), 2.0) * (a > 0.5)


def smooth_field(shape, rng, sigma, amp):
    f = rng.standard_normal(shape).astype(np.float32)
    f = cv2.GaussianBlur(f, (0, 0), sigma)
    return f / (np.abs(f).max() + 1e-6) * amp


def redraw_outline(line, rng):
    h, w = line.shape
    dx = smooth_field((h, w), rng, 40, 1.6)
    dy = smooth_field((h, w), rng, 40, 1.6)
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    warped = cv2.remap(line, gx + dx, gy + dy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    gamma = np.exp(smooth_field((h, w), rng, 60, 0.45))  # pressure: lines thicken and thin
    return np.clip(warped, 0, 1) ** gamma


def hatch_strokes(shade, alpha, rng):
    h, w = shade.shape
    canvas = np.zeros((h, w), np.float32)
    layers = [(0.785, 0.15, 13.0), (-0.785, 0.45, 13.0), (0.2, 0.75, 10.5)]
    diag = math.hypot(w, h)
    for angle, thresh, spacing in layers:
        d = np.array([math.cos(angle), math.sin(angle)])
        n = np.array([-d[1], d[0]])
        centre = np.array([w / 2, h / 2])
        off = -diag / 2 + rng.uniform(0, spacing)
        while off < diag / 2:
            s = -diag / 2
            while s < diag / 2:
                length = rng.uniform(24, 60)
                jitter_n = rng.normal(0, 1.2)
                ang = angle + rng.normal(0, 0.05)
                dd = np.array([math.cos(ang), math.sin(ang)])
                mid = centre + n * (off + jitter_n) + d * (s + length / 2)
                mx, my = int(mid[0]), int(mid[1])
                if 0 <= mx < w and 0 <= my < h:
                    v = shade[my, mx] - (thresh + rng.uniform(-0.05, 0.05))
                    if v > 0 and alpha[my, mx] > 0.5:
                        ink = min(1.0, v * 3.0 + 0.35)
                        p0 = mid - dd * length / 2
                        p1 = mid + dd * length / 2
                        cv2.line(canvas, (int(p0[0] * 4), int(p0[1] * 4)), (int(p1[0] * 4), int(p1[1] * 4)),
                                 float(ink), 1 if rng.random() < 0.6 else 2, cv2.LINE_AA, shift=2)
                s += length + rng.uniform(2, 9)
            off += spacing
    return np.clip(canvas, 0, 1) * (alpha > 0.5)


def paint_out(bgr, alpha, mask):
    solid = cv2.erode((alpha > 0.9).astype(np.uint8), np.ones((13, 13), np.uint8))
    mask = mask.copy()
    mask[solid == 0] = 0
    painted = cv2.inpaint(bgr, mask, 3, cv2.INPAINT_TELEA)
    return painted, cv2.addWeighted(painted, 0.8, bgr, 0.2, 0)


def make_from_ink(cid, expr, img, ink_img):
    """Drawn ink: split it into outline (heavy strokes) and hatching (fine strokes), and
    make the extra variants by redrawing it: warped, re-weighted, some strokes left out."""
    bgr = img[:, :, :3]
    alpha = img[:, :, 3].astype(np.float32) / 255.0
    ink = ink_img[:, :, 3].astype(np.float32) / 255.0
    heavy = cv2.morphologyEx((ink > 0.5).astype(np.uint8), cv2.MORPH_OPEN,
                             cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (4, 4)))
    heavy = cv2.dilate(heavy, np.ones((3, 3), np.uint8)).astype(np.float32)
    outline = ink * heavy
    hatch = ink * (1.0 - heavy)

    out = OUT.format(id=cid)
    os.makedirs(out, exist_ok=True)
    # Paint out the portrait's own linework under the drawn outlines (and its other dark lines).
    inner, _, gray = extract_outline(bgr, alpha)
    # A colour "closing" lifts out dark lines thinner than the kernel and keeps the fill
    # either side; inpainting smeared the lines' dark cores into dashes. Anything the
    # closing lightens a lot is a line, drawn ink or not.
    closed = cv2.morphologyEx(bgr, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11)))
    lift = cv2.cvtColor(closed, cv2.COLOR_BGR2GRAY).astype(np.float32) - gray
    mask = ((outline > 0.2) | (inner > 0.22) | (lift > 40)).astype(np.uint8) * 255
    mask = cv2.dilate(mask, np.ones((5, 5), np.uint8))
    closed = cv2.GaussianBlur(closed, (0, 0), 1.5)
    solid = cv2.erode((alpha > 0.9).astype(np.uint8), np.ones((9, 9), np.uint8)).astype(np.float32)
    m = cv2.GaussianBlur((mask > 0).astype(np.float32), (0, 0), 1.5) * solid
    base = (bgr * (1 - m[..., None]) + closed * m[..., None]).astype(np.uint8)
    cv2.imwrite(os.path.join(out, "%s-base.png" % expr), np.dstack([base, img[:, :, 3]]))

    n_strokes, strokes = cv2.connectedComponents((hatch > 0.25).astype(np.uint8), connectivity=8)
    for i, v in enumerate(VARIANTS):
        rng = np.random.default_rng(1000 * i + sum(map(ord, cid + expr)))
        o, hch = outline, hatch
        if i > 0:
            h, w = ink.shape
            dx = smooth_field((h, w), rng, 40, 1.6)
            dy = smooth_field((h, w), rng, 40, 1.6)
            gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
            keep = rng.random(n_strokes) > 0.22   # a redraw doesn't repeat every stroke
            keep[0] = True
            hch = hatch * keep[strokes]
            o = cv2.remap(outline, gx + dx, gy + dy, cv2.INTER_LINEAR)
            hch = cv2.remap(hch, gx + dx, gy + dy, cv2.INTER_LINEAR)
            o = np.clip(o, 0, 1) ** np.exp(smooth_field((h, w), rng, 60, 0.45))
        packed = np.zeros(img.shape[:2] + (4,), np.uint8)
        packed[:, :, 2] = (np.clip(o, 0, 1) * 255).astype(np.uint8)
        packed[:, :, 1] = (np.clip(hch, 0, 1) * 255).astype(np.uint8)
        packed[:, :, 3] = 255
        cv2.imwrite(os.path.join(out, "%s-lines-%s.png" % (expr, v)), packed)
    print("wrote", out, expr, "(from drawn ink)")


def make(cid, expr):
    img = load(SRC.format(id=cid, expr=expr))
    if os.path.exists(INK.format(id=cid, expr=expr)):
        return make_from_ink(cid, expr, img, load(INK.format(id=cid, expr=expr)))
    bgr = img[:, :, :3]
    alpha = img[:, :, 3].astype(np.float32) / 255.0
    inner, rim, gray = extract_outline(bgr, alpha)
    line = np.maximum(inner, rim)

    out = OUT.format(id=cid)
    os.makedirs(out, exist_ok=True)
    # Colour base: paint most of the ink out so the boiling layer isn't doubled by a still one.
    # Only inner lines: the silhouette rim would pull in the transparent background's colour.
    mask = cv2.dilate((inner > 0.22).astype(np.uint8) * 255, np.ones((3, 3), np.uint8))
    # Thick strokes and junctions are wider than the line detector: take their dark cores too.
    grown = cv2.dilate(mask, np.ones((9, 9), np.uint8))
    mask[(gray < 75) & (grown > 0)] = 255
    solid = cv2.erode((alpha > 0.9).astype(np.uint8), np.ones((13, 13), np.uint8))
    mask[solid == 0] = 0
    painted = cv2.inpaint(bgr, mask, 3, cv2.INPAINT_TELEA)
    base = cv2.addWeighted(painted, 0.8, bgr, 0.2, 0)
    cv2.imwrite(os.path.join(out, "%s-base.png" % expr), np.dstack([base, img[:, :, 3]]))
    # Shade from the painted-out base, so ink lines (a mouth, a brow) don't count as shadow;
    # and ease off in areas that are already near-black, like hair.
    pgray = cv2.cvtColor(painted, cv2.COLOR_BGR2GRAY).astype(np.float32)
    shade = shade_map(pgray, alpha) * np.clip((pgray - 45.0) / 50.0, 0.0, 1.0)

    for i, v in enumerate(VARIANTS):
        rng = np.random.default_rng(1000 * i + sum(map(ord, cid + expr)))
        outline = line if i == 0 else redraw_outline(line, rng)
        # Keep strokes off the features' own lines (a mouth hatched across reads as stitches).
        hatch = hatch_strokes(shade, alpha, rng) * (cv2.dilate(inner, np.ones((5, 5), np.uint8)) < 0.5)
        packed = np.zeros(img.shape[:2] + (4,), np.uint8)
        packed[:, :, 2] = (outline * 255).astype(np.uint8)  # R (OpenCV is BGRA)
        packed[:, :, 1] = (hatch * 255).astype(np.uint8)    # G
        packed[:, :, 3] = 255
        cv2.imwrite(os.path.join(out, "%s-lines-%s.png" % (expr, v)), packed)
    print("wrote", out, expr)


if __name__ == "__main__":
    for arg in sys.argv[1:] or ["jory:neutral,harsh", "nisha:neutral,harsh"]:
        cid, _, exprs = arg.partition(":")
        for e in (exprs or "neutral").split(","):
            make(cid, e)
