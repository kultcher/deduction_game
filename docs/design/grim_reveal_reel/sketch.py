# Grim-reveal pitch sketches (Limner). Presentation mockups only: PIL, no game code.
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps, ImageEnhance
R = '/home/user/deduction_game/'
OUT = sys.argv[1]
W, H = 1600, 900
PAPER = (240, 227, 196); INK = (43, 33, 23); EVIL = (128, 30, 26); GOOD = (176, 136, 60)
F = lambda s, b=False, i=False: ImageFont.truetype('/usr/share/fonts/truetype/liberation/LiberationSerif-%s.ttf' % ('BoldItalic' if b and i else 'Bold' if b else 'Italic' if i else 'Regular'), s)

def icon(role, size):
    im = Image.open(R + 'assets/ui/roles/%s.png' % role).convert('RGBA')
    im.thumbnail((size, size), Image.LANCZOS); return im
def portrait(pid, h):
    im = Image.open(R + 'assets/art/cast_expressions/%s/neutral-v1.png' % pid).convert('RGBA')
    return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
def shadow(im, r=10, off=(8, 12), a=0.45):
    s = Image.new('RGBA', (im.width + 4 * r, im.height + 4 * r), (0, 0, 0, 0))
    m = im.getchannel('A').point(lambda v: int(v * a))
    s.paste(Image.new('RGBA', im.size, (25, 15, 8, 255)), (2 * r, 2 * r), m)
    return s.filter(ImageFilter.GaussianBlur(r)), (off[0] - 2 * r, off[1] - 2 * r)
def put(c, im, xy, sh=True, r=10, off=(8, 12), a=0.45):
    if sh:
        s, o = shadow(im, r, off, a); c.alpha_composite(s, (int(xy[0] + o[0]), int(xy[1] + o[1])))
    c.alpha_composite(im, (int(xy[0]), int(xy[1])))
def grey(im, k=0.15, dark=0.75):
    g = ImageOps.grayscale(im.convert('RGB')).convert('RGB')
    g = ImageEnhance.Brightness(Image.blend(g, im.convert('RGB'), k)).enhance(dark)
    out = g.convert('RGBA'); out.putalpha(im.getchannel('A')); return out
def paper_panel(w, h, col=PAPER, seed=1):
    import random; rnd = random.Random(seed)
    m = Image.new('L', (w, h), 0); d = ImageDraw.Draw(m)
    pts = []
    for x in range(0, w, 14): pts.append((x, rnd.uniform(0, 4)))
    for y in range(0, h, 14): pts.append((w - rnd.uniform(0, 4), y))
    for x in range(w, 0, -14): pts.append((x, h - rnd.uniform(0, 4)))
    for y in range(h, 0, -14): pts.append((rnd.uniform(0, 4), y))
    d.polygon(pts, fill=255)
    p = Image.new('RGBA', (w, h), col + (255,))
    noise = Image.effect_noise((w, h), 18).convert('L').filter(ImageFilter.GaussianBlur(0.8))
    p = Image.composite(Image.new('RGBA', (w, h), tuple(int(c * 0.93) for c in col) + (255,)), p, noise.point(lambda v: 80 if v > 140 else 0))
    p.putalpha(m); return p

BG = Image.open(R + 'assets/art/interiors_poc/mill-papercraft-v1.png').convert('RGB').resize((W, H)).filter(ImageFilter.GaussianBlur(6))
BG = ImageEnhance.Brightness(BG).enhance(0.38).convert('RGBA')
TOWN = ['edda', 'dorian', 'fenwick', 'greta', 'hollis', 'isolde', 'jory', 'kiran', 'merrin', 'odette']
TRUTH = {'edda': ('gravedigger', 'Delusional'), 'dorian': ('seer', None), 'odette': ('poisoner', None)}
SCRIPT = ['seer', 'dowser', 'clerk', 'gravedigger', 'medium', 'nightwatch', 'magistrate', 'lamplighter', 'poisoner', 'brute', 'demon']
NAMES = {'seer': 'Seer', 'dowser': 'Dowser', 'clerk': 'Clerk', 'gravedigger': 'Gravedigger', 'medium': 'Medium',
         'nightwatch': 'Night Watch', 'magistrate': 'Magistrate', 'lamplighter': 'Lamplighter', 'poisoner': 'Poisoner', 'brute': 'Brute', 'demon': 'Demon'}
EVILS = {'poisoner', 'brute', 'demon'}

def town_strip(c, current, revealed, dead):
    n = len(TOWN); tile = 92; gap = 14; x0 = (W - (n * tile + (n - 1) * gap)) // 2; y0 = H - tile - 26
    for i, pid in enumerate(TOWN):
        p = Image.open(R + 'assets/art/cast_expressions/%s/neutral-v1.png' % pid).convert('RGBA')
        p = p.crop((p.width * 0.22, p.height * 0.06, p.width * 0.78, p.height * 0.06 + p.width * 0.56)).resize((tile - 12, tile - 12), Image.LANCZOS)
        card = paper_panel(tile, tile, (226, 212, 180), seed=i); card.alpha_composite(p, (6, 6))
        if pid in dead and pid not in revealed and pid != current: card = grey(card)
        y = y0 - (16 if pid == current else 0)
        put(c, card, (x0 + i * (tile + gap), y), r=5, off=(3, 5) if pid != current else (6, 12))
        if pid in revealed:
            role = revealed[pid]; ic = icon(role, 34)
            disc = Image.new('RGBA', (42, 42)); ImageDraw.Draw(disc).ellipse((0, 0, 41, 41), fill=(EVIL if role in EVILS else GOOD) + (255,))
            disc.alpha_composite(ImageOps.contain(ic.convert('RGBA'), (28, 28)), (7, 7))
            put(c, disc, (x0 + i * (tile + gap) + tile - 30, y + tile - 30), r=3, off=(2, 3))

def frame_base(pid, title_y=True):
    c = BG.copy()
    panel = paper_panel(1180, 640, seed=7); put(c, panel, (210, 40), r=18, off=(12, 20), a=0.6)
    pr = portrait(pid, 600); px = 260
    put(c, pr, (px, 70), r=12, off=(10, 16))
    d = ImageDraw.Draw(c)
    d.text((880, 78), pid.capitalize(), font=F(46, b=True), fill=INK)
    return c, d

# --- Reel A: the volvelle (a paper wheel behind a cut window) -----------------------------
VR = 175; VC = (1110, 375)
def volvelle_disc(roles):
    s = VR * 2 + 20; disc = Image.new('RGBA', (s, s), (0, 0, 0, 0)); d = ImageDraw.Draw(disc)
    d.ellipse((10, 10, s - 10, s - 10), fill=(222, 204, 168, 255), outline=INK, width=3)
    d.ellipse((s / 2 - 60, s / 2 - 60, s / 2 + 60, s / 2 + 60), outline=(150, 120, 80), width=2)
    n = len(roles)
    for k, r in enumerate(roles):
        a = -90 + k * 360 / n; rad = math.radians(a)
        ic = icon(r, 70).rotate(-(a + 90), resample=Image.BICUBIC, expand=True)
        cx = s / 2 + math.cos(rad) * (VR - 50); cy = s / 2 + math.sin(rad) * (VR - 50)
        disc.alpha_composite(ic, (int(cx - ic.width / 2), int(cy - ic.height / 2)))
        for j in range(2):  # tick marks between notches
            b = math.radians(a + 180 / n); d.line((s / 2 + math.cos(b) * (VR - 6), s / 2 + math.sin(b) * (VR - 6), s / 2 + math.cos(b) * (VR - 24), s / 2 + math.sin(b) * (VR - 24)), fill=(150, 120, 80), width=2)
    return disc
def volvelle_plate():
    s = VR * 2 + 60; m = Image.new('L', (s, s), 0); d = ImageDraw.Draw(m)
    d.ellipse((0, 0, s, s), fill=255)
    # the window: a sector cut at the top, one notch wide
    cx = s / 2; d.pieslice((cx - VR + 6, cx - VR + 6, cx + VR - 6, cx + VR - 6), -90 - 19, -90 + 19, fill=0)
    d.ellipse((cx - 72, cx - 72, cx + 72, cx + 72), fill=255)
    plate = paper_panel(s, s, (232, 218, 186), seed=3); plate.putalpha(m)
    pd = ImageDraw.Draw(plate); pd.ellipse((cx - 26, cx - 26, cx + 26, cx + 26), fill=(120, 92, 52, 255), outline=INK, width=3)  # the rivet
    pd.polygon([(cx - 16, 8), (cx + 16, 8), (cx, 34)], fill=INK)  # the pointer
    return plate
DISC = PLATE = None
def draw_volvelle(c, angle, label=None, label_col=INK):
    global DISC, PLATE
    if DISC is None: DISC = volvelle_disc(SCRIPT); PLATE = volvelle_plate()
    rd = DISC.rotate(angle, resample=Image.BICUBIC)
    c.alpha_composite(rd, (VC[0] - rd.width // 2, VC[1] - rd.height // 2))
    put(c, PLATE, (VC[0] - PLATE.width // 2, VC[1] - PLATE.height // 2), r=8, off=(4, 8), a=0.5)
    if label:
        d = ImageDraw.Draw(c); f = F(40, b=True); w = d.textlength(label, font=f)
        d.text((VC[0] - w / 2, VC[1] + VR + 34), label, font=f, fill=label_col)
def angle_for(role, extra_turns=0):
    k = SCRIPT.index(role); return k * 360 / len(SCRIPT) + 360 * extra_turns

# --- Reel B: the slot (a paper strip drawn through a slot) --------------------------------
def draw_slot(c, pos, label=None):
    x0, y0, w, h = 900, 190, 380, 300; cell = 150
    strip = Image.new('RGBA', (w - 40, cell * (len(SCRIPT) + 3)), (222, 204, 168, 255)); d = ImageDraw.Draw(strip)
    for k in range(len(SCRIPT) + 3):
        r = SCRIPT[k % len(SCRIPT)]; ic = icon(r, 110)
        strip.alpha_composite(ic, ((w - 40 - ic.width) // 2, k * cell + (cell - ic.height) // 2))
        d.line((10, k * cell, w - 50, k * cell), fill=(160, 130, 90), width=2)
    off = int(pos * cell) % (cell * len(SCRIPT))
    view = strip.crop((0, off, w - 40, off + h - 40))
    c.alpha_composite(view, (x0 + 20, y0 + 20))
    frame = paper_panel(w, h, (200, 176, 136), seed=5); m = Image.new('L', (w, h), 255); ImageDraw.Draw(m).rectangle((20, 70, w - 20, h - 70), fill=0)
    fa = frame.getchannel('A'); frame.putalpha(Image.fromarray(__import__('numpy').minimum(__import__('numpy').array(fa), __import__('numpy').array(m))))
    put(c, frame, (x0, y0), r=8, off=(5, 9))
    if label:
        dd = ImageDraw.Draw(c); f = F(40, b=True); tw = dd.textlength(label, font=f); dd.text((x0 + w / 2 - tw / 2, y0 + h + 18), label, font=f, fill=INK)

# --- Reel C: the shuffled cards (one turned over) -----------------------------------------
def draw_cards(c):
    for k, r in enumerate(['clerk', 'seer', 'gravedigger', 'medium', 'dowser']):
        card = paper_panel(150, 220, (226, 212, 180), seed=10 + k); ImageDraw.Draw(card).rectangle((10, 10, 139, 209), outline=INK, width=3)
        if k == 2: card.alpha_composite(icon(r, 110), (20, 50))
        else:
            dd = ImageDraw.Draw(card); dd.rectangle((18, 18, 131, 201), fill=(120, 40, 34, 255)); dd.text((52, 85), '?', font=F(60, b=True), fill=PAPER)
        card = card.rotate((k - 2) * 9, resample=Image.BICUBIC, expand=True)
        put(c, card, (880 + k * 70, 220 - (30 if k == 2 else 0) + abs(k - 2) * 14), r=6, off=(4, 8))

def seal(c, evil, xy):
    s = 120; im = Image.new('RGBA', (s, s)); d = ImageDraw.Draw(im)
    col = EVIL if evil else GOOD
    d.ellipse((6, 6, s - 6, s - 6), fill=col + (255,)); d.ellipse((18, 18, s - 18, s - 18), outline=tuple(int(v * 0.7) for v in col) + (255,), width=4)
    t = 'EVIL' if evil else 'GOOD'; f = F(26, b=True); w = d.textlength(t, font=f); d.text((s / 2 - w / 2, s / 2 - 15), t, font=f, fill=PAPER)
    put(c, im.rotate(-12, resample=Image.BICUBIC), xy, r=5, off=(3, 6))
def tag(c, text, xy, drop=0.0):
    f = F(30, i=True); w = int(ImageDraw.Draw(c).textlength(text, font=f)) + 40
    t = paper_panel(w, 54, (236, 226, 204), seed=21); ImageDraw.Draw(t).text((20, 10), text, font=f, fill=EVIL)
    t = t.rotate(-4 + 6 * (1 - drop), resample=Image.BICUBIC, expand=True)
    y = xy[1] - 60 * (1 - drop)
    d = ImageDraw.Draw(c); d.line((xy[0] + 24, xy[1] - 70, xy[0] + 24, y + 6), fill=INK, width=2)
    put(c, t, (xy[0], y), r=4, off=(3, 6))
def guessed(d, text): d.text((880, 140), text, font=F(28, i=True), fill=(90, 70, 50))

def save(c, name): c.convert('RGB').save(os.path.join(OUT, name), quality=92)

dead = {'hollis', 'merrin', 'jory'}
# Still 1: reel styles side by side (A volvelle, B slot, C cards) on the same overlay.
for name, fn in [('A_volvelle', lambda c: draw_volvelle(c, angle_for('medium') + 12)),
                 ('B_slot', lambda c: draw_slot(c, 3.0)),
                 ('C_cards', draw_cards)]:
    c, d = frame_base('dorian'); guessed(d, 'You guessed: Seer'); fn(c)
    town_strip(c, 'dorian', {'odette': 'poisoner'}, dead); save(c, 'reel_%s.jpg' % name)
# Still 2: landed, evil, after a fakeout (Odette claimed Seer).
c, d = frame_base('odette'); guessed(d, 'You guessed: Poisoner')
draw_volvelle(c, angle_for('poisoner'), 'Poisoner', EVIL); seal(c, True, (1290, 470))
d.text((880, 180), 'Claimed Seer on day 2. A lie, to cover the poisoning.', font=F(26, i=True), fill=INK)
town_strip(c, 'odette', {'odette': 'poisoner'}, dead); save(c, 'landed_evil.jpg')
# Still 3: landed, good, burden tag dropped.
c, d = frame_base('edda'); guessed(d, 'You guessed: Gravedigger')
draw_volvelle(c, angle_for('gravedigger'), 'Gravedigger', INK); seal(c, False, (1290, 470)); tag(c, '…and Delusional', (1180, 620), 1.0)
town_strip(c, 'edda', {'odette': 'poisoner', 'edda': 'gravedigger'}, dead); save(c, 'landed_burden.jpg')
# Still 4: reduced motion: no spin; the role card simply sets down, seal and tag appear in place.
c, d = frame_base('edda'); guessed(d, 'You guessed: Gravedigger')
card = paper_panel(300, 380, (232, 218, 186), seed=31); cd = ImageDraw.Draw(card)
card.alpha_composite(icon('gravedigger', 200), (50, 40)); f = F(38, b=True); tw = cd.textlength('Gravedigger', font=f); cd.text((150 - tw / 2, 280), 'Gravedigger', font=f, fill=INK)
put(c, card, (960, 200), r=10, off=(6, 12)); seal(c, False, (1220, 470)); tag(c, '…and Delusional', (900, 640), 1.0)
town_strip(c, 'edda', {'odette': 'poisoner', 'edda': 'gravedigger'}, dead); save(c, 'reduced_motion.jpg')

# Clip: Odette (fakeout: lands on Seer, slips to Poisoner), then Edda (Gravedigger, then the
# burden tag drops). 30 fps.
if len(sys.argv) > 2:
    fd = os.path.join(OUT, 'clip'); os.makedirs(fd, exist_ok=True); n = 0
    def ease(t): return 1 - (1 - t) ** 3
    def spin(pid, start, land, dur, hold, slip_to=None, burden=None, evil=False, revealed=None, guess=''):
        global n
        a0 = start; a1 = land
        T = dur + hold + (0.35 if slip_to is not None else 0) + 1.4
        for f in range(int(T * 30)):
            t = f / 30; c, d = frame_base(pid); guessed(d, guess); label = None; col = INK
            if t < dur: a = a0 + (a1 - a0) * ease(t / dur)
            elif slip_to is None or t < dur + hold: a = a1; label = NAMES[SCRIPT[round((a1 % 360) / (360 / len(SCRIPT))) % len(SCRIPT)]] if t > dur + 0.1 else None
            else:
                u = max(0.0, min(1, (t - dur - hold) / 0.3))
                wob = math.sin(u * math.pi * 3) * 4 * (1 - u)   # the paper catches, then slips a notch
                a = a1 + (slip_to - a1) * (u ** 0.5) + wob; label = NAMES[SCRIPT[round((slip_to % 360) / (360 / len(SCRIPT))) % len(SCRIPT)]] if u >= 1 else None
            settled = t >= dur + (hold + 0.35 if slip_to is not None else 0) + 0.15
            if settled:
                k = round(((slip_to if slip_to is not None else a1) % 360) / (360 / len(SCRIPT))) % len(SCRIPT); label = NAMES[SCRIPT[k]]; col = EVIL if SCRIPT[k] in EVILS else INK
            draw_volvelle(c, a, label, col)
            if settled and t > dur + (hold + 0.35 if slip_to is not None else 0) + 0.35: seal(c, evil, (1290, 470))
            if burden and t > T - 0.8: tag(c, burden, (1180, 620), min(1, (t - (T - 0.8)) / 0.3))
            town_strip(c, pid, revealed, dead)
            c.convert('RGB').resize((1280, 720), Image.LANCZOS).save(os.path.join(fd, 'f%04d.jpg' % n), quality=90); n += 1
    spin('odette', 0, angle_for('seer', 3), 1.7, 0.6, slip_to=angle_for('poisoner', 3) + 0, evil=True, revealed={}, guess='You guessed: Poisoner')
    spin('edda', 0, angle_for('gravedigger', 2), 1.2, 0.0, burden='…and Delusional', revealed={'odette': 'poisoner'}, guess='You guessed: Gravedigger')
    print('frames', n)
