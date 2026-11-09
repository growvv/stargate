# -*- coding: utf-8 -*-
"""Export the deck to 1920x1080 PNGs for the demo video."""
import os
import re
import shutil
import win32com.client as win32

BASE = os.path.dirname(os.path.abspath(__file__))
PPTX = os.path.join(BASE, 'StarGate_答辩PPT.pptx')
OUT = os.path.join(BASE, 'render_hd')
if os.path.isdir(OUT):
    shutil.rmtree(OUT)
os.makedirs(OUT)

ppt = win32.DispatchEx('PowerPoint.Application')
try:
    pres = ppt.Presentations.Open(PPTX, WithWindow=False)
    pres.Export(OUT, 'PNG', 1920, 1080)
    pres.Close()
finally:
    ppt.Quit()

files = [f for f in os.listdir(OUT) if f.lower().endswith('.png')]
def num(f):
    m = re.search(r'(\d+)', f)
    return int(m.group(1)) if m else 0
files.sort(key=num)
for i, f in enumerate(files, start=1):
    src = os.path.join(OUT, f)
    dst = os.path.join(OUT, 'slide%02d.png' % i)
    if src != dst:
        os.replace(src, dst)
print('exported', len(files), 'slides to', OUT)
