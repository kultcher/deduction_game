#!/usr/bin/env python3
"""Display copies of the trace artwork, from the sources in assets/art/trace_items_poc/.

  assets/art/trace_icons/large/<key>.png   768 px square: the dialogue window
  assets/art/trace_icons/small/<key>.png   128 px square: solver cards and tooltips

<key> is the trace's places joined with "_" in sorted order, as in its trace_key
("locations:bakery:mill" -> "bakery_mill").

- Two-place tokens: the item is trimmed to its silhouette and centred with even padding,
  so a pin and a coin read at the same size. The sources stay untouched.
- Three-place scents: one of four wisp shapes, picked from the key, tinted with a
  bottom-to-top blend of its three places' colours (so each combination looks its own).

  python3 tools/make_trace_icons.py
"""
import hashlib
import itertools
import os

import numpy as np
from PIL import Image

SRC = "assets/art/trace_items_poc"
OUT = "assets/art/trace_icons"
SIZES = {"large": 768, "small": 128}
FILL = 0.84   # the item's longer side, as a fraction of the square
LOCS = ["bakery", "chapel", "graveyard", "mill", "smithy", "tavern", "well", "wharf"]
# Scent colours, after LOC_SCENT_NOTES in sim/content.gd.
SCENT_TINT = {
    "bakery": (226, 168, 96),     # warm yeast
    "chapel": (236, 210, 128),    # beeswax incense
    "graveyard": (128, 160, 110), # damp yew and loam
    "mill": (232, 222, 186),      # crushed grain
    "smithy": (140, 146, 160),    # coal-smoke
    "tavern": (196, 120, 78),     # spilled ale
    "well": (128, 168, 196),      # wet stone
    "wharf": (92, 168, 158),      # brine and tar
}
WISPS = ["scent_wisp_%d-v1.png" % i for i in range(1, 5)]


def trim(im, alpha_floor=12):
    a = np.array(im)[:, :, 3]
    ys, xs = np.nonzero(a > alpha_floor)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def fit_square(im, size):
    w, h = im.size
    s = size * FILL / max(w, h)
    item = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(item, ((size - item.width) // 2, (size - item.height) // 2))
    return out


def save(im, key):
    for name, size in SIZES.items():
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        fit_square(im, size).save(os.path.join(d, key + ".png"), optimize=True)


def tinted_wisp(wisp, places):
    arr = np.array(wisp).astype(np.float32) / 255.0
    lum = arr[:, :, :3].mean(axis=2)
    h = arr.shape[0]
    # Bottom of the wisp takes the first place's colour, the top the last.
    t = np.linspace(1.0, 0.0, h)[:, None]
    cols = [np.array(SCENT_TINT[p], np.float32) / 255.0 for p in places]
    seg = np.clip(t * 2.0, 0.0, 2.0)
    lo = np.where(seg[..., None] < 1.0, cols[0], cols[1])
    hi = np.where(seg[..., None] < 1.0, cols[1], cols[2])
    f = (seg - np.floor(np.minimum(seg, 1.999)))[..., None]
    tint = lo * (1 - f) + hi * f
    tint = np.broadcast_to(tint, arr[:, :, :3].shape)
    rgb = tint * (0.45 + 0.55 * lum[..., None])
    rgb = rgb + (1.0 - rgb) * (lum[..., None] ** 4) * 0.35   # keep the brightest highlights
    out = np.dstack([np.clip(rgb, 0, 1), arr[:, :, 3]])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def main():
    n = 0
    for a, b in itertools.combinations(LOCS, 2):
        key = "%s_%s" % (a, b)
        path = os.path.join(SRC, key + "-v1.png")
        if os.path.exists(path):
            save(trim(Image.open(path).convert("RGBA")), key)
            n += 1
    wisps = [trim(Image.open(os.path.join(SRC, w)).convert("RGBA"), alpha_floor=4) for w in WISPS]
    for combo in itertools.combinations(LOCS, 3):
        key = "_".join(combo)
        pick = int(hashlib.md5(key.encode()).hexdigest(), 16) % len(wisps)
        save(tinted_wisp(wisps[pick], combo), key)
        n += 1
    print("wrote %d icons to %s" % (n, OUT))


if __name__ == "__main__":
    main()
