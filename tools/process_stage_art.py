#!/usr/bin/env python3
"""Post-process generated stage/UI art for Relicário do Abismo.

Re-runnable. Reads raw generations from RAW_DIR (override with --raw or the
RELICARIO_ART_RAW env var) and writes finished assets to assets/art/stages/<stageN>/
and assets/art/ui/.

Sprites  : alpha check (>=15 % transparent, else flood-fill bg removal),
           crop to alpha bbox (alpha>40), pad 4 px, fit larger side to 512 (LANCZOS).
Backgrounds: cover + center-crop to 820x1080, darken (max 25 %) so mean luma < 70.
UI       : cover + center-crop to fixed sizes, opaque RGB.
"""
import argparse
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_RAW = ("/tmp/claude-1000/-home-pc--rea-de-trabalho-game-monster-pinball/"
               "7f393ea8-a20e-437d-a143-31d98aa00040/scratchpad/art/raw")
OUT_STAGES = os.path.join(PROJECT, "assets", "art", "stages")
OUT_UI = os.path.join(PROJECT, "assets", "art", "ui")

ALPHA_T = 40          # alpha threshold for "transparent"
MIN_TRANSP = 0.15     # below this the generation is considered non-transparent
PAD = 4
MAX_SIDE = 512
BG_SIZE = (820, 1080)
BG_MAX_LUMA = 70.0
BG_MAX_DARKEN = 0.25
FLOOD_TOL = 28        # colour tolerance for the flood-fill fallback

SPRITES = ["boss", "enemy_static", "enemy_flyer", "enemy_guardian", "guardian_shield"]
STAGES = ["stage1", "stage2", "stage3"]
UI = {"menu_bg": (1920, 1080), "side_panel": (550, 1080)}

report = []
failures = []


def transparent_fraction(arr):
    return float((arr[:, :, 3] < ALPHA_T).mean())


def flood_remove_background(arr):
    """Flood-fill from the four corners, clearing alpha of similar-coloured pixels."""
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3].astype(np.int16)
    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    for y, x in ((0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)):
        q.append((y, x, rgb[y, x].copy()))
        visited[y, x] = True
    while q:
        y, x, ref = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if np.abs(rgb[ny, nx] - ref).max() <= FLOOD_TOL:
                    visited[ny, nx] = True
                    q.append((ny, nx, ref))
    arr = arr.copy()
    arr[visited, 3] = 0
    return arr


def process_sprite(src, dst):
    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    frac = transparent_fraction(arr)
    note = ""
    if frac < MIN_TRANSP:
        arr = flood_remove_background(arr)
        frac2 = transparent_fraction(arr)
        note = f"bg removed by flood-fill ({frac:.2f} -> {frac2:.2f})"
        failures.append(f"{src}: not transparent ({frac:.2f}); {note}")
        frac = frac2
    mask = arr[:, :, 3] > ALPHA_T
    if not mask.any():
        failures.append(f"{src}: empty alpha, skipped")
        return
    ys, xs = np.where(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = Image.fromarray(arr[y0:y1, x0:x1])
    w, h = crop.size
    canvas = Image.new("RGBA", (w + 2 * PAD, h + 2 * PAD), (0, 0, 0, 0))
    canvas.paste(crop, (PAD, PAD))
    if max(canvas.size) > MAX_SIDE:
        s = MAX_SIDE / max(canvas.size)
        canvas = canvas.resize((max(1, round(canvas.width * s)),
                                max(1, round(canvas.height * s))), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    canvas.save(dst, optimize=True)
    out_frac = transparent_fraction(np.array(canvas))
    report.append((dst, f"{canvas.width}x{canvas.height}", f"{out_frac:.2f}", note))


def cover_crop(im, size):
    tw, th = size
    s = max(tw / im.width, th / im.height)
    nw, nh = max(tw, round(im.width * s)), max(th, round(im.height * s))
    im = im.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - tw) // 2, (nh - th) // 2
    return im.crop((left, top, left + tw, top + th))


def process_background(src, dst, size=BG_SIZE, limit_luma=True):
    im = cover_crop(Image.open(src).convert("RGB"), size)
    note = ""
    if limit_luma:
        luma = np.array(im.convert("L")).mean()
        if luma > BG_MAX_LUMA:
            factor = max(1.0 - BG_MAX_DARKEN, BG_MAX_LUMA / luma)
            im = Image.fromarray((np.array(im).astype(np.float32) * factor)
                                 .clip(0, 255).astype(np.uint8))
            note = f"darkened x{factor:.2f} (luma {luma:.0f})"
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, optimize=True)
    luma = np.array(im.convert("L")).mean()
    report.append((dst, f"{im.width}x{im.height}", "-", note or f"luma {luma:.0f}"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=os.environ.get("RELICARIO_ART_RAW", DEFAULT_RAW))
    args = ap.parse_args()
    raw = args.raw
    art = os.path.dirname(os.path.abspath(raw))  # RAW/.. holds the stage-1 references

    for stage in STAGES:
        out = os.path.join(OUT_STAGES, stage)
        bg = os.path.join(art, "background_gen.png") if stage == "stage1" \
            else os.path.join(raw, f"{stage}_background.png")
        if os.path.exists(bg):
            process_background(bg, os.path.join(out, "background.png"))
        else:
            failures.append(f"missing {bg}")
        for name in SPRITES:
            src = os.path.join(art, "bishop_gen.png") if (stage, name) == ("stage1", "boss") \
                else os.path.join(raw, f"{stage}_{name}.png")
            if os.path.exists(src):
                process_sprite(src, os.path.join(out, f"{name}.png"))
            else:
                failures.append(f"missing {src}")

    for name, size in UI.items():
        src = os.path.join(raw, f"ui_{name}.png")
        if os.path.exists(src):
            process_background(src, os.path.join(OUT_UI, f"{name}.png"), size, limit_luma=False)
        else:
            failures.append(f"missing {src}")

    print(f"{'output':<80} {'size':>10} {'transp':>7}  note")
    for path, size, frac, note in report:
        print(f"{os.path.relpath(path, PROJECT):<80} {size:>10} {frac:>7}  {note}")
    if failures:
        print("\nFAILURES / FALLBACKS:")
        for f in failures:
            print("  -", f)
    return 1 if any("missing" in f or "skipped" in f for f in failures) else 0


if __name__ == "__main__":
    sys.exit(main())
