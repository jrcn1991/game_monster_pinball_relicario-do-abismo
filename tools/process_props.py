"""Recorta e redimensiona os props gerados (scratchpad art/raw/prop_*.png) para assets/art/props."""
import os, sys, glob
from PIL import Image
import numpy as np
RAW = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("RELICARIO_ART_RAW", "")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art", "props")
os.makedirs(OUT, exist_ok=True)
for path in sorted(glob.glob(os.path.join(RAW, "prop_*.png"))):
    name = os.path.basename(path)[5:-4]
    if "-" in name:
        continue
    im = Image.open(path).convert("RGBA")
    a = np.array(im)[:, :, 3]
    ys, xs = np.where(a > 40)
    if len(xs) == 0:
        print("vazio:", name); continue
    box = (max(xs.min()-4,0), max(ys.min()-4,0), min(xs.max()+5, im.width), min(ys.max()+5, im.height))
    im = im.crop(box)
    m = max(im.size)
    if m > 256:
        im = im.resize((round(im.width*256/m), round(im.height*256/m)), Image.LANCZOS)
    out = os.path.join(OUT, name + ".png")
    im.save(out)
    print(name, im.size, "transp=%.2f" % (np.array(im)[:, :, 3] < 40).mean())
