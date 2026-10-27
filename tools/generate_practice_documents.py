#!/usr/bin/env python3
"""Generate fictional example documents. Requires Pillow, NumPy and DejaVu Sans.

The separately provided practice-photo.jpg is a reviewed synthetic image and is
not recreated by this deterministic script. Run from the repository root.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = Path('assets/samples')
OUT.mkdir(parents=True, exist_ok=True)
REGULAR = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
W, H = 1000, 1414  # A4 aspect ratio, not a promise of print resolution.
INK = '#292824'
MUTED = '#67655f'
ACCENT = '#b96045'

def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else REGULAR, size)

def document(title, subtitle):
    im = Image.new('RGB', (W, H), '#fffefa')
    d = ImageDraw.Draw(im)
    d.rectangle((74, 69, 926, 73), fill=ACCENT)
    d.text((76, 96), 'DESKSUITE  /  EXAMPLE', font=font(20, True), fill=ACCENT)
    d.text((76, 155), title, font=font(43, True), fill=INK)
    d.text((76, 220), subtitle, font=font(20), fill=MUTED)
    d.line((76, 265, 924, 265), fill='#dbd6ce', width=2)
    d.text((76, 1330), 'FICTIONAL PRACTICE MATERIAL  •  NOT AN OFFICIAL DOCUMENT', font=font(16, True), fill=MUTED)
    return im, d

def lines(d, x, y, items, gap=46, size=24):
    for line in items:
        d.text((x, y), line, font=font(size), fill=INK)
        y += gap
    return y

letter, d = document('Formal letter', 'A4 practice page  /  All names and details are fictional')
lines(d, 76, 305, [
    'Asha Example', 'Practice Lane', 'Dar es Salaam, Tanzania', '',
    '14 October 2026', '', 'The Workshop Coordinator', 'Community Learning Centre', '',
    'Dear Coordinator,', '',
    'RE: REQUEST FOR A PRACTICE WORKSHOP', '',
    'I am writing to request information about your upcoming',
    'document preparation workshop. I would be grateful for',
    'details about the schedule and available materials.', '',
    'Thank you for your consideration.', '', 'Yours faithfully,', '', 'Asha Example',
], gap=42, size=23)
letter.save(OUT / 'letter.png', optimize=True)

invoice, d = document('Example invoice', 'Fictional stationery purchase  /  Tanzanian shillings')
lines(d, 76, 310, ['Seller: Example Paper Studio', 'Customer: Fictional Workshop', 'Reference: EX-001  |  Date: 14 October 2026'], gap=42, size=23)
d.rectangle((76, 470, 924, 515), fill='#f1ede7')
d.text((90, 480), 'DESCRIPTION', font=font(20, True), fill=INK)
d.text((610, 480), 'QTY', font=font(20, True), fill=INK)
d.text((740, 480), 'AMOUNT', font=font(20, True), fill=INK)
for y, desc, qty, amount in [(545, 'A4 paper pack', '2', '24,000'), (600, 'Document folders', '4', '12,000'), (655, 'Printing service', '1', '8,000')]:
    d.text((90, y), desc, font=font(22), fill=INK)
    d.text((615, y), qty, font=font(22), fill=INK)
    d.text((740, y), amount, font=font(22), fill=INK)
    d.line((76, y+39, 924, y+39), fill='#ebe6de', width=2)
d.text((610, 745), 'TOTAL TZS', font=font(22, True), fill=INK)
d.text((760, 745), '44,000', font=font(22, True), fill=INK)
invoice.save(OUT / 'invoice.png', optimize=True)

form, d = document('Practice application', 'Example only  /  Not an official government or institutional form')
y = 320
for label in ['Full name', 'Contact email', 'Postal address', 'Purpose of application', 'Date', 'Signature']:
    d.text((76, y), label.upper(), font=font(18, True), fill=MUTED)
    d.rounded_rectangle((76, y+32, 924, y+100), radius=8, outline='#a8a29a', width=2)
    y += 138
form.save(OUT / 'application-form.png', optimize=True)

for page in (1, 2):
    report, d = document(f'Community project report  /  {page}', 'Two-page fictional example  /  A4 portrait')
    if page == 1:
        body = ['EXECUTIVE SUMMARY', '', 'This sample report describes a fictional community', 'learning session about organizing and sharing documents.', '',
                'OBJECTIVE', '', 'Participants practise creating clear documents and', 'keeping original files safe during editing and export.', '',
                'ACTIVITIES', '', '1. Review a sample letter.', '2. Prepare a clean document image.', '3. Export a copy and check the result.']
    else:
        body = ['RESULTS', '', 'The fictional workshop demonstrates a repeatable', 'workflow for local-first document preparation.', '',
                'RECOMMENDATIONS', '', '1. Keep a separate copy of important source material.', '2. Review each output before sharing it.', '3. Use suitable page sizes and readable text.', '',
                'Prepared for training purposes only.', '', 'End of example report.']
    lines(d, 76, 315, body, gap=48, size=23)
    report.save(OUT / f'report-{page}.png', optimize=True)

# Place the letter on a neutral background using a true projective warp.
# Destination corners are documented in the tutorial and used as a test fixture.
dst = [(142, 140), (760, 84), (824, 949), (95, 910)]
src = [(0, 0), (W - 1, 0), (W - 1, H - 1), (0, H - 1)]
a, b = [], []
for (x, y), (u, v) in zip(dst, src):
    a += [[x, y, 1, 0, 0, 0, -u*x, -u*y], [0, 0, 0, x, y, 1, -v*x, -v*y]]
    b += [u, v]
coeff = np.linalg.solve(np.array(a, dtype=float), np.array(b, dtype=float)).tolist()
back = Image.new('RGB', (920, 1040), '#d7d0c5')
warped = letter.transform(back.size, Image.Transform.PERSPECTIVE, coeff, resample=Image.Resampling.BICUBIC, fillcolor='#d7d0c5')
warped.save(OUT / 'perspective-letter.png', optimize=True)

# This is an editable DeskSuite graphic design, not a DOCX or word-processor file.
def layer(id, text, y, size, bold=False):
    return {'id': id, 'kind': 'text', 'x': 22, 'y': y, 'width': 166, 'height': 24,
            'rotation': 0, 'color': 4280751908, 'opacity': 1, 'text': text,
            'fontSizePt': size, 'bold': bold, 'textAlignment': 'left'}
editable = {'format': 'desksuite.design', 'version': 1, 'id': 'sample_editable_letter',
            'name': 'Example editable letter', 'widthMm': 210, 'heightMm': 297,
            'updatedAt': '2026-10-14T00:00:00.000Z', 'backgroundColor': 4294967295,
            'elements': [layer('heading', 'EXAMPLE LETTER', 22, 24, True),
                         layer('recipient', 'To: Workshop Coordinator', 57, 12),
                         layer('body', 'This is fictional practice text. Edit this design and export a copy.', 90, 12),
                         layer('closing', 'Yours faithfully,\nAsha Example', 165, 12)]}
(OUT / 'editable-example.dsdesign').write_text(json.dumps(editable, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Generated fictional sample documents in', OUT)
