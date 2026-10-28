#!/usr/bin/env python3
"""Create three fictional, reproducible document-scanning practice images.

Requires Pillow and NumPy. Fonts are the Noto Sans files already bundled with
DeskSuite. These are synthetic exercises, not camera photographs or OCR-quality
benchmarks. Run from the repository root; existing source files are untouched.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path('assets/samples')
OUT.mkdir(parents=True, exist_ok=True)
REGULAR = 'assets/fonts/NotoSans-Regular.ttf'
BOLD = 'assets/fonts/NotoSans-Bold.ttf'
W, H = 1200, 1697


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else REGULAR, size)


def text(draw, xy, content, size, color, bold=False):
    draw.text(xy, content, font=font(size, bold), fill=color)


paper = Image.new('RGB', (W, H), '#fdfcf8')
d = ImageDraw.Draw(paper)
navy = '#20384d'
ink = '#293743'
muted = '#62737c'
teal = '#258679'
copper = '#c67c55'
pale = '#edf4f1'

# Wide margins, clear hierarchy and legible fictional copy, rendered as pixels.
d.rounded_rectangle((72, 72, 1128, 168), radius=12, fill=navy)
text(d, (100, 91), 'DESKSUITE  /  PRACTICE DOCUMENT', 24, '#ffffff', True)
text(d, (100, 126), 'FICTIONAL EXAMPLE  •  NOT AN OFFICIAL RECORD', 17, '#c9dbdd', True)
text(d, (73, 214), 'Community garden', 48, navy, True)
text(d, (73, 282), 'FIELD REPORT', 23, teal, True)
text(d, (73, 332), 'A sample page for scan enhancement and text review', 22, muted)
d.line((73, 390, 1127, 390), fill='#dce4e0', width=3)

text(d, (73, 425), 'PROJECT OVERVIEW', 20, teal, True)
paragraphs = [
    'This fictional report records observations from a community',
    'garden. It is designed for practising a real document workflow:',
    'compare the original, reduce uneven lighting, inspect the text,',
    'and save a new copy without replacing the source image.',
]
for i, line in enumerate(paragraphs):
    text(d, (73, 470 + i * 38), line, 24, ink)

# Two editorial callouts exercise soft colors and small, readable ink.
for x, heading, value, detail in [
    (73, 'PLOTS VISITED', '12', 'example locations'),
    (430, 'WATERING DAYS', '03', 'fictional observations'),
    (787, 'NEXT REVIEW', 'NOV', 'practice schedule'),
]:
    d.rounded_rectangle((x, 680, x + 340, 829), radius=12, fill=pale)
    text(d, (x + 21, 698), heading, 15, muted, True)
    text(d, (x + 21, 731), value, 39, teal, True)
    text(d, (x + 21, 786), detail, 16, muted)

text(d, (73, 876), 'OBSERVATIONS', 20, teal, True)
lines = [
    'The garden beds remained damp after the morning watering.',
    'New leaves appeared near the shaded fence. The team noted',
    'that light and shadow can make small writing harder to read.',
    'Review every processed page before using its extracted text.',
]
for i, line in enumerate(lines):
    text(d, (73, 920 + i * 38), line, 24, ink)

text(d, (73, 1120), 'EXAMPLE WATER LEVELS', 20, teal, True)
text(d, (73, 1153), 'Compare these colored bars after enhancement.', 18, muted)
for i, (label, length, color) in enumerate([
    ('DAY 1', 330, teal),
    ('DAY 2', 490, copper),
    ('DAY 3', 410, '#5789a8'),
]):
    y = 1204 + i * 66
    text(d, (73, y), label, 18, ink, True)
    d.rounded_rectangle((205, y + 2, 205 + length, y + 27), radius=6, fill=color)

text(d, (73, 1450), 'CHECK BEFORE EXPORT', 20, teal, True)
text(d, (73, 1490), '• Compare fine text and colored areas with the original.', 22, ink)
text(d, (73, 1527), '• Keep the imported file and save the result as a new copy.', 22, ink)
d.line((73, 1594, 1127, 1594), fill='#dce4e0', width=3)
text(d, (73, 1617), 'DESKSUITE  /  FICTIONAL PRACTICE MATERIAL', 15, muted, True)
text(d, (1060, 1617), '01', 15, muted, True)
paper.save(OUT / 'clean-practice-page.png', optimize=True)

# Broad, soft, deliberately uneven illumination affects ink and paper alike.
# Seeded subtle sensor-like texture helps show limits without making text fuzzy.
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
x /= W - 1
y /= H - 1
broad = .19 * np.exp(-(((x - .35) / .29) ** 2 + ((y - .44) / .48) ** 2))
edge = .10 / (1 + np.exp((x - .24 + .13 * y) * 22))
light = np.clip(.63 + .23 * x + .09 * y - broad - edge, .35, .98)
channel_cast = np.array([1.025, 1.0, .96], dtype=np.float32)
rng = np.random.default_rng(20261028)
noise = rng.normal(0, .75, (H, W, 1)).astype(np.float32)
shaded_array = np.clip(
    np.asarray(paper, dtype=np.float32) * light[..., None] * channel_cast + noise,
    0,
    255,
).astype(np.uint8)
shaded = Image.fromarray(shaded_array, 'RGB')
shaded.save(OUT / 'shadowed-practice-page.png', optimize=True)

# A synthetic desk scene with a perspective-warped page, for corner correction.
# Destination points are reproduced in the tests (top-left, clockwise).
SW, SH = 1500, 1900
yy, xx = np.mgrid[0:SH, 0:SW]
texture = rng.normal(0, 1.7, (SH, SW))
lighting = 10 * xx / SW + 6 * yy / SH
back_array = np.empty((SH, SW, 3), dtype=np.uint8)
for i, base in enumerate((53, 61, 65)):
    back_array[:, :, i] = np.clip(base + lighting + texture, 0, 255)
back = Image.fromarray(back_array, 'RGB').convert('RGBA')
dst = [(250, 195), (1260, 120), (1322, 1724), (188, 1770)]
src = [(0, 0), (W - 1, 0), (W - 1, H - 1), (0, H - 1)]
a, b = [], []
for (x1, y1), (u, v) in zip(dst, src):
    a.extend([[x1, y1, 1, 0, 0, 0, -u*x1, -u*y1],
              [0, 0, 0, x1, y1, 1, -v*x1, -v*y1]])
    b.extend([u, v])
coeff = np.linalg.solve(np.array(a, dtype=float), np.array(b, dtype=float)).tolist()
mask = Image.new('L', (W, H), 255).transform(
    (SW, SH), Image.Transform.PERSPECTIVE, coeff,
    resample=Image.Resampling.BICUBIC, fillcolor=0,
)
shadow = Image.new('L', (SW, SH), 0)
shadow.paste(mask, (15, 20))
shadow = shadow.filter(ImageFilter.GaussianBlur(24)).point(lambda p: p * 0.38)
back.alpha_composite(Image.merge('RGBA', (Image.new('L', (SW, SH), 0),) * 3 + (shadow,)))
warped = shaded.convert('RGBA').transform(
    (SW, SH), Image.Transform.PERSPECTIVE, coeff,
    resample=Image.Resampling.BICUBIC, fillcolor=(0, 0, 0, 0),
)
back.alpha_composite(warped)
back.convert('RGB').save(OUT / 'angled-practice-page.jpg', quality=92, subsampling=0, optimize=True)
print('Generated clean, shadowed and perspective fictional practice pages in', OUT)
