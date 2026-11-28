"""Draws the theme's checkbox icons (Limner, Nov 28): a small cream paper square with a gold
edge, empty or with an ink tick, plus dimmed disabled versions. Drawn at 4x and reduced for
smooth edges. Writes assets/ui/checkbox_{off,on,off_disabled,on_disabled}.png.
    python3 tools/art/draw_checkbox_icons.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'ui')
SIZE = 22          # the icon's size in the game, in pixels
K = 4              # supersampling
PAPER = (240, 227, 196)
GOLD = (199, 153, 69)
GOLD_DARK = (132, 96, 38)
INK = (125, 33, 27)          # the game's red ink, as on a ticked plaque
SHADOW = (0, 0, 0, 90)


def box(ticked: bool, disabled: bool) -> Image.Image:
    s = SIZE * K
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    # A soft drop shadow, down and right.
    sh = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([3 * K, 4 * K, s - 1 * K, s - 0 * K], radius=4 * K, fill=SHADOW)
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(1.2 * K)))
    d = ImageDraw.Draw(im)
    r = [2 * K, 2 * K, s - 3 * K, s - 3 * K]
    d.rounded_rectangle(r, radius=4 * K, fill=PAPER, outline=GOLD_DARK, width=int(2.2 * K))
    d.rounded_rectangle([r[0] + 2 * K, r[1] + 2 * K, r[2] - 2 * K, r[3] - 2 * K], radius=3 * K, outline=GOLD, width=K)
    # A faint inner shade along the top and left, so the square reads as pressed into paper.
    d.line([(r[0] + 3 * K, r[1] + 3 * K), (r[2] - 4 * K, r[1] + 3 * K)], fill=(214, 196, 158), width=K)
    if ticked:
        pts = [(6.2 * K, 11.0 * K), (9.4 * K, 14.6 * K), (16.6 * K, 5.6 * K)]
        d.line(pts, fill=INK, width=int(2.8 * K), joint='curve')
        for p in pts:
            d.ellipse([p[0] - 1.35 * K, p[1] - 1.35 * K, p[0] + 1.35 * K, p[1] + 1.35 * K], fill=INK)
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    if disabled:
        grey = im.convert('LA').convert('RGBA')
        grey.putalpha(im.getchannel('A').point(lambda a: int(a * 0.55)))
        im = grey
    return im


if __name__ == '__main__':
    for name, t, dis in [('off', False, False), ('on', True, False), ('off_disabled', False, True), ('on_disabled', True, True)]:
        box(t, dis).save(os.path.join(OUT, 'checkbox_%s.png' % name), optimize=True)
        print('checkbox_%s.png' % name)
