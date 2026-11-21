#!/usr/bin/env python3
"""Builds the two layers the line-boil shader (ui/line_boil.gdshader) draws a portrait from.

Input, per portrait and expression:
  the painted portrait   assets/art/cast_expressions/<id>/<expr>-v1.png
  its drawn ink          a transparent sheet registered to the portrait, ink in alpha
                         (INK below, or assets/art/cast_ink/<id>/<expr>-v1.png)

Output, in assets/art/line_boil/<id>/:
  <expr>-base.png   the colour layer: the portrait with its own linework lifted out, so
                    the boiling ink isn't doubled by a still copy of the same lines
  <expr>-ink.png    the ink layer, channel-packed (all of it travels in one texture):
                      R  outlines (the heavy strokes), as drawn
                      G  outlines redrawn: warped a pixel or two, pressure varied
                      B  hatching and shadow (the fine strokes)
                      A  a random value per hatch stroke, 1..255, so the shader can leave
                         out a different few strokes on each redraw. Never 0: the importer's
                         alpha-border fix only touches fully transparent pixels.

The base is extracted; the ink is drawn. When the art arrives as separate flats and inks,
the flats can be used as the base directly (--flat) and the extraction step goes away.

  python3 tools/make_line_boil_layers.py               # every portrait with drawn ink
  python3 tools/make_line_boil_layers.py edda:neutral
Needs numpy and opencv (pip install opencv-python-headless). Deterministic for a given input.
"""
import os
import sys

import cv2
import numpy as np

SRC = "assets/art/cast_expressions/{id}/{expr}-v1.png"
INK_DEFAULT = "assets/art/cast_ink/{id}/{expr}-v1.png"
# Drawn ink kept somewhere other than the default path.
INK = {
    ("edda", "neutral"): "assets/art/edda_ink_overlay_poc/edda-ink-overlay-v1.png",
}
FLAT_DEFAULT = "assets/art/cast_flats/{id}/{expr}-v1.png"
OUT = "assets/art/line_boil/{id}"


def load(path):
    img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    if img is None or img.ndim != 3 or img.shape[2] != 4:
        raise SystemExit("can't read an RGBA image at " + path)
    return img


def ink_path(cid, expr):
    return INK.get((cid, expr), INK_DEFAULT.format(id=cid, expr=expr))


def smooth_field(shape, rng, sigma, amp):
    f = rng.standard_normal(shape).astype(np.float32)
    f = cv2.GaussianBlur(f, (0, 0), sigma)
    return f / (np.abs(f).max() + 1e-6) * amp


def split_ink(ink):
    """Heavy strokes (wider than ~4 px) are outlines, the rest hatching and shadow."""
    heavy = cv2.morphologyEx((ink > 0.5).astype(np.uint8), cv2.MORPH_OPEN,
                             cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (4, 4)))
    heavy = cv2.dilate(heavy, np.ones((3, 3), np.uint8)).astype(np.float32)
    return ink * heavy, ink * (1.0 - heavy)


def redraw(outline, rng):
    """The same outlines drawn again: bent a pixel or two, pressed harder in places."""
    h, w = outline.shape
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    dx = smooth_field((h, w), rng, 40, 1.6)
    dy = smooth_field((h, w), rng, 40, 1.6)
    o = cv2.remap(outline, gx + dx, gy + dy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    return np.clip(o, 0, 1) ** np.exp(smooth_field((h, w), rng, 60, 0.45))


def stroke_ids(hatch, rng):
    """A random 1..255 per hatch stroke, spread a few pixels past each stroke so a filtered
    lookup at its anti-aliased edge still reads the stroke's own value."""
    n, labels = cv2.connectedComponents((hatch > 0.25).astype(np.uint8), connectivity=8)
    values = rng.integers(1, 256, size=n).astype(np.uint8)
    ids = values[labels]
    ids[labels == 0] = 0
    grown = cv2.dilate(ids, np.ones((5, 5), np.uint8))
    return np.where(grown == 0, 255, grown).astype(np.uint8)


def lift_lines(bgr, alpha, outline):
    """The colour layer: dark lines replaced by the fill either side of them. A colour
    closing lifts out dark lines thinner than its kernel and keeps the colour round them
    (inpainting smeared the lines' dark cores into dashes)."""
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
    paper = np.where(alpha > 0.5, gray, 232.0)
    inner = np.clip((cv2.morphologyEx(paper, cv2.MORPH_BLACKHAT,
                     cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))) - 16.0) / 38.0, 0.0, 1.0)
    closed = cv2.morphologyEx(bgr, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11)))
    lift = cv2.cvtColor(closed, cv2.COLOR_BGR2GRAY).astype(np.float32) - gray
    mask = ((outline > 0.2) | (inner > 0.22) | (lift > 40)).astype(np.uint8)
    mask = cv2.dilate(mask, np.ones((5, 5), np.uint8))
    closed = cv2.GaussianBlur(closed, (0, 0), 1.5)
    solid = cv2.erode((alpha > 0.9).astype(np.uint8), np.ones((9, 9), np.uint8)).astype(np.float32)
    m = cv2.GaussianBlur(mask.astype(np.float32), (0, 0), 1.5) * solid
    return (bgr * (1 - m[..., None]) + closed * m[..., None]).astype(np.uint8)


def make(cid, expr, flat=False):
    img = load(SRC.format(id=cid, expr=expr))
    ink_img = load(ink_path(cid, expr))
    if ink_img.shape[:2] != img.shape[:2]:
        raise SystemExit("%s: the ink sheet isn't the portrait's size" % ink_path(cid, expr))
    alpha = img[:, :, 3].astype(np.float32) / 255.0
    ink = ink_img[:, :, 3].astype(np.float32) / 255.0
    outline, hatch = split_ink(ink)
    rng = np.random.default_rng(sum(map(ord, cid + ":" + expr)))

    out = OUT.format(id=cid)
    os.makedirs(out, exist_ok=True)
    if flat:
        base = load(FLAT_DEFAULT.format(id=cid, expr=expr))
    else:
        base = np.dstack([lift_lines(img[:, :, :3], alpha, outline), img[:, :, 3]])
    cv2.imwrite(os.path.join(out, "%s-base.png" % expr), base)

    packed = np.zeros(img.shape[:2] + (4,), np.uint8)   # OpenCV order: B, G, R, A
    packed[:, :, 2] = (np.clip(outline, 0, 1) * 255).astype(np.uint8)
    packed[:, :, 1] = (np.clip(redraw(outline, rng), 0, 1) * 255).astype(np.uint8)
    packed[:, :, 0] = (np.clip(hatch, 0, 1) * 255).astype(np.uint8)
    packed[:, :, 3] = stroke_ids(hatch, rng)
    cv2.imwrite(os.path.join(out, "%s-ink.png" % expr), packed)
    print("wrote %s/%s-base.png and %s-ink.png" % (out, expr, expr))


def everything_with_ink():
    found = list(INK)
    root = os.path.dirname(INK_DEFAULT.format(id="x", expr="x")).rsplit("/", 1)[0]
    if os.path.isdir(root):
        for cid in sorted(os.listdir(root)):
            for f in sorted(os.listdir(os.path.join(root, cid))):
                if f.endswith("-v1.png") and (cid, f[:-7]) not in found:
                    found.append((cid, f[:-7]))
    return found


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flat = "--flat" in sys.argv
    jobs = []
    for arg in args:
        cid, _, exprs = arg.partition(":")
        jobs += [(cid, e) for e in (exprs or "neutral").split(",")]
    for cid, expr in jobs or everything_with_ink():
        make(cid, expr, flat)
