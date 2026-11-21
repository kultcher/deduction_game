# Card-deck reveal mockups (Michael's two versions). PIL only.
import sys, math, os, random
OUTD = sys.argv[1]; MODE = sys.argv[2]   # 'v1' or 'v2'
sys.argv = [sys.argv[0], '.']
exec(open('mock.py').read().split('dead = {')[0])
import numpy as np
BLUE = (46, 74, 128)
CW, CH = 190, 268
def tinted(role, size):
    im = icon(role, size); a = np.array(im).astype(np.float32); col = EVIL if role in EVILS else BLUE
    dark = (a[..., :3].mean(2) < 90)[..., None]; a[..., :3] = np.where(dark, np.array(col, np.float32), a[..., :3]); return Image.fromarray(a.astype(np.uint8))
def card_face(role):
    c = paper_panel(CW, CH, (238, 226, 198), seed=hash(role) % 97); d = ImageDraw.Draw(c)
    col = EVIL if role in EVILS else BLUE
    d.rectangle((8, 8, CW - 9, CH - 9), outline=col, width=3)
    ic = tinted(role, 120); c.alpha_composite(ic, ((CW - ic.width) // 2, 34))
    f = F(24, b=True); t = NAMES[role]; w = d.textlength(t, font=f); d.text(((CW - w) / 2, CH - 56), t, font=f, fill=col)
    return c
def card_back():
    c = paper_panel(CW, CH, (110, 34, 30), seed=3); d = ImageDraw.Draw(c)
    d.rectangle((9, 9, CW - 10, CH - 10), outline=(200, 160, 80), width=3); d.rectangle((17, 17, CW - 18, CH - 18), outline=(200, 160, 80), width=1)
    cx, cy = CW / 2, CH / 2; pts = [(cx + 34 * math.cos(math.radians(-90 + k * 144)), cy + 34 * math.sin(math.radians(-90 + k * 144))) for k in range(5)]
    d.line(pts + [pts[0]], fill=(200, 160, 80), width=3); d.ellipse((cx - 42, cy - 42, cx + 42, cy + 42), outline=(200, 160, 80), width=2)
    return c
BACK = card_back(); FACES = {}
def face(r):
    if r not in FACES: FACES[r] = card_face(r)
    return FACES[r]
def draw_card(c, img, x, y, s=1.0, rot=0.0, lift=0.0, flipw=1.0, alpha=1.0):
    w = max(1, int(img.width * s * max(0.02, flipw))); h = max(1, int(img.height * s))
    im = img.resize((w, h), Image.BILINEAR)
    if rot: im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    if alpha < 1: im.putalpha(im.getchannel('A').point(lambda v: int(v * alpha)))
    put(c, im, (x - im.width / 2, y - im.height / 2), r=int(4 + lift * 10), off=(3 + lift * 10, 5 + lift * 16), a=0.45 * alpha)
def flipped(r, f):   # f 0 = back, 1 = face; returns (image, width factor)
    return (BACK if f < 0.5 else face(r)), abs(math.cos(math.pi * f))
def tear(img, seed=4):
    """Split a card along a jagged, roughly vertical tear into two halves."""
    rnd = random.Random(seed); w, h = img.size; xs = []
    x = w * 0.5
    for y in range(0, h + 8, 8): x += rnd.uniform(-7, 7); x = min(w * 0.65, max(w * 0.35, x)); xs.append((x, y))
    L = Image.new('L', (w, h), 0); ImageDraw.Draw(L).polygon([(0, 0)] + xs + [(0, h)], fill=255)
    a = np.array(img.getchannel('A')); l = np.minimum(a, np.array(L)); r = np.minimum(a, 255 - np.array(L))
    left = img.copy(); left.putalpha(Image.fromarray(l)); right = img.copy(); right.putalpha(Image.fromarray(r))
    return left, right
def ease(t): return 1 - (1 - t) ** 3
def smooth(t): t = max(0, min(1, t)); return t * t * (3 - 2 * t)

DX, DY = 1120, 410            # the deck
dead = {'hollis', 'merrin', 'jory'}
frames = []
def npc(pid, truth, fake, burden, revealed, guess, seed):
    rnd = random.Random(seed)
    pool = [r for r in SCRIPT if r not in (truth, fake)]; rnd.shuffle(pool); deal = pool[:6]
    base, d0 = frame_base(pid); guessed(d0, guess); town_strip(base, pid, revealed, dead)
    n_deal = len(deal); stack = n_deal + (2 if fake else 1)
    # timing: each dealt card takes `dur`, the next starts at 55% of it; they quicken.
    starts = []; t = 0.25; dur = []
    for i in range(n_deal):
        d = 0.42 - 0.035 * i; starts.append(t); dur.append(d); t += d * 0.55
    t_final = t + dur[-1] * 0.5
    tosses = [(rnd.uniform(-1, 1), rnd.uniform(0.6, 1.0), rnd.uniform(-400, 400)) for _ in range(n_deal)]
    T = t_final + (1.55 if fake else 0.9) + (0.9 if burden else 0.6)
    for fi in range(int(T * 30)):
        tt = fi / 30; c = base.copy()
        # how many cards still in the deck (face down, drawn as a slightly offset stack)
        gone = sum(1 for s in starts if tt >= s)
        in_deck = stack - gone
        behind = []; front = []
        for i, (s, d) in enumerate(zip(starts, dur)):
            if tt < s: continue
            u = (tt - s) / d; r = deal[i]
            if MODE == 'v1':
                side = 1 if i % 2 == 0 else -1
                if u < 0.22:     # slide off the top and flip
                    v = u / 0.22; img, fw = flipped(r, v); x = DX + side * 30 * v; y = DY - 30 * v; front.append((img, x, y, 1.0 + 0.05 * v, 0, 0.3 * v, fw))
                elif u < 0.78:   # arc up and out to the side, down beside the deck
                    v = smooth((u - 0.22) / 0.56); ang = math.pi * v
                    x = DX + side * (30 + 190 * math.sin(ang)); y = DY - 30 - 150 * math.cos(ang) * (1 - v) - 120 * math.sin(ang) * 0.5 + 60 * v
                    front.append((face(r), x, y, 1.05 + 0.1 * math.sin(ang), side * -12 * math.sin(ang), 0.3 + 0.4 * math.sin(ang), 1.0))
                elif u < 1.0:    # slide back in under the deck
                    v = smooth((u - 0.78) / 0.22); x = DX + side * 30 * (1 - v) + side * 0; y = DY + 30 * (1 - v)
                    x = DX + side * 190 * (1 - v); behind.append((face(r), x, y, 1.0, 0, 0.1, 1.0))
            else:
                vx, up, spin = tosses[i]
                if u < 0.25:
                    v = u / 0.25; img, fw = flipped(r, v); front.append((img, DX, DY - 40 * v, 1.0 + 0.08 * v, 0, 0.4 * v, fw))
                else:
                    v = (u - 0.25) * d * 1.6   # seconds in flight (scaled)
                    x = DX + vx * 900 * v; y = DY - 40 - up * 700 * v + 1500 * v * v
                    if y < 1100: front.append((face(r), x, y, 1.08, spin * v, 0.5, 1.0))
        # the deck: real card (and false card) still at the bottom
        for k in range(max(0, in_deck) - 1, -1, -1):
            pass
        for img, x, y, s, rot, lift, fw in behind: draw_card(c, img, x, y, s, rot, lift, fw)
        deck_n = max(1, in_deck)
        top_is_final = tt >= t_final
        if not top_is_final:
            for k in range(deck_n):
                draw_card(c, BACK, DX - k * 1.5, DY - k * 1.5, 1.0, 0, 0.0 if k else 0.1)
        for img, x, y, s, rot, lift, fw in front: draw_card(c, img, x, y, s, rot, lift, fw)
        # the final card(s)
        if top_is_final:
            u = tt - t_final
            label = None; col = INK; settled = False
            if fake:
                if u < 0.22:                                   # the false card flips in place
                    img, fw = flipped(fake, u / 0.22); draw_card(c, img, DX, DY, 1.0, 0, 0.1, fw)
                elif u < 0.62:                                 # starts to push out
                    v = smooth((u - 0.22) / 0.4) * 0.45
                    draw_card(c, face(truth), DX, DY, 1.0, 0, 0.05)
                    draw_card(c, face(fake), DX, DY - 4 * v, 1.0 + 0.36 * v, 0, 0.1 + 0.6 * v)
                    label = NAMES[fake]; col = EVIL if fake in EVILS else BLUE
                elif u < 1.12:                                 # torn in half and tossed away
                    v = (u - 0.62) / 0.5
                    draw_card(c, face(truth), DX, DY, 1.0 + 0.02 * v, 0, 0.1)
                    s0 = 1.0 + 0.36 * 0.45; L, Rr = tear(face(fake).resize((int(CW * s0), int(CH * s0))))
                    for half, sgn in ((L, -1), (Rr, 1)):
                        x = DX + sgn * (20 + 420 * v); y = DY - 6 - 120 * v + 900 * v * v
                        im = half.rotate(sgn * -70 * v, resample=Image.BICUBIC, expand=True)
                        put(c, im, (x - im.width / 2, y - im.height / 2), r=8, off=(8, 14), a=0.4)
                    if v < 0.3:
                        dd = ImageDraw.Draw(c); f = F(40, b=True); t_ = NAMES[fake]; w = dd.textlength(t_, font=f)
                        dd.text((DX - w / 2, DY + 196), t_, font=f, fill=INK); dd.line((DX - w / 2 - 6, DY + 220, DX + w / 2 + 6, DY + 216), fill=EVIL, width=4)
                else:
                    v = smooth((u - 1.12) / 0.3); draw_card(c, face(truth), DX, DY - 4 * v, 1.0 + 0.36 * v, 0, 0.1 + 1.0 * v); settled = v >= 1
                    label = NAMES[truth]; col = EVIL if truth in EVILS else BLUE
                    u2 = u - 1.42
            else:
                if u < 0.22:
                    img, fw = flipped(truth, u / 0.22); draw_card(c, img, DX, DY, 1.0, 0, 0.1, fw)
                else:
                    v = smooth((u - 0.22) / 0.3); draw_card(c, face(truth), DX, DY - 4 * v, 1.0 + 0.36 * v, 0, 0.1 + 1.0 * v)
                    label = NAMES[truth]; col = EVIL if truth in EVILS else BLUE; u2 = u - 0.52
            if label:
                dd = ImageDraw.Draw(c); f = F(40, b=True); w = dd.textlength(label, font=f); dd.text((DX - w / 2, DY + 196), label, font=f, fill=col)
            land = (t_final + (1.42 if fake else 0.52))
            if tt > land + 0.15: seal(c, truth in EVILS, (DX + 140, DY + 70))
            if burden and tt > land + 0.55: tag(c, burden, (DX - 330, DY + 150), min(1, (tt - land - 0.55) / 0.3))
            if fake and tt > land + 0.1:
                dd = ImageDraw.Draw(c); dd.text((880, 176), 'Claimed Seer on the second day. False.', font=F(26, i=True), fill=INK)
        frames.append(c.convert('RGB').resize((1280, 720), Image.LANCZOS))
npc('odette', 'poisoner', 'seer', None, {}, 'You guessed: Minion', 1)
npc('edda', 'gravedigger', None, '…and Delusional', {'odette': 'poisoner'}, 'You guessed: Gravedigger', 2)
os.makedirs(OUTD, exist_ok=True)
for i, f in enumerate(frames): f.save(os.path.join(OUTD, 'f%04d.jpg' % i), quality=88)
print(MODE, len(frames), 'frames')
