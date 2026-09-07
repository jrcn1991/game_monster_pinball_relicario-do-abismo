#!/usr/bin/env python3
"""Post-process generated prop art (props3 batch): background removal, crop, resize.

Usage: process_props3.py RAW_DIR OUT_DIR [name ...]
Looks for RAW_DIR/<name>.png (or the newest RAW_DIR/<name>*.png) and writes OUT_DIR/<name>.png
"""
import sys, glob, os
from collections import deque
import numpy as np
from PIL import Image

MAX_SIDE = 256
PAD = 4
TOL = 40

def is_light_neutral(rgb):
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    return (mn >= 150) & ((mx - mn) <= 24)

def bg_mask(arr):
    """Flood-fill mask of background from borders (median border color, tol TOL) + light-neutral."""
    h, w, _ = arr.shape
    rgb = arr[..., :3].astype(int)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    med = np.median(border, axis=0)
    near = np.abs(rgb - med).max(axis=2) <= TOL
    cand = near | is_light_neutral(arr[..., :3])
    mask = np.zeros((h, w), bool)
    q = deque()
    for y in range(h):
        for x in (0, w - 1):
            if cand[y, x] and not mask[y, x]:
                mask[y, x] = True; q.append((y, x))
    for x in range(w):
        for y in (0, h - 1):
            if cand[y, x] and not mask[y, x]:
                mask[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and cand[ny, nx] and not mask[ny, nx]:
                mask[ny, nx] = True; q.append((ny, nx))
    # enclosed-hole pass: connected components of light-neutral checker patches that look like
    # checkerboard (two alternating greys) - remove blocks of light-neutral >= 64 px inside
    ln = is_light_neutral(arr[..., :3]) & ~mask
    if ln.any():
        seen = np.zeros_like(ln)
        for y0, x0 in zip(*np.nonzero(ln)):
            if seen[y0, x0]:
                continue
            comp = []
            q = deque([(y0, x0)]); seen[y0, x0] = True
            while q:
                y, x = q.popleft(); comp.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and ln[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx))
            if len(comp) >= 64:
                ys, xs = zip(*comp)
                vals = rgb[ys, xs, 0]
                # checkerboard: at least two distinct grey levels present
                if len(np.unique(vals // 8)) >= 2:
                    mask[ys, xs] = True
    return mask

def process(src, dst):
    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    alpha = arr[..., 3]
    transp_frac = (alpha < 40).mean()
    if transp_frac < 0.15:
        m = bg_mask(arr)
        arr[m, 3] = 0
        alpha = arr[..., 3]
    ys, xs = np.nonzero(alpha >= 40)
    if len(ys) == 0:
        print(f"  !! {src}: fully transparent, skipping"); return None
    y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, arr.shape[0])
    x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, arr.shape[1])
    arr = arr[y0:y1, x0:x1]
    out = Image.fromarray(arr, "RGBA")
    if max(out.size) > MAX_SIDE:
        s = MAX_SIDE / max(out.size)
        out = out.resize((max(1, round(out.width * s)), max(1, round(out.height * s))), Image.LANCZOS)
    out.save(dst)
    a = np.array(out)[..., 3]
    tf = (a < 40).mean()
    print(f"  {os.path.basename(dst)}: {out.width}x{out.height} transparent={tf:.2f} (raw transp={transp_frac:.2f})")
    return out

def main():
    raw, out = sys.argv[1], sys.argv[2]
    names = sys.argv[3:]
    if not names:
        names = sorted({os.path.basename(p).split('.')[0].split('-v')[0] for p in glob.glob(os.path.join(raw, '*.png'))})
    for n in names:
        cands = sorted(glob.glob(os.path.join(raw, n + '*.png')), key=os.path.getmtime)
        if not cands:
            print(f"  !! no raw for {n}"); continue
        process(cands[-1], os.path.join(out, n + '.png'))

if __name__ == '__main__':
    main()
