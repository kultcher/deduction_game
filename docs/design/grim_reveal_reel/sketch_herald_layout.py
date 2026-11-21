# Herald's layout (town row on top, centred panel, reel under the portrait), both reel styles.
import sys, math
sys.argv = [sys.argv[0], sys.argv[1]]
exec(open('mock.py').read().split('dead = {')[0])
import numpy as np
BLUE = (46, 74, 128); VIOLET = (98, 56, 128)
def tinted(role, size):
    im = icon(role, size); a = np.array(im).astype(np.float32)
    col = EVIL if role in EVILS else BLUE
    dark = (a[..., :3].mean(2) < 90)[..., None]
    a[..., :3] = np.where(dark, np.array(col, np.float32), a[..., :3]); return Image.fromarray(a.astype(np.uint8))
def town_row(c, current, revealed, dead):
    n = len(TOWN); tile = 70; gap = 10; x0 = (W - (n * tile + (n - 1) * gap)) // 2; y0 = 18
    for i, pid in enumerate(TOWN):
        p = Image.open(R + 'assets/art/cast_expressions/%s/neutral-v1.png' % pid).convert('RGBA')
        p = p.crop((p.width * 0.22, p.height * 0.06, p.width * 0.78, p.height * 0.06 + p.width * 0.56)).resize((tile - 10, tile - 10), Image.LANCZOS)
        card = paper_panel(tile, tile, (226, 212, 180), seed=i); card.alpha_composite(p, (5, 5))
        if pid in dead and pid not in revealed and pid != current: card = grey(card)
        y = y0 + (10 if pid == current else 0)
        put(c, card, (x0 + i * (tile + gap), y), r=4, off=(3, 5) if pid != current else (5, 10))
        if pid in revealed:
            role = revealed[pid]; disc = Image.new('RGBA', (34, 34)); ImageDraw.Draw(disc).ellipse((0, 0, 33, 33), fill=(EVIL if role in EVILS else GOOD) + (255,))
            disc.alpha_composite(ImageOps.contain(icon(role, 24), (22, 22)), (6, 6)); put(c, disc, (x0 + i * (tile + gap) + tile - 24, y + tile - 24), r=2, off=(2, 3))
def base(pid):
    c = BG.copy(); px, py, pw, ph = 420, 112, 760, 778
    put(c, paper_panel(pw, ph, seed=8), (px, py), r=16, off=(10, 18), a=0.6)
    pr = Image.open(R + 'assets/art/cast_expressions/%s/neutral-v1.png' % pid).convert('RGBA')
    pr = pr.crop((0, 0, pr.width, int(pr.width * 0.62))).resize((420, int(420 * 0.62)), Image.LANCZOS)
    put(c, pr, (W // 2 - 210, py + 14), r=10, off=(6, 10))
    d = ImageDraw.Draw(c); f = F(38, b=True); t = pid.capitalize(); d.text((W // 2 - d.textlength(t, font=f) / 2, py + 284), t, font=f, fill=INK)
    for k, lab in enumerate(['Skip', 'Next ▸']):
        b = paper_panel(110, 44, (214, 196, 160), seed=40 + k); bd = ImageDraw.Draw(b); bd.text((18, 8), lab, font=F(26, b=True), fill=INK)
        put(c, b, (px + pw - 250 + k * 124, py + ph - 64), r=3, off=(2, 4))
    return c, d
def guess_line(c, text, ok=None):
    d = ImageDraw.Draw(c); f = F(26, i=True); w = d.textlength(text, font=f); x = px0 = 450; y = 840
    d.text((x, y), text, font=f, fill=(90, 70, 50))
    if ok is not None: d.text((x + w + 12, y - 4), '✓' if ok else '✗', font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 30), fill=(60, 110, 50) if ok else EVIL)
def label(c, text, col):
    d = ImageDraw.Draw(c); f = F(36, b=True); w = d.textlength(text, font=f); d.text((W // 2 - w / 2, 642), text, font=f, fill=col)
def keyline(c, text):
    d = ImageDraw.Draw(c); f = F(22, i=True); w = d.textlength(text, font=f); d.text((W // 2 - w / 2, 700), text, font=f, fill=INK)

# Slot, Herald's: a horizontal window under the portrait, icons scrolling vertically.
def slot(c, pos):
    x0, y0, w, h = W // 2 - 95, 384, 190, 236; cell = 110
    strip = Image.new('RGBA', (w - 30, cell * (len(SCRIPT) + 3)), (222, 204, 168, 255)); d = ImageDraw.Draw(strip)
    for k in range(len(SCRIPT) + 3):
        r = SCRIPT[k % len(SCRIPT)]; ic = tinted(r, 84)
        strip.alpha_composite(ic, ((w - 30 - ic.width) // 2, k * cell + (cell - ic.height) // 2))
        d.line((8, k * cell, w - 38, k * cell), fill=(170, 140, 100), width=2)
    off = int(pos * cell - (h - 30 - cell) / 2) % (cell * len(SCRIPT))
    c.alpha_composite(strip.crop((0, off, w - 30, off + h - 30)), (x0 + 15, y0 + 15))
    fr = paper_panel(w, h, (196, 172, 132), seed=5); m = np.array(fr.getchannel('A')); m[15 + 48:h - 15 - 48, 15:w - 15] = 0
    fr.putalpha(Image.fromarray(m)); put(c, fr, (x0, y0), r=6, off=(4, 8))
    dd = ImageDraw.Draw(c); dd.polygon([(x0 - 14, y0 + h / 2 - 12), (x0 - 14, y0 + h / 2 + 12), (x0 + 2, y0 + h / 2)], fill=INK)
# Volvelle, scaled into the same space.
def wheel(c, angle):
    global VR, VC, DISC, PLATE
    VR = 118; VC = (W // 2, 506); DISC = None; PLATE = None
    exec_globals = globals()
    # rebuild with tinted icons
    s = VR * 2 + 20; disc = Image.new('RGBA', (s, s)); d = ImageDraw.Draw(disc)
    d.ellipse((10, 10, s - 10, s - 10), fill=(222, 204, 168, 255), outline=INK, width=3)
    n = len(SCRIPT)
    for k, r in enumerate(SCRIPT):
        a = -90 + k * 360 / n; rad = math.radians(a); ic = tinted(r, 50).rotate(-(a + 90), resample=Image.BICUBIC, expand=True)
        cx = s / 2 + math.cos(rad) * (VR - 36); cy = s / 2 + math.sin(rad) * (VR - 36)
        disc.alpha_composite(ic, (int(cx - ic.width / 2), int(cy - ic.height / 2)))
    rd = disc.rotate(angle, resample=Image.BICUBIC); c.alpha_composite(rd, (VC[0] - rd.width // 2, VC[1] - rd.height // 2))
    plate = volvelle_plate(); put(c, plate, (VC[0] - plate.width // 2, VC[1] - plate.height // 2), r=8, off=(4, 8), a=0.5)

dead = {'hollis', 'merrin', 'jory'}
rev = {'odette': 'poisoner'}
for name, fn, lab in [('herald_layout_slot', lambda c: slot(c, SCRIPT.index('gravedigger')), True),
                      ('herald_layout_wheel', lambda c: wheel(c, angle_for('gravedigger')), True),
                      ('herald_layout_slot_spinning', lambda c: slot(c, 5.45), False)]:
    c, d = base('edda'); fn(c)
    if lab:
        label(c, 'Gravedigger  ·  Good', BLUE); tag(c, '…and Delusional', (W // 2 - 120, 752), 1.0)
        keyline(c, 'Read Odette as the Poisoner on the second night. The reading was false.')
        guess_line(c, 'You guessed: Gravedigger', True)
    else: guess_line(c, 'You guessed: Gravedigger')
    town_row(c, 'edda', rev, dead); c.convert('RGB').save(name + '.jpg', quality=92)
print('ok')
