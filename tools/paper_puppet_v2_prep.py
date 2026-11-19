#!/usr/bin/env python3
"""One-off (mock branch): turns Michael's Krita exports into assets/art/paper_puppet_poc/edda_v2/.
Usage: python3 tools/paper_puppet_v2_prep.py <exports dir> <out dir> <scratch dir>.
The input file names are the ones they arrived under in this session."""
import sys
from PIL import Image
import numpy as np, cv2
I, D, S = sys.argv[1]+'/', sys.argv[2]+'/', sys.argv[3]+'/'
H, W = 1536, 1024
def rgba(f): return np.array(Image.open(I+f).convert('RGBA'))
def save(a, n): Image.fromarray(a).save(D+n+'.png')
L = {'body':'30.webp','eyes':'25.png','nose':'24.png','brow_far':'18.png','brow_near':'19.png',
     'hair_left':'26.png','hair_mass':'21.png','hair_neck':'22.png','hair_waves':'23.png','hair_swoop':'27.png'}
A = {n: rgba(f) for n, f in L.items()}
for n, a in A.items(): save(a, n)

def comps(a, min_area=1500):
    m = (a[...,3] > 40).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((5,5), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
    out = [(st[i], (lab == i)) for i in range(1, n) if st[i][4] >= min_area]
    return out

def paste(canvas, src, mask, s, dx, dy):
    """Scale the masked part of src by s and put its pixel (0,0) at (dx,dy) on the canvas."""
    piece = src.copy(); piece[...,3] = (piece[...,3] * cv2.dilate(mask.astype(np.uint8), np.ones((5,5),np.uint8))).astype(np.uint8)
    M = np.float32([[s, 0, dx], [0, s, dy]])
    warped = cv2.warpAffine(piece, M, (W, H), flags=cv2.INTER_AREA if s < 1 else cv2.INTER_LINEAR, borderValue=(0,0,0,0))
    a = warped[...,3:4].astype(np.float32) / 255
    canvas[...,:3] = (canvas[...,:3] * (1 - a) + warped[...,:3] * a).astype(np.uint8)
    canvas[...,3] = np.maximum(canvas[...,3], warped[...,3])

# Mouths: the sheet's closed mouth is matched to the placed one (28.png); the others take the
# same scale and line up on their upper lip's left corner and top.
ref = rgba('28.png'); ys, xs = np.where(ref[...,3] > 40)
rx0, ry0, rw = xs.min(), ys.min(), xs.max() - xs.min()
sheet = rgba('29.png'); cs = sorted(comps(sheet), key=lambda c: (c[0][1] // 300, c[0][0]))
print('mouth sheet', [tuple(c[0][:4]) for c in cs])
s = rw / cs[0][0][2]
for i, (st, m) in enumerate(cs):
    can = np.zeros((H, W, 4), np.uint8)
    paste(can, sheet, m, s, rx0 - st[0] * s, ry0 - st[1] * s)
    save(can, 'mouth_%d' % i)
print('mouth scale %.3f' % s)

# Eyes: each sheet eye is matched to its placed eye (25.png); its closed lid takes the same
# scale, centred across the eye a little below its middle.
eyes = A['eyes']; placed = sorted(comps(eyes, 500), key=lambda c: c[0][0])
sh = rgba('31.png'); ec = sorted(comps(sh), key=lambda c: (c[0][1] // 400, c[0][0]))
print('eye sheet', [tuple(c[0][:4]) for c in ec], 'placed', [tuple(c[0][:4]) for c in placed])
opens, shuts = ec[:2], ec[2:4]
shut = np.zeros((H, W, 4), np.uint8)
for (pst, _), (ost, _), (cst, cm) in zip(placed, opens, shuts):
    s = pst[2] / ost[2]
    cx = pst[0] + pst[2] / 2; cy = pst[1] + pst[3] * 0.58
    paste(shut, sh, cm, s, cx - (cst[0] + cst[2] / 2) * s, cy - (cst[1] + cst[3] / 2) * s)
save(shut, 'eyes_shut')

# Ear: lifted out of the body so it sits in front of the hair mass.
b = A['body']; hsv = cv2.cvtColor(b[...,:3], cv2.COLOR_RGB2HSV).astype(int)
skin = ((b[...,3] > 128) & (hsv[...,2] > 180) & (hsv[...,0] <= 25)).astype(np.uint8)
ell = np.zeros((H, W), np.uint8); cv2.ellipse(ell, (679, 374), (46, 68), 12, 0, 360, 1, -1)
mass_hole = (A['hair_mass'][...,3] < 128).astype(np.uint8)
ear = skin & ell & mass_hole
n, lab, st, _ = cv2.connectedComponentsWithStats(ear, 8); ear = (lab == np.argmax(st[1:, 4]) + 1).astype(np.uint8)
ff = (1 - ear).copy(); mk = np.zeros((H + 2, W + 2), np.uint8); cv2.floodFill(ff, mk, (0, 0), 0); ear |= ff
e = b.copy(); e[...,3] = (cv2.GaussianBlur(ear.astype(np.float32), (0, 0), 0.7) * b[...,3]).astype(np.uint8)
save(e, 'ear')

# Under-hair: dark hair wherever the hair covers empty canvas, so a swaying piece never opens
# a hole. Never over the body: a gap there shows the face or neck, which is right.
foot = np.zeros((H, W), np.uint8)
for n in ['hair_left', 'hair_mass', 'hair_neck', 'hair_waves', 'hair_swoop']:
    m = (A[n][...,3] > 128).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31)))
    ff = (1 - m).copy(); mk = np.zeros((H + 2, W + 2), np.uint8); cv2.floodFill(ff, mk, (0, 0), 0)
    foot |= m | ff
under = cv2.erode(foot, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13))) & (b[...,3] < 128)
mass = A['hair_mass']; dk = mass[mass[...,3] > 200][:, :3]
Lc = cv2.cvtColor(dk[None], cv2.COLOR_RGB2LAB)[0, :, 0]; col = np.median(dk[Lc < np.percentile(Lc, 30)], axis=0)
rng = np.random.default_rng(9)
g = cv2.GaussianBlur(rng.standard_normal((H, W)).astype(np.float32), (0, 0), 1.2) * 0.04
rgb = np.clip(col[None, None] * (1 + g[..., None]), 0, 255).astype(np.uint8)
save(np.dstack([rgb, (cv2.GaussianBlur(under.astype(np.float32), (0, 0), 0.8) * 255).astype(np.uint8)]), 'hair_under')

# Check sheet: everything stacked, eyes open and shut, mouths.
order = ['body', 'hair_under', 'hair_left', 'hair_neck', 'nose', 'eyes', 'mouth_0', 'brow_far', 'brow_near', 'hair_mass', 'ear', 'hair_waves', 'hair_swoop']
def stack(over=None):
    c = Image.new('RGBA', (W, H), (60, 60, 70, 255))
    for n in order:
        n = (over or {}).get(n, n)
        if n: c.alpha_composite(Image.open(D + n + '.png'))
    return c.crop((150, 0, 900, 650)).convert('RGB')
shots = [stack(), stack({'eyes': None, 'mouth_0': 'mouth_1'}), stack({'mouth_0': 'mouth_2'})]
sh_ = stack({'eyes': None}); c = Image.open(D + 'eyes_shut.png')
out = Image.new('RGB', (1500, 1300))
for i, im in enumerate(shots): out.paste(im, ((i % 2) * 750, (i // 2) * 650))
tmp = Image.new('RGBA', (W, H), (60, 60, 70, 255))
for n in order:
    if n != 'eyes': tmp.alpha_composite(Image.open(D + n + '.png'))
tmp.alpha_composite(c); out.paste(tmp.crop((150, 0, 900, 650)).convert('RGB'), (750, 650))
out.resize((1000, 867)).save(S + 'v2_check.jpg')
