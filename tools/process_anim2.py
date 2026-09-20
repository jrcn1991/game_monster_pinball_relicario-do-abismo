#!/usr/bin/env python3
"""
process_anim2.py - second batch of GPT-generated art: extra boss/guardian idle
frames, the new "rune turret" enemy (base + frames) per stage, and three table
props. Reuses the helpers of process_anim.py (background removal, crop,
normalize) and rebuilds the contact sheet with the previous rows included.

Re-runnable. Usage:
  python3 tools/process_anim2.py [--raw RAW_DIR] [--only KEY ...] [--no-sheet]
Keys look like stage1_boss_idle4, stage2_enemy_turret, prop_spinner.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from process_anim import (ALPHA_T, PROJECT, STAGES, STAGE_NAMES, THUMB_H,   # noqa: E402
                          crop_alpha, drop_specks, normalize, remove_background)
import process_anim                                                          # noqa: E402

PROPS = os.path.join(PROJECT, "assets", "art", "props")
RAW_DEFAULT = ("/tmp/claude-1000/-home-pc--rea-de-trabalho-game-monster-pinball/"
               "7f393ea8-a20e-437d-a143-31d98aa00040/scratchpad/art/anim2")

# new frames of existing characters (normalised against STAGES/stageN/<char>.png)
EXTRA_FRAMES = {
    "boss":           ["idle4", "idle5", "idle6"],
    "enemy_guardian": ["idle3"],
}
# new character: base is generated too (crop + max side 512), frames follow it
NEW_CHARACTERS = {
    "enemy_turret": ["idle2", "attack", "hurt"],
}
TURRET_MAX = 512
PROP_MAX = 256
PROP_NAMES = ["spinner", "ramp_arrow", "lane_marker"]

# full row layout for the contact sheet (base + all frames, old and new)
SHEET_ROWS = {
    "enemy_static":   ["idle2", "idle3", "attack"],
    "enemy_flyer":    ["mid", "up"],
    "enemy_guardian": ["idle2", "hit", "idle3"],
    "boss":           ["idle2", "idle3", "attack", "hurt", "death", "idle4", "idle5", "idle6"],
    "enemy_turret":   ["idle2", "attack", "hurt"],
}


def clean(raw_path):
    """raw PNG -> (cropped RGBA image, note)."""
    img = Image.open(raw_path).convert("RGBA")
    arr = np.array(img)
    arr, removed, note = remove_background(arr)
    arr = drop_specks(arr)
    img = crop_alpha(Image.fromarray(arr, "RGBA"))
    return img, f"bg removed {removed:.1%} ({note})"


def limit_side(img, max_side):
    w, h = img.size
    s = max_side / max(w, h)
    if s >= 1.0:
        return img
    return img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)


def stats(img):
    a = np.array(img)[:, :, 3]
    return img.size, float((a < ALPHA_T).mean())


def do_frame(stage, char, frame, raw_dir, results):
    key = f"{stage}_{char}_{frame}"
    raw = os.path.join(raw_dir, key + ".png")
    base_path = os.path.join(STAGES, stage, f"{char}.png")
    out_path = os.path.join(STAGES, stage, f"{char}_{frame}.png")
    if not os.path.exists(raw):
        results.append((out_path, None, None, "MISSING raw " + raw))
        print(f"[{key}] missing raw, skipped")
        return
    if not os.path.exists(base_path):
        results.append((out_path, None, None, "MISSING base " + base_path))
        print(f"[{key}] missing base, skipped")
        return
    base = Image.open(base_path).convert("RGBA")
    img, note = clean(raw)
    out = normalize(img, base, "height")
    out.save(out_path)
    size, tf = stats(out)
    results.append((out_path, size, tf, note))
    print(f"[{key}] {note}; out {size} transparent {tf:.1%}")


def do_base(stage, char, raw_dir, results):
    key = f"{stage}_{char}"
    raw = os.path.join(raw_dir, key + ".png")
    out_path = os.path.join(STAGES, stage, f"{char}.png")
    if not os.path.exists(raw):
        results.append((out_path, None, None, "MISSING raw " + raw))
        print(f"[{key}] missing raw, skipped")
        return
    img, note = clean(raw)
    img = limit_side(img, TURRET_MAX)
    img.save(out_path)
    size, tf = stats(img)
    results.append((out_path, size, tf, note))
    print(f"[{key}] {note}; out {size} transparent {tf:.1%}")


def do_prop(name, raw_dir, results):
    raw = os.path.join(raw_dir, f"prop_{name}.png")
    out_path = os.path.join(PROPS, f"{name}.png")
    if not os.path.exists(raw):
        results.append((out_path, None, None, "MISSING raw " + raw))
        print(f"[prop_{name}] missing raw, skipped")
        return
    img, note = clean(raw)
    img = limit_side(img, PROP_MAX)
    os.makedirs(PROPS, exist_ok=True)
    img.save(out_path)
    size, tf = stats(img)
    results.append((out_path, size, tf, note))
    print(f"[prop_{name}] {note}; out {size} transparent {tf:.1%}")


def build_sheet(path):
    """Same look as process_anim.build_sheet, but with the extended row layout
    (previous rows + new frames + turret rows)."""
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    except Exception:
        font = ImageFont.load_default()
    rows = []
    for stage in STAGE_NAMES:
        for char, frames in SHEET_ROWS.items():
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
            if not thumbs:
                continue
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
    # props row
    thumbs = []
    for name in PROP_NAMES:
        p = os.path.join(PROPS, f"{name}.png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            s = min(THUMB_H / im.height, 1.0)
            im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
            thumbs.append((name, im))
    if thumbs:
        rw = sum(t.width + 12 for _, t in thumbs) + 140
        row = Image.new("RGBA", (rw, THUMB_H + 24), (52, 52, 58, 255))
        d = ImageDraw.Draw(row)
        d.text((6, THUMB_H // 2 - 6), "props", fill=(230, 230, 230), font=font)
        x = 140
        for label, t in thumbs:
            row.alpha_composite(t, (x, (THUMB_H - t.height) // 2))
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
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--no-sheet", action="store_true")
    args = ap.parse_args()

    def wanted(key):
        return not args.only or key in args.only

    results = []
    for stage in STAGE_NAMES:
        for char, frames in EXTRA_FRAMES.items():
            for f in frames:
                if wanted(f"{stage}_{char}_{f}"):
                    do_frame(stage, char, f, args.raw, results)
        for char, frames in NEW_CHARACTERS.items():
            if wanted(f"{stage}_{char}"):
                do_base(stage, char, args.raw, results)
            for f in frames:
                if wanted(f"{stage}_{char}_{f}"):
                    do_frame(stage, char, f, args.raw, results)
    for name in PROP_NAMES:
        if wanted(f"prop_{name}"):
            do_prop(name, args.raw, results)

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
