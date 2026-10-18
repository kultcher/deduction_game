#!/usr/bin/env python3
"""Cut the art sheets in assets/*/source into one PNG per piece.

    python3 tools/slice_sheets.py            # all sheets
    python3 tools/slice_sheets.py --preview  # also writes assets/slices_preview.png

Each sheet is split by finding the separate shapes on its transparent background
(connected components of the alpha mask, after a small dilation so a piece's loose bits,
like a candle flame or the dot of a "?", stay with it). Pieces are ordered in reading order
(rows top to bottom, left to right) and named from the list in SHEETS below. The soft,
coloured fringe left by background removal is cut off (alpha below FRINGE goes to 0).

Re-run it whenever a sheet changes. If a sheet gains or loses a piece, update its name
list here; the script stops with an error if the counts don't match.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FRINGE = 110      # alpha below this is background-removal fringe
MIN_AREA = 1500   # specks smaller than this (pixels) are noise

CAST = ["agnes", "bart", "constance", "dorian", "edda", "fenwick", "greta", "hollis", "isolde", "jory"]

SHEETS = {
    "ui/source/ui_bits.png": {"out": "ui", "dilate": 6, "names": [
        "plaque_cream", "plaque_gold", "plaque_red", "plaque_grey", "plaque_navy",
        "tab_cream", "tab_red", "ring_gold", "ring_red", "plaque_wide",
        "corner_tl", "corner_tr", "corner_bl", "corner_br", "divider",
        "curtain_left", "curtain_right", "candle", "raven", "books",
        "sun", "moon", "wax_seal", "arrow_left", "arrow_right"]},
    "ui/source/frames.png": {"out": "ui", "dilate": 4, "names": [
        "frame_wide", "frame_stage", "frame_portrait", "frame_titled", "frame_tab", "frame_banner"]},
    "ui/source/cards.png": {"out": "ui/cards", "dilate": 3, "names": ["card_%02d" % i for i in range(1, 17)]},
    "ui/source/role_icons.png": {"out": "ui/roles", "dilate": 12, "names": [
        "gravedigger", "hearthwitch", "seer", "nightwatch",
        "archivist", "clerk", "warden", "veteran",
        "demon", "poisoner", "unknown", "none"]},
    "art/source/portraits.png": {"out": "art/portraits", "dilate": 3, "names": CAST},
    "art/source/standees_a.png": {"out": "art/standees", "dilate": 3, "names": CAST[:5]},
    "art/source/standees_b.png": {"out": "art/standees", "dilate": 3, "names": CAST[5:]},
    "art/source/buildings.png": {"out": "art/buildings", "dilate": 6, "names": [
        "bakery", "smithy", "tavern", "well", "chapel",
        "graveyard", "mill", "wharf", "cottage_red", "cottage_blue"]},
    "art/source/block_bases.png": {"out": "art/blocks", "dilate": 4, "names": ["square", "market", "docks", "hill"]},
    "art/source/roads_decor.png": {"out": "art/decor", "dilate": 3, "names": [
        "road_h", "road_v", "road_bend", "road_t",
        "road_cross", "bridge", "fence", "stone_wall",
        "tree_oak", "tree_pine", "tree_autumn", "bush",
        "lamp", "crates", "boat", "flowers"]},
    "art/source/terrain_water_walls.png": {"out": "art/terrain", "dilate": 4, "names": [
        "water_big", "water_h", "water_v",
        "water_l", "cliff_h", "cliff_bend",
        "wall_h", "wall_step", "wall_corner"]},
    "art/source/terrain_patches.png": {"out": "art/terrain", "dilate": 2, "names": [
        "grass_a", "grass_strip", "dirt_a", "grass_b",
        "dirt_b", "path_strip", "grass_dirt", "field_ploughed",
        "field_wheat", "field_crops", "grass_c", "dirt_c"]},
}


def pieces(path, dilate):
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    alpha = a[..., 3]
    mask = alpha >= FRINGE
    grown = ndimage.binary_dilation(mask, iterations=dilate) if dilate > 0 else mask
    lab, n = ndimage.label(grown)
    found = []
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        if sl is None:
            continue
        own = (lab[sl] == i) & mask[sl]
        if own.sum() < MIN_AREA:
            continue
        found.append((sl, i))
    # Reading order: group into rows by vertical overlap, then left to right.
    found.sort(key=lambda t: t[0][0].start)
    rows = []
    for sl, i in found:
        cy = (sl[0].start + sl[0].stop) / 2
        for r in rows:
            if r["top"] <= cy <= r["bottom"]:
                r["items"].append((sl, i))
                r["top"] = min(r["top"], sl[0].start)
                r["bottom"] = max(r["bottom"], sl[0].stop)
                break
        else:
            rows.append({"top": sl[0].start, "bottom": sl[0].stop, "items": [(sl, i)]})
    ordered = []
    for r in sorted(rows, key=lambda r: r["top"]):
        ordered += sorted(r["items"], key=lambda t: t[0][1].start)
    out = []
    for sl, i in ordered:
        crop = a[sl].copy()
        keep = (lab[sl] == i) & mask[sl]
        crop[..., 3] = np.where(keep, crop[..., 3], 0)
        # Fully opaque inside the cut-out, so the fringe colour can't bleed back in.
        crop[..., 3] = np.where(keep & (crop[..., 3] >= 200), 255, crop[..., 3])
        out.append((Image.fromarray(crop, "RGBA"), (sl[1].start, sl[0].start, sl[1].stop - sl[1].start, sl[0].stop - sl[0].start)))
    return out


def main():
    preview = "--preview" in sys.argv
    manifest = {}
    thumbs = []
    for rel, cfg in SHEETS.items():
        src = os.path.join(ROOT, "assets", rel)
        got = pieces(src, cfg["dilate"])
        names = cfg["names"]
        if len(got) != len(names):
            sys.exit("%s: found %d pieces, expected %d (%s). Adjust its dilate or name list." % (rel, len(got), len(names), ", ".join(names)))
        outdir = os.path.join(ROOT, "assets", cfg["out"])
        os.makedirs(outdir, exist_ok=True)
        for (img, box), name in zip(got, names):
            p = os.path.join(outdir, name + ".png")
            img.save(p, optimize=True)
            key = "%s/%s" % (cfg["out"], name)
            manifest[key] = {"size": [img.width, img.height], "sheet": rel, "box": list(box)}
            thumbs.append((key, img))
        print("%-36s %2d pieces -> assets/%s" % (rel, len(got), cfg["out"]))
    with open(os.path.join(ROOT, "assets", "slices.json"), "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    if preview:
        from PIL import ImageDraw
        cell = 160
        cols = 12
        rows = (len(thumbs) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * (cell + 16)), (60, 40, 70))
        d = ImageDraw.Draw(sheet)
        for k, (key, img) in enumerate(thumbs):
            t = img.copy()
            t.thumbnail((cell - 8, cell - 8))
            x, y = (k % cols) * cell, (k // cols) * (cell + 16)
            sheet.paste(t, (x + 4, y + 4), t)
            d.text((x + 4, y + cell), key.split("/")[-1], fill=(255, 255, 255))
        sheet.save(os.path.join(ROOT, "assets", "ui", "source", "slices_preview.png"))


if __name__ == "__main__":
    main()
