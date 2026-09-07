#!/usr/bin/env python3
"""
process_anim.py - post-process raw GPT-generated animation frames into
registered, transparent sprite frames next to their base frames.

Re-runnable. Steps per frame:
  1. background removal (flood fill from the borders; handles white/checker)
  2. crop to alpha bbox (+4 px pad)
  3. normalize scale/position against the base frame of that character
  4. save to assets/art/stages/stageN/<character>_<frame>.png
Finally builds assets/art/stages/anim_sheet.jpg (base + frames per character).

Usage:  python3 tools/process_anim.py [--raw RAW_DIR] [--only stage1_boss_idle2 ...]
"""
import argparse
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGES = os.path.join(PROJECT, "assets", "art", "stages")
RAW_DEFAULT = ("/tmp/claude-1000/-home-pc--rea-de-trabalho-game-monster-pinball/"
               "7f393ea8-a20e-437d-a143-31d98aa00040/scratchpad/art/anim")

STAGE_NAMES = ["stage1", "stage2", "stage3"]

# character -> (frames, normalization mode)
#   "height" : scale so height == base height, bottom-align (feet)
#   "width"  : scale so width == base width, vertical-center align (flyers)
#   ("keep"  : used internally for enemy_flyer_up - no rescale, just re-canvas)
CHARACTERS = {
    "enemy_static":   (["idle2", "idle3", "attack"], "height"),
    "enemy_flyer":    (["mid", "up"], "width"),
    "enemy_guardian": (["idle2", "hit"], "height"),
    "boss":           (["idle2", "idle3", "attack", "hurt", "death"], "height"),
}

ALPHA_T = 40          # alpha threshold used everywhere
TOL = 40              # RGB tolerance vs. median border color
PAD = 4
THUMB_H = 160


# --------------------------------------------------------------------------
# background removal
# --------------------------------------------------------------------------
def _flood_from_border(candidate):
    """Vectorised 4-connected BFS from all border pixels through `candidate`.
    Returns bool mask of reached pixels."""
    h, w = candidate.shape
    visited = np.zeros_like(candidate, dtype=bool)
    ys, xs = np.nonzero(candidate)
    border = (ys == 0) | (ys == h - 1) | (xs == 0) | (xs == w - 1)
    fy, fx = ys[border], xs[border]
    visited[fy, fx] = True
    while fy.size:
        ny = np.concatenate([fy - 1, fy + 1, fy, fy])
        nx = np.concatenate([fx, fx, fx - 1, fx + 1])
        ok = (ny >= 0) & (ny < h) & (nx >= 0) & (nx < w)
        ny, nx = ny[ok], nx[ok]
        ok = candidate[ny, nx] & ~visited[ny, nx]
        ny, nx = ny[ok], nx[ok]
        if ny.size == 0:
            break
        flat = np.unique(ny.astype(np.int64) * w + nx)
        fy, fx = flat // w, flat % w
        visited[fy, fx] = True
    return visited


def _components(mask, min_px=1):
    """Yield 4-connected components of `mask` (bool) with >= min_px pixels."""
    h, w = mask.shape
    remaining = mask.copy()
    while True:
        ys, xs = np.nonzero(remaining)
        if ys.size == 0:
            return
        fy, fx = ys[:1], xs[:1]
        comp = np.zeros_like(mask)
        comp[fy, fx] = True
        while fy.size:
            ny = np.concatenate([fy - 1, fy + 1, fy, fy])
            nx = np.concatenate([fx, fx, fx - 1, fx + 1])
            ok = (ny >= 0) & (ny < h) & (nx >= 0) & (nx < w)
            ny, nx = ny[ok], nx[ok]
            ok = remaining[ny, nx] & ~comp[ny, nx]
            ny, nx = ny[ok], nx[ok]
            if ny.size == 0:
                break
            flat = np.unique(ny.astype(np.int64) * w + nx)
            fy, fx = flat // w, flat % w
            comp[fy, fx] = True
        remaining &= ~comp
        if comp.sum() >= min_px:
            yield comp


def remove_background(rgba):
    """rgba: uint8 HxWx4. Returns (rgba, removed_fraction, note)."""
    a = rgba[:, :, 3]
    transparent = (a < ALPHA_T).mean()
    if transparent >= 0.15:
        return rgba, 0.0, "already transparent (%.1f%%)" % (100 * transparent)

    rgb = rgba[:, :, :3].astype(np.int16)
    h, w = a.shape
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]], axis=0)
    med = np.median(border, axis=0)
    spread = border.max(axis=0) - border.min(axis=0)
    uniform = bool((spread <= TOL).all())

    diff = np.abs(rgb - med[None, None, :]).max(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    candidate = (diff <= TOL) & (sat <= 24)          # near the border colour, grey-ish
    note = "uniform border" if uniform else "non-uniform border (checker?)"
    if not uniform:
        near_white = (rgb >= 225).all(axis=2)
        light_grey = (rgb >= 190).all(axis=2) & (rgb <= 215).all(axis=2) & (sat <= 12)
        candidate |= near_white | light_grey

    bg = _flood_from_border(candidate)

    # enclosed holes (between an arm and the body, etc.) are not reachable from
    # the border. A hole still carries the checker texture: two grey tones
    # (~254 and ~240) in roughly equal amounts. A genuine white light burst is
    # almost entirely pure white, so it is kept.
    inner = candidate & ~bg
    if not uniform or inner.any():
        lum = rgb.mean(axis=2)
        for comp in _components(inner, min_px=40):
            v = lum[comp]
            lo = float(((v >= 228) & (v <= 248)).mean())
            hi = float((v > 248).mean())
            if lo >= 0.3 and hi >= 0.2:
                bg |= comp

    # one-pass fringe cleanup: light, unsaturated pixels touching the background
    # (anti-aliased checker/character boundary)
    nb = np.zeros_like(bg)
    nb[1:, :] |= bg[:-1, :]
    nb[:-1, :] |= bg[1:, :]
    nb[:, 1:] |= bg[:, :-1]
    nb[:, :-1] |= bg[:, 1:]
    fringe = nb & ~bg & (rgb.min(axis=2) >= 200) & (sat <= 30)
    bg |= fringe

    out = rgba.copy()
    out[bg, 3] = 0
    return out, float(bg.mean()), note


def drop_specks(rgba, min_frac=0.0004):
    """Remove tiny isolated opaque islands (stray noise pixels) that are far
    smaller than the sprite. Keeps every component with >= min_frac of pixels."""
    a = rgba[:, :, 3] >= ALPHA_T
    h, w = a.shape
    keep = np.zeros_like(a)
    min_px = max(16, int(min_frac * h * w))
    for comp in _components(a, min_px=min_px):
        keep |= comp
    out = rgba.copy()
    out[~keep & a, 3] = 0
    return out


# --------------------------------------------------------------------------
# crop / normalize
# --------------------------------------------------------------------------
def crop_alpha(img, pad=PAD):
    a = np.array(img)[:, :, 3]
    ys, xs = np.nonzero(a >= ALPHA_T)
    if ys.size == 0:
        return img
    y0, y1 = max(0, ys.min() - pad), min(img.height, ys.max() + 1 + pad)
    x0, x1 = max(0, xs.min() - pad), min(img.width, xs.max() + 1 + pad)
    return img.crop((x0, y0, x1, y1))


def normalize(frame, base, mode):
    """Scale `frame` (cropped RGBA) to register with `base` (RGBA, untouched
    base frame). Returns a new RGBA canvas."""
    bw, bh = base.size
    fw, fh = frame.size
    if mode == "height":
        s = bh / fh
    elif mode == "width":
        s = bw / fw
    else:                                 # "keep": already registered asset
        s = 1.0
    nw, nh = max(1, round(fw * s)), max(1, round(fh * s))
    if s != 1.0:
        frame = frame.resize((nw, nh), Image.LANCZOS)

    cw = max(bw, nw)                      # never clip a wider pose
    ch = bh if mode == "height" else max(bh, nh)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    x = (cw - nw) // 2
    if mode == "height":
        y = ch - nh                       # feet on the base's bottom edge
    else:
        y = (ch - nh) // 2                # flyers: vertical centre
    canvas.alpha_composite(frame, (x, y))
    return canvas


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------
def process_one(stage, char, frame, raw_dir, results):
    key = f"{stage}_{char}_{frame}"
    raw_path = os.path.join(raw_dir, key + ".png")
    base_path = os.path.join(STAGES, stage, f"{char}.png")
    out_path = os.path.join(STAGES, stage, f"{char}_{frame}.png")

    # enemy_flyer_up is an existing asset, not generated: snapshot it into RAW
    # once so the run stays re-runnable, then normalise it like the others.
    if char == "enemy_flyer" and frame == "up" and not os.path.exists(raw_path):
        if os.path.exists(out_path):
            shutil.copy2(out_path, raw_path)
    if not os.path.exists(raw_path):
        results.append((out_path, None, None, "MISSING raw " + raw_path))
        print(f"[{key}] missing raw frame, skipped")
        return

    base = Image.open(base_path).convert("RGBA")
    img = Image.open(raw_path).convert("RGBA")
    arr = np.array(img)
    arr, removed, note = remove_background(arr)
    arr = drop_specks(arr)
    img = Image.fromarray(arr, "RGBA")
    img = crop_alpha(img)
    _, mode = CHARACTERS[char]
    if char == "enemy_flyer" and frame == "up":
        # pre-existing, already-registered asset (stage1/2 were width-matched,
        # stage3 height-matched): keep its scale, only clean/crop/re-canvas.
        mode = "keep"
    out = normalize(img, base, mode)
    out.save(out_path)

    a = np.array(out)[:, :, 3]
    tfrac = float((a < ALPHA_T).mean())
    results.append((out_path, out.size, tfrac, f"bg removed {removed:.1%} ({note})"))
    print(f"[{key}] {note}; removed {removed:.1%}; out {out.size} transparent {tfrac:.1%}")


def build_sheet(path):
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    except Exception:
        font = ImageFont.load_default()
    rows = []
    for stage in STAGE_NAMES:
        for char, (frames, _) in CHARACTERS.items():
            items = [("base", os.path.join(STAGES, stage, f"{char}.png"))]
            items += [(f, os.path.join(STAGES, stage, f"{char}_{f}.png")) for f in frames]
            thumbs = []
            for label, p in items:
                if not os.path.exists(p):
                    continue
                im = Image.open(p).convert("RGBA")
                s = THUMB_H / im.height
                im = im.resize((max(1, round(im.width * s)), THUMB_H), Image.LANCZOS)
                thumbs.append((label, im))
            rw = sum(t.width + 12 for _, t in thumbs) + 140
            row = Image.new("RGBA", (rw, THUMB_H + 24), (52, 52, 58, 255))
            d = ImageDraw.Draw(row)
            d.text((6, THUMB_H // 2 - 6), f"{stage}\n{char}", fill=(230, 230, 230), font=font)
            x = 140
            for label, t in thumbs:
                row.alpha_composite(t, (x, 0))
                d.text((x, THUMB_H + 4), label, fill=(200, 200, 200), font=font)
                x += t.width + 12
            rows.append(row)
    W = max(r.width for r in rows)
    sheet = Image.new("RGB", (W, sum(r.height + 6 for r in rows)), (52, 52, 58))
    y = 0
    for r in rows:
        sheet.paste(r.convert("RGB"), (0, y))
        y += r.height + 6
    sheet.save(path, quality=88)
    print("sheet ->", path, sheet.size)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=RAW_DEFAULT)
    ap.add_argument("--only", nargs="*", help="keys like stage1_boss_idle2")
    ap.add_argument("--no-sheet", action="store_true")
    args = ap.parse_args()

    results = []
    for stage in STAGE_NAMES:
        for char, (frames, _) in CHARACTERS.items():
            for frame in frames:
                key = f"{stage}_{char}_{frame}"
                if args.only and key not in args.only:
                    continue
                process_one(stage, char, frame, args.raw, results)

    if not args.no_sheet:
        build_sheet(os.path.join(STAGES, "anim_sheet.jpg"))

    print("\nSUMMARY")
    for p, size, tf, note in results:
        rel = os.path.relpath(p, PROJECT)
        if size is None:
            print(f"  {rel}: {note}")
        else:
            print(f"  {rel}: {size[0]}x{size[1]} transparent={tf:.1%} {note}")


if __name__ == "__main__":
    main()
