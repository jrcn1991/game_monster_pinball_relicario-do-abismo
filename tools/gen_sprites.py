#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_sprites.py

Procedurally generates ORIGINAL placeholder pixel-art sprites for the
gothic-fantasy pinball game "Relicario do Abismo".

Everything is drawn with PIL (ImageDraw) + numpy (noise/gradients/dithering).
No external assets, no downloads, no text, no real religious symbols
(all runes/glyphs are invented). Deterministic (seeded RNG).

Usage:
    python3 tools/gen_sprites.py
"""

import os
import math
import random

import numpy as np
from PIL import Image, ImageDraw

# ----------------------------------------------------------------------------
# Setup
# ----------------------------------------------------------------------------

SEED = 1337
random.seed(SEED)
np.random.seed(SEED)

PROJECT = "/home/pc/Área de trabalho/game_monster_pinball"
OUT_DIR = os.path.join(PROJECT, "assets", "art")
os.makedirs(OUT_DIR, exist_ok=True)

# ----------------------------------------------------------------------------
# Palette
# ----------------------------------------------------------------------------

BG_BLUE      = (9, 10, 18, 255)
STONE_DARK   = (36, 36, 55, 255)
STONE_LIGHT  = (57, 54, 77, 255)
BRONZE       = (140, 98, 57, 255)
BRONZE_LIGHT = (214, 168, 95, 255)
VIOLET       = (123, 43, 191, 255)
VIOLET_LIGHT = (199, 125, 255, 255)
RED_DANGER   = (230, 57, 70, 255)
GOLD         = (244, 211, 94, 255)
IVORY        = (232, 223, 200, 255)
BLACK        = (4, 4, 7, 255)
OUTLINE      = (6, 5, 10, 255)

GREY_ASH     = (118, 116, 128, 255)
GREY_ASH_D   = (78, 76, 90, 255)


def shade(c, factor):
    """Multiply RGB by factor (darken <1, lighten >1), clamp, keep alpha."""
    r, g, b = c[0], c[1], c[2]
    a = c[3] if len(c) > 3 else 255
    r = max(0, min(255, int(r * factor)))
    g = max(0, min(255, int(g * factor)))
    b = max(0, min(255, int(b * factor)))
    return (r, g, b, a)


def mix(c1, c2, t):
    """Linear-interpolate two RGBA colors, t in [0,1]."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


def with_alpha(c, a):
    return (c[0], c[1], c[2], a)


# ----------------------------------------------------------------------------
# Small helpers for "chunky" pixel-art rendering
# ----------------------------------------------------------------------------

def canvas(w, h):
    """New transparent RGBA canvas at reduced (draw) resolution."""
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def upscale(img, w, h):
    """Nearest-neighbour upscale to final target size -> crisp pixel blocks."""
    return img.resize((w, h), Image.NEAREST)


def np_img(img):
    return np.array(img).astype(np.int16)


def from_np(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def add_noise(img, amount=10, only_where_opaque=True, seed=None):
    """Add per-pixel RGB grain to an RGBA image (dithering / texture)."""
    if seed is not None:
        rng = np.random.RandomState(seed)
    else:
        rng = np.random
    arr = np_img(img)
    h, w = arr.shape[0], arr.shape[1]
    noise = rng.randint(-amount, amount + 1, size=(h, w, 1)).astype(np.int16)
    if only_where_opaque:
        mask = (arr[:, :, 3:4] > 0).astype(np.int16)
    else:
        mask = 1
    arr[:, :, 0:3] = arr[:, :, 0:3] + noise * mask
    return from_np(arr)


def radial_field(w, h, center, radius):
    """Return normalized (0..1, clamped) distance field from center / radius."""
    yy, xx = np.mgrid[0:h, 0:w]
    dist = np.sqrt((xx - center[0]) ** 2 + (yy - center[1]) ** 2)
    return dist / radius, dist


def radial_sphere(w, h, center, radius, c_center, c_edge, bands=0):
    """Filled circle with radial gradient (optionally banded for retro shading)."""
    t, dist = radial_field(w, h, center, radius)
    t = np.clip(t, 0, 1)
    if bands > 0:
        t = np.floor(t * bands) / bands
    arr = np.zeros((h, w, 4), dtype=np.float32)
    for i in range(4):
        arr[:, :, i] = c_center[i] + (c_edge[i] - c_center[i]) * t
    out = np.zeros((h, w, 4), dtype=np.uint8)
    inside = dist <= radius
    out[inside] = arr[inside].astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def radial_glow(w, h, center, radius, color, max_alpha=180):
    """Soft additive-looking radial glow (falls off to 0 alpha at radius)."""
    t, dist = radial_field(w, h, center, radius)
    t = np.clip(1.0 - t, 0, 1) ** 1.6
    a = (t * max_alpha).astype(np.uint8)
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    arr[:, :, 0] = color[0]
    arr[:, :, 1] = color[1]
    arr[:, :, 2] = color[2]
    arr[:, :, 3] = a
    return Image.fromarray(arr, "RGBA")


def paste(base, top, pos=(0, 0)):
    base.alpha_composite(top, dest=pos)


def outline_polygon(draw, pts, fill, outline=OUTLINE, width=1):
    draw.polygon(pts, fill=fill)
    if outline is not None:
        draw.polygon(pts, outline=outline, width=width)


def save_png(img, name, expected_size):
    path = os.path.join(OUT_DIR, name)
    if img.size != expected_size:
        raise ValueError(f"{name}: built size {img.size} != expected {expected_size}")
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    img.save(path, "PNG")
    return path


def bayer_dither(w, h, amount=6):
    """Small 4x4 Bayer ordered-dither pattern tiled across w x h, centered on 0."""
    m = np.array([[0, 8, 2, 10],
                  [12, 4, 14, 6],
                  [3, 11, 1, 9],
                  [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5
    tile = np.tile(m, (h // 4 + 1, w // 4 + 1))[:h, :w]
    return (tile * amount).astype(np.int16)


# ----------------------------------------------------------------------------
# 1. ball.png 32x32 - luminous ivory/gold sphere
# ----------------------------------------------------------------------------

def gen_ball():
    S = 2
    w, h = 32 // S, 32 // S  # 16x16
    img = canvas(w, h)

    cx, cy, r = w / 2, h / 2, w / 2 - 1.2

    # thin violet rim glow behind the sphere
    rim = radial_sphere(w, h, (cx, cy), r + 1.4, VIOLET_LIGHT, with_alpha(VIOLET, 0), bands=0)
    paste(img, rim)

    # main sphere body: bright core -> gold -> warm bronze edge, banded for retro shading
    body = radial_sphere(w, h, (cx - 1.0, cy - 1.0), r, mix(IVORY, (255, 255, 255, 255), 0.6), BRONZE_LIGHT, bands=6)
    paste(img, body)

    d = ImageDraw.Draw(img)
    # subtle darker contour just at the very edge (keeps ball readable on any bg)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=with_alpha(shade(BRONZE_LIGHT, 0.7), 160))

    # specular highlight top-left - brightest thing in the game
    hi = radial_sphere(w, h, (cx - r * 0.42, cy - r * 0.5), r * 0.55, (255, 255, 255, 255), with_alpha(GOLD, 0))
    paste(img, hi)
    d.point([(cx - r * 0.45, cy - r * 0.55)], fill=(255, 255, 255, 255))

    img = upscale(img, 32, 32)
    return img


# ----------------------------------------------------------------------------
# 2. skeleton_sentry.png 48x48
# ----------------------------------------------------------------------------

def gen_skeleton_sentry():
    S = 2
    w, h = 48 // S, 48 // S  # 24x24
    img = canvas(w, h)
    d = ImageDraw.Draw(img)

    bone = IVORY
    bone_d = shade(IVORY, 0.75)

    # lance (drawn first, behind body) - diagonal from bottom-right to upper-left
    d.line([(20, 22), (4, 2)], fill=shade(BRONZE, 0.8), width=1)
    d.line([(19, 22), (5, 3)], fill=BRONZE_LIGHT, width=1)
    # lance blade tip
    outline_polygon(d, [(4, 2), (2, 4), (5, 6), (7, 3)], fill=IVORY, outline=OUTLINE)

    # legs
    outline_polygon(d, [(9, 16), (11, 16), (11, 23), (9, 23)], fill=bone, outline=OUTLINE)
    outline_polygon(d, [(13, 16), (15, 16), (15, 23), (13, 23)], fill=bone_d, outline=OUTLINE)
    d.line([(10, 18), (10, 21)], fill=bone_d)
    d.line([(14, 18), (14, 21)], fill=shade(IVORY, 0.6))

    # pelvis
    outline_polygon(d, [(8, 14), (16, 14), (17, 17), (7, 17)], fill=bone, outline=OUTLINE)

    # ribcage
    outline_polygon(d, [(7, 7), (17, 7), (17, 14), (7, 14)], fill=bone, outline=OUTLINE)
    for ry in (9, 11, 13):
        d.line([(8, ry), (16, ry)], fill=bone_d)
    d.line([(12, 7), (12, 14)], fill=bone_d)  # sternum

    # arms holding lance
    outline_polygon(d, [(6, 8), (8, 9), (7, 15), (5, 14)], fill=bone, outline=OUTLINE)  # left arm
    outline_polygon(d, [(16, 8), (18, 8), (17, 14), (15, 14)], fill=bone_d, outline=OUTLINE)  # right arm to lance

    # skull
    outline_polygon(d, [(9, 2), (15, 2), (16, 6), (14, 8), (10, 8), (8, 6)], fill=bone, outline=OUTLINE)
    d.rectangle([10, 8, 11, 9], fill=OUTLINE)  # jaw shadow
    d.rectangle([13, 8, 14, 9], fill=OUTLINE)

    # glowing violet eye sockets
    d.rectangle([10, 4, 11, 5], fill=VIOLET_LIGHT)
    d.rectangle([13, 4, 14, 5], fill=VIOLET_LIGHT)
    d.point([(10, 4), (13, 4)], fill=(255, 255, 255, 255))

    # bronze helmet
    outline_polygon(d, [(8, 0), (16, 0), (16, 3), (8, 3)], fill=BRONZE, outline=OUTLINE)
    outline_polygon(d, [(7, 2), (17, 2), (16, 4), (8, 4)], fill=BRONZE_LIGHT, outline=OUTLINE)
    d.line([(8, 1), (16, 1)], fill=BRONZE_LIGHT)
    # small helmet spike
    d.polygon([(11, -1), (13, -1), (12, 0)], fill=BRONZE_LIGHT)

    img = upscale(img, 48, 48)
    img = add_noise(img, amount=6, seed=SEED + 2)
    return img


# ----------------------------------------------------------------------------
# 3. ash_bat.png 48x32
# ----------------------------------------------------------------------------

def gen_ash_bat():
    S = 2
    w, h = 48 // S, 32 // S  # 24x16
    img = canvas(w, h)
    d = ImageDraw.Draw(img)

    cx, cy = w / 2, h / 2 + 1

    # wings (jagged bat-wing polygons), spread left/right
    left_wing = [
        (cx - 1, cy - 1), (cx - 5, cy - 5), (cx - 9, cy - 3), (cx - 8, cy - 1),
        (cx - 11, cy), (cx - 8, cy + 1), (cx - 10, cy + 3), (cx - 6, cy + 2),
        (cx - 4, cy + 4), (cx - 2, cy + 1),
    ]
    right_wing = [(w - x, y) for (x, y) in left_wing]
    outline_polygon(d, left_wing, fill=GREY_ASH, outline=OUTLINE)
    outline_polygon(d, right_wing, fill=GREY_ASH, outline=OUTLINE)
    # wing membrane fold lines
    for k in (1, 2, 3):
        d.line([(cx - 1, cy - 1), (cx - 2 - k * 2, cy - 1 + k)], fill=GREY_ASH_D)
        d.line([(w - (cx - 1), cy - 1), (w - (cx - 2 - k * 2), cy - 1 + k)], fill=GREY_ASH_D)

    # body
    outline_polygon(d, [(cx - 2, cy - 2), (cx + 2, cy - 2), (cx + 2, cy + 2), (cx - 2, cy + 2)],
                     fill=GREY_ASH_D, outline=OUTLINE)
    # ears
    d.polygon([(cx - 2, cy - 2), (cx - 3, cy - 5), (cx - 1, cy - 3)], fill=GREY_ASH_D, outline=OUTLINE)
    d.polygon([(cx + 2, cy - 2), (cx + 3, cy - 5), (cx + 1, cy - 3)], fill=GREY_ASH_D, outline=OUTLINE)

    # violet glowing eyes
    d.point([(cx - 1, cy - 1)], fill=VIOLET_LIGHT)
    d.point([(cx + 1, cy - 1)], fill=VIOLET_LIGHT)

    # ember specks
    embers = [(cx - 7, cy - 4), (cx + 6, cy + 2), (cx - 3, cy + 5), (cx + 8, cy - 2)]
    for ex, ey in embers:
        d.point([(ex, ey)], fill=with_alpha(RED_DANGER, 230))
        d.point([(ex + 1, ey)], fill=with_alpha(GOLD, 140))

    img = upscale(img, 48, 32)
    img = add_noise(img, amount=8, seed=SEED + 3)
    return img


# ----------------------------------------------------------------------------
# 4. glass_guardian.png 72x72
# ----------------------------------------------------------------------------

def gen_glass_guardian():
    S = 2
    w, h = 72 // S, 72 // S  # 36x36
    img = canvas(w, h)
    d = ImageDraw.Draw(img)

    lead = BLACK

    # overall silhouette (the "lead" body): helmet, shoulders, torso, legs
    silhouette = [
        (14, 3), (22, 3), (24, 7),            # helmet top
        (27, 10), (30, 15), (30, 24),          # right shoulder/arm
        (26, 24), (25, 34), (20, 34), (19, 25),
        (17, 25), (16, 34), (11, 34), (10, 24),
        (6, 24), (6, 15), (9, 10), (12, 7),
    ]
    outline_polygon(d, silhouette, fill=lead, outline=OUTLINE, width=1)

    def pane(pts, color):
        inset = []
        cx_ = sum(p[0] for p in pts) / len(pts)
        cy_ = sum(p[1] for p in pts) / len(pts)
        for (px, py) in pts:
            inset.append((px + (cx_ - px) * 0.12, py + (cy_ - py) * 0.12))
        d.polygon(inset, fill=color)

    # stained glass panes inset within the lead silhouette
    pane([(13, 5), (23, 5), (22, 10), (14, 10)], VIOLET)               # helmet visor band
    pane([(9, 11), (27, 11), (27, 16), (9, 16)], GOLD)                 # gorget
    pane([(9, 17), (17, 17), (17, 24), (9, 24)], VIOLET_LIGHT)         # chest left
    pane([(19, 17), (27, 17), (27, 24), (19, 24)], RED_DANGER)         # chest right
    pane([(10, 25), (26, 25), (24, 33), (12, 33)], BRONZE_LIGHT)       # tabard
    pane([(7, 16), (10, 16), (10, 23), (7, 23)], VIOLET)               # left pauldron
    pane([(26, 16), (29, 16), (29, 23), (26, 23)], VIOLET)             # right pauldron

    # glowing eye slits
    d.rectangle([15, 7, 16, 8], fill=GOLD)
    d.rectangle([20, 7, 21, 8], fill=GOLD)
    d.point([(15, 7), (20, 7)], fill=(255, 255, 255, 255))

    # extra lead lines cutting through panes for a "many small panes" look
    d.line([(18, 5), (18, 33)], fill=OUTLINE)
    d.line([(9, 16), (27, 16)], fill=OUTLINE)
    d.line([(9, 24), (27, 24)], fill=OUTLINE)

    img = upscale(img, 72, 72)
    return img


# ----------------------------------------------------------------------------
# 5. guardian_shield.png 96x48
# ----------------------------------------------------------------------------

def gen_guardian_shield():
    S = 2
    w, h = 96 // S, 48 // S  # 48x24
    img = canvas(w, h)

    cx, cy = w / 2, -h * 0.55
    outer_r = h * 1.95
    inner_r = h * 1.45

    yy, xx = np.mgrid[0:h, 0:w]
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    ang = np.degrees(np.arctan2(yy - cy, xx - cx))  # -180..180, 90=down

    ring_mask = (dist >= inner_r) & (dist <= outer_r) & (ang > 8) & (ang < 172)

    arr = np.zeros((h, w, 4), dtype=np.uint8)
    seg_colors = [VIOLET, GOLD, RED_DANGER, VIOLET, GOLD]
    n = len(seg_colors)
    ang_norm = np.clip((ang - 8) / (172 - 8), 0, 0.9999)
    seg_idx = (ang_norm * n).astype(np.int32)

    for i, col in enumerate(seg_colors):
        m = ring_mask & (seg_idx == i)
        arr[m] = col

    img = Image.fromarray(arr, "RGBA")
    d = ImageDraw.Draw(img)

    # lead / frame lines: outer edge, inner edge, and radial dividers
    for rad in (outer_r, outer_r - 1, inner_r, inner_r + 1):
        d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=OUTLINE)
    for i in range(n + 1):
        a = math.radians(8 + (172 - 8) * i / n)
        x1, y1 = cx + inner_r * math.cos(a), cy + inner_r * math.sin(a)
        x2, y2 = cx + outer_r * math.cos(a), cy + outer_r * math.sin(a)
        d.line([(x1, y1), (x2, y2)], fill=OUTLINE)

    # bright bevel highlight along outer rim
    d.arc([cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r], 10, 170, fill=with_alpha(BRONZE_LIGHT, 200))

    img = upscale(img, 96, 48)
    return img


# ----------------------------------------------------------------------------
# 6. bishop.png 140x140 - Faceless Bishop boss
# ----------------------------------------------------------------------------

def gen_bishop():
    S = 2
    w, h = 140 // S, 140 // S  # 70x70
    img = canvas(w, h)
    d = ImageDraw.Draw(img)

    robe_dark = mix(VIOLET, BLACK, 0.55)
    robe_mid = mix(VIOLET, BLACK, 0.35)
    robe_light = mix(VIOLET, BLACK, 0.15)

    cx = w / 2

    # flowing robe (bell shape flaring at the bottom, floating - no visible feet)
    robe = [
        (cx - 8, 26), (cx - 14, 34), (cx - 20, 46), (cx - 24, 58),
        (cx - 22, 64), (cx - 12, 66), (cx, 67), (cx + 12, 66),
        (cx + 22, 64), (cx + 24, 58), (cx + 20, 46), (cx + 14, 34),
        (cx + 8, 26),
    ]
    outline_polygon(d, robe, fill=robe_mid, outline=OUTLINE, width=1)

    # robe shading folds
    for k, x_off in enumerate((-14, -6, 6, 14)):
        col = robe_dark if k % 2 == 0 else robe_light
        d.polygon([(cx + x_off, 30), (cx + x_off - 3, 63), (cx + x_off + 3, 63), (cx + x_off + 3, 30)], fill=col)

    # bronze trim hem
    d.line([(cx - 22, 63), (cx - 12, 65), (cx, 66), (cx + 12, 65), (cx + 22, 63)], fill=BRONZE_LIGHT, width=1)

    # shoulders + bronze epaulettes
    outline_polygon(d, [(cx - 14, 22), (cx + 14, 22), (cx + 18, 28), (cx - 18, 28)], fill=robe_dark, outline=OUTLINE)
    d.rectangle([cx - 18, 24, cx - 13, 28], fill=BRONZE)
    d.rectangle([cx + 13, 24, cx + 18, 28], fill=BRONZE)
    d.point([(cx - 16, 25), (cx + 16, 25)], fill=BRONZE_LIGHT)

    # tall mitre / hood
    hood = [(cx - 10, 22), (cx - 6, 6), (cx - 2, -2), (cx, -6), (cx + 2, -2), (cx + 6, 6), (cx + 10, 22)]
    outline_polygon(d, hood, fill=robe_mid, outline=OUTLINE)
    d.line([(cx, -6), (cx, 20)], fill=robe_dark)
    d.line([(cx - 8, 20), (cx - 4, 4)], fill=robe_light)
    d.line([(cx + 8, 20), (cx + 4, 4)], fill=robe_dark)
    # bronze piping along hood edges
    d.line([(cx - 10, 22), (cx - 6, 6), (cx, -6)], fill=BRONZE_LIGHT)
    d.line([(cx + 10, 22), (cx + 6, 6), (cx, -6)], fill=BRONZE)

    # empty dark mask / void face
    mask_shape = [(cx - 6, 12), (cx + 6, 12), (cx + 5, 20), (cx, 23), (cx - 5, 20)]
    outline_polygon(d, mask_shape, fill=BLACK, outline=OUTLINE)
    d.ellipse([cx - 3, 14, cx + 3, 19], fill=with_alpha(VIOLET, 60))

    # three small luminous fictional runes on the chest
    rune_pts = [(cx, 34), (cx - 6, 42), (cx + 6, 42)]
    for (rx, ry) in rune_pts:
        d.line([(rx - 2, ry - 2), (rx + 2, ry + 2)], fill=GOLD)
        d.line([(rx - 2, ry + 2), (rx + 2, ry - 2)], fill=GOLD)
        d.point([(rx, ry)], fill=(255, 255, 255, 255))

    # bronze belt/sash
    d.line([(cx - 16, 32), (cx + 16, 32)], fill=BRONZE)
    d.line([(cx - 16, 33), (cx + 16, 33)], fill=shade(BRONZE, 0.7))

    # floating wisps under the robe (implies levitation, no feet)
    for fx, fy, fr in ((cx - 10, 68, 3), (cx, 69, 4), (cx + 10, 68, 3)):
        glow = radial_glow(w, h, (fx, fy), fr, VIOLET_LIGHT, max_alpha=120)
        paste(img, glow)

    img = upscale(img, 140, 140)
    img = add_noise(img, amount=5, seed=SEED + 6)
    return img


# ----------------------------------------------------------------------------
# 7. bishop_eye.png 56x56
# ----------------------------------------------------------------------------

def gen_bishop_eye():
    S = 2
    w, h = 56 // S, 56 // S  # 28x28
    img = canvas(w, h)
    cx, cy = w / 2, h / 2

    # outer glow
    glow = radial_glow(w, h, (cx, cy), w * 0.5, VIOLET, max_alpha=150)
    paste(img, glow)

    d = ImageDraw.Draw(img)
    # almond sclera shape
    eye = [
        (cx - 12, cy), (cx - 6, cy - 6), (cx, cy - 7), (cx + 6, cy - 6), (cx + 12, cy),
        (cx + 6, cy + 6), (cx, cy + 7), (cx - 6, cy + 6),
    ]
    sclera_c = mix(RED_DANGER, VIOLET, 0.6)
    outline_polygon(d, eye, fill=shade(sclera_c, 0.55), outline=OUTLINE)

    # radial darkening toward corners
    dark_corners = radial_glow(w, h, (cx, cy), w * 0.62, BLACK, max_alpha=120)
    paste(img, dark_corners)

    d = ImageDraw.Draw(img)
    # iris
    d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=mix(VIOLET, BLACK, 0.2), outline=OUTLINE)
    d.ellipse([cx - 3, cy - 5.5, cx + 3, cy + 5.5], fill=VIOLET)
    # slit pupil
    d.polygon([(cx - 1, cy - 5), (cx + 1, cy - 5), (cx + 0.6, cy + 5), (cx - 0.6, cy + 5)], fill=BLACK)
    d.line([(cx, cy - 5), (cx, cy + 5)], fill=with_alpha(VIOLET_LIGHT, 200))

    # bright glint
    d.point([(cx - 3, cy - 3)], fill=(255, 255, 255, 255))

    img = upscale(img, 56, 56)
    return img


# ----------------------------------------------------------------------------
# 8. weakpoint.png 36x36
# ----------------------------------------------------------------------------

def gen_weakpoint():
    S = 2
    w, h = 36 // S, 36 // S  # 18x18
    img = canvas(w, h)
    cx, cy = w / 2, h / 2

    glow = radial_glow(w, h, (cx, cy), w * 0.55, VIOLET_LIGHT, max_alpha=190)
    paste(img, glow)

    orb = radial_sphere(w, h, (cx, cy), w * 0.34, mix(VIOLET_LIGHT, (255, 255, 255, 255), 0.3), mix(VIOLET, BLACK, 0.3), bands=4)
    paste(img, orb)

    d = ImageDraw.Draw(img)
    d.ellipse([cx - w * 0.34, cy - w * 0.34, cx + w * 0.34, cy + w * 0.34], outline=with_alpha(VIOLET_LIGHT, 220))

    # fictional angular rune inside
    r = w * 0.2
    d.line([(cx, cy - r), (cx, cy + r)], fill=(255, 255, 255, 255))
    d.line([(cx - r * 0.8, cy - r * 0.3), (cx, cy)], fill=(255, 255, 255, 255))
    d.line([(cx + r * 0.8, cy - r * 0.3), (cx, cy)], fill=(255, 255, 255, 255))
    d.line([(cx - r * 0.5, cy + r * 0.7), (cx + r * 0.5, cy + r * 0.7)], fill=(255, 255, 255, 255))

    img = upscale(img, 36, 36)
    return img


# ----------------------------------------------------------------------------
# 9. bumper_bell.png 88x88 - seen from above
# ----------------------------------------------------------------------------

def gen_bumper_bell():
    S = 2
    w, h = 88 // S, 88 // S  # 44x44
    img = canvas(w, h)
    cx, cy = w / 2, h / 2
    R = w / 2 - 1

    rings = [
        (R, BRONZE_LIGHT),
        (R - 2, BRONZE),
        (R - 4, shade(BRONZE, 0.75)),
        (R - 7, STONE_DARK),
        (R - 9, shade(STONE_DARK, 0.7)),
        (R - 13, BLACK),
    ]
    for rad, col in rings:
        c = radial_sphere(w, h, (cx, cy), rad, col, shade(col, 0.85))
        paste(img, c)

    d = ImageDraw.Draw(img)
    for rad, _ in rings:
        d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=OUTLINE)

    # violet cracks radiating from the dark center
    rnd = random.Random(SEED + 9)
    for i in range(6):
        a0 = rnd.uniform(0, math.tau)
        x, y = cx, cy
        r0 = R - 13
        r1 = r0 + rnd.uniform(10, R - 3 - r0)
        pts = [(x, y)]
        steps = 5
        for s in range(1, steps + 1):
            rr = r0 + (r1 - r0) * s / steps
            aa = a0 + rnd.uniform(-0.25, 0.25)
            pts.append((cx + rr * math.cos(aa), cy + rr * math.sin(aa)))
        d.line(pts, fill=VIOLET_LIGHT, width=1, joint="curve")

    # bright rim highlight (top-left, seen from above under a light)
    d.arc([cx - R, cy - R, cx + R, cy + R], 200, 300, fill=with_alpha((255, 255, 255, 255), 180))

    img = upscale(img, 88, 88)
    img = add_noise(img, amount=6, seed=SEED + 90)
    return img


# ----------------------------------------------------------------------------
# 10-12. rune_a/b/c.png 40x40 - fictional angular runes on stone plate
# ----------------------------------------------------------------------------

def _rune_plate(w, h):
    img = canvas(w, h)
    cx, cy = w / 2, h / 2
    r = w / 2 - 1
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=STONE_DARK, outline=OUTLINE)
    d.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], outline=STONE_LIGHT)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=BRONZE)
    d.point([(cx - r * 0.6, cy - r * 0.75)], fill=BRONZE_LIGHT)
    return img, d, cx, cy, r


def gen_rune_a():
    w, h = 20, 20
    img, d, cx, cy, r = _rune_plate(w, h)
    g = r * 0.55
    # angular glyph: vertical spine + two outward diagonal ticks + base bar
    d.line([(cx, cy - g), (cx, cy + g)], fill=GOLD, width=2)
    d.line([(cx, cy - g * 0.3), (cx + g * 0.8, cy - g * 0.9)], fill=GOLD, width=2)
    d.line([(cx, cy + g * 0.1), (cx - g * 0.8, cy - g * 0.5)], fill=GOLD, width=2)
    d.line([(cx - g * 0.5, cy + g), (cx + g * 0.5, cy + g)], fill=GOLD, width=2)
    img = upscale(img, 40, 40)
    return img


def gen_rune_b():
    w, h = 20, 20
    img, d, cx, cy, r = _rune_plate(w, h)
    g = r * 0.55
    # angular glyph: triangle with a crossing bar and a dot
    d.polygon([(cx, cy - g), (cx + g, cy + g * 0.7), (cx - g, cy + g * 0.7)], outline=GOLD, width=2)
    d.line([(cx - g * 0.5, cy + g * 0.15), (cx + g * 0.5, cy + g * 0.15)], fill=GOLD, width=2)
    d.point([(cx, cy - g * 0.15)], fill=GOLD)
    img = upscale(img, 40, 40)
    return img


def gen_rune_c():
    w, h = 20, 20
    img, d, cx, cy, r = _rune_plate(w, h)
    g = r * 0.55
    # angular glyph: zigzag with a small ring at the top
    d.ellipse([cx - g * 0.28, cy - g - g * 0.28, cx + g * 0.28, cy - g + g * 0.28], outline=GOLD, width=2)
    d.line([
        (cx, cy - g * 0.5), (cx - g * 0.6, cy - g * 0.1), (cx + g * 0.6, cy + g * 0.35), (cx - g * 0.2, cy + g),
    ], fill=GOLD, width=2, joint="curve")
    img = upscale(img, 40, 40)
    return img


# ----------------------------------------------------------------------------
# 13. mana_fragment.png 20x20
# ----------------------------------------------------------------------------

def gen_mana_fragment():
    S = 2
    w, h = 20 // S, 20 // S  # 10x10
    img = canvas(w, h)
    cx, cy = w / 2, h / 2
    d = ImageDraw.Draw(img)

    top = (cx, cy - 4.2)
    bottom = (cx, cy + 4.2)
    left = (cx - 2.4, cy - 0.5)
    right = (cx + 2.4, cy - 0.5)

    outline_polygon(d, [top, right, bottom, left], fill=mix(VIOLET, BLACK, 0.25), outline=OUTLINE)
    d.polygon([top, right, cy_mid := (cx, cy - 0.5)], fill=mix(VIOLET_LIGHT, (255, 255, 255, 255), 0.15))
    d.polygon([top, left, (cx, cy - 0.5)], fill=VIOLET)
    d.polygon([left, bottom, (cx, cy - 0.5)], fill=mix(VIOLET, BLACK, 0.45))
    d.polygon([right, bottom, (cx, cy - 0.5)], fill=mix(VIOLET, BLACK, 0.3))
    d.line([top, (cx, cy - 0.5), bottom], fill=OUTLINE)

    d.point([(cx, cy - 1)], fill=(255, 255, 255, 255))

    img = upscale(img, 20, 20)
    return img


# ----------------------------------------------------------------------------
# 14. projectile.png 24x24
# ----------------------------------------------------------------------------

def gen_projectile():
    S = 2
    w, h = 24 // S, 24 // S  # 12x12
    img = canvas(w, h)
    cx, cy = w / 2, h / 2
    r = w / 2 - 1

    glow = radial_glow(w, h, (cx, cy), r + 1.5, VIOLET, max_alpha=140)
    paste(img, glow)

    body = radial_sphere(w, h, (cx, cy), r, RED_DANGER, mix(VIOLET, BLACK, 0.6), bands=4)
    paste(img, body)

    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=OUTLINE)
    d.point([(cx - r * 0.3, cy - r * 0.3)], fill=with_alpha((255, 220, 220, 255), 230))

    img = upscale(img, 24, 24)
    return img


# ----------------------------------------------------------------------------
# 15. drop_target.png 28x56
# ----------------------------------------------------------------------------

def gen_drop_target():
    S = 2
    w, h = 28 // S, 56 // S  # 14x28
    img = canvas(w, h)
    d = ImageDraw.Draw(img)

    rect = [1, 1, w - 2, h - 2]
    # vertical bronze gradient
    grad = canvas(w, h)
    garr = np.zeros((h, w, 4), dtype=np.uint8)
    for y in range(h):
        t = y / (h - 1)
        col = mix(BRONZE_LIGHT, shade(BRONZE, 0.6), t)
        garr[y, :, :] = col
    grad = Image.fromarray(garr, "RGBA")
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    md.rectangle(rect, fill=255)
    img.paste(grad, (0, 0), mask)

    d.rectangle(rect, outline=OUTLINE, width=1)
    # rivets
    for (rx, ry) in [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]:
        d.point([(rx, ry)], fill=shade(BRONZE, 0.6))

    # small fictional violet rune, centered
    cx, cy = w / 2, h / 2
    g = 3.2
    d.line([(cx, cy - g), (cx, cy + g)], fill=VIOLET_LIGHT)
    d.line([(cx - g * 0.7, cy - g * 0.3), (cx + g * 0.7, cy - g * 0.3)], fill=VIOLET_LIGHT)
    d.line([(cx - g * 0.5, cy + g * 0.6), (cx, cy + g * 0.1), (cx + g * 0.5, cy + g * 0.6)], fill=VIOLET_LIGHT)

    img = upscale(img, 28, 56)
    return img


# ----------------------------------------------------------------------------
# 16. lock_saucer.png 64x64
# ----------------------------------------------------------------------------

def gen_lock_saucer():
    S = 2
    w, h = 64 // S, 64 // S  # 32x32
    img = canvas(w, h)
    cx, cy = w / 2, h / 2
    r = w / 2 - 1

    pit = radial_sphere(w, h, (cx, cy), r, shade(STONE_DARK, 0.9), BLACK, bands=5)
    paste(img, pit)

    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=BRONZE)
    d.ellipse([cx - r + 0.8, cy - r + 0.8, cx + r - 0.8, cy + r - 0.8], outline=with_alpha(BRONZE_LIGHT, 160))

    # subtle violet swirl
    turns = 1.6
    pts = []
    for i in range(60):
        t = i / 59
        aa = t * turns * math.tau
        rr = r * 0.85 * t
        pts.append((cx + rr * math.cos(aa), cy + rr * math.sin(aa)))
    d.line(pts, fill=with_alpha(VIOLET, 150), width=1, joint="curve")

    d.arc([cx - r, cy - r, cx + r, cy + r], 200, 300, fill=with_alpha((255, 255, 255, 255), 90))

    img = upscale(img, 64, 64)
    return img


# ----------------------------------------------------------------------------
# 17. portal_boss.png 96x96 - violet vortex ring
# ----------------------------------------------------------------------------

def gen_portal_boss():
    S = 2
    w, h = 96 // S, 96 // S  # 48x48
    img = canvas(w, h)
    cx, cy = w / 2, h / 2
    outer = w / 2 - 1
    inner = outer * 0.55

    glow = radial_glow(w, h, (cx, cy), outer + 4, VIOLET, max_alpha=140)
    paste(img, glow)

    d = ImageDraw.Draw(img)
    rnd = random.Random(SEED + 17)
    n_arcs = 10
    for i in range(n_arcs):
        rad = inner + (outer - inner) * (i / (n_arcs - 1))
        a0 = rnd.uniform(0, 360)
        span = rnd.uniform(70, 160)
        col = VIOLET_LIGHT if i % 2 == 0 else VIOLET
        width = 2 if i % 3 == 0 else 1
        d.arc([cx - rad, cy - rad, cx + rad, cy + rad], a0, a0 + span, fill=col, width=width)

    d.ellipse([cx - outer, cy - outer, cx + outer, cy + outer], outline=with_alpha(VIOLET_LIGHT, 220), width=1)
    d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], outline=with_alpha(VIOLET_LIGHT, 200), width=1)

    # punch out transparent center hole to background/black-blue
    hole = Image.new("L", (w, h), 0)
    hd = ImageDraw.Draw(hole)
    hd.ellipse([cx - inner + 1, cy - inner + 1, cx + inner - 1, cy + inner - 1], fill=255)
    arr = np.array(img)
    hole_arr = np.array(hole)
    arr[:, :, 3] = np.where(hole_arr > 0, 0, arr[:, :, 3])
    img = Image.fromarray(arr, "RGBA")

    img = upscale(img, 96, 96)
    return img


# ----------------------------------------------------------------------------
# 18. background_table.png 820x1080 (OPAQUE)
# ----------------------------------------------------------------------------

def gen_background_table():
    W, H = 820, 1080
    arr = np.zeros((H, W, 4), dtype=np.float32)

    yy, xx = np.mgrid[0:H, 0:W]

    top_c = np.array(shade(BG_BLUE, 0.85)[:3])
    mid_c = np.array(mix(BG_BLUE, STONE_DARK, 0.45)[:3])
    bot_c = np.array(mix(STONE_DARK, (60, 62, 84, 255), 0.35)[:3])

    t_mid = np.clip((yy - 200) / 300, 0, 1)[:, :, None]
    t_bot = np.clip((yy - 620) / 260, 0, 1)[:, :, None]

    col = top_c[None, None, :] * (1 - t_mid) + mid_c[None, None, :] * t_mid
    col = col * (1 - t_bot) + bot_c[None, None, :] * t_bot

    arr[:, :, 0:3] = col
    arr[:, :, 3] = 255

    # dithered fine noise to break banding
    dith = bayer_dither(W, H, amount=5)
    fine = np.random.RandomState(SEED + 18).randint(-4, 5, size=(H, W)).astype(np.int16)
    grain = (dith + fine)[:, :, None]
    arr[:, :, 0:3] = np.clip(arr[:, :, 0:3] + grain, 0, 255)

    img = from_np(arr)
    d = ImageDraw.Draw(img)

    # soft violet radial glow, top zone, centered (410,180)
    glow = radial_glow(W, H, (410, 180), 320, VIOLET, max_alpha=46)
    paste(img, glow)

    # faint stained-glass window rectangles near left/right edges, middle zone
    for x0 in (36, W - 36 - 70):
        for yc in (420, 560):
            rect = [x0, yc, x0 + 70, yc + 140]
            d.rectangle(rect, outline=with_alpha(shade(STONE_LIGHT, 1.1), 60))
            d.rectangle([rect[0] + 6, rect[1] + 6, rect[2] - 6, rect[3] - 6], outline=with_alpha(VIOLET, 40))
            d.line([rect[0] + 6, (rect[1] + rect[3]) // 2, rect[2] - 6, (rect[1] + rect[3]) // 2],
                   fill=with_alpha(VIOLET, 30))
            d.line([(rect[0] + rect[2]) // 2, rect[1] + 6, (rect[0] + rect[2]) // 2, rect[3] - 6],
                   fill=with_alpha(GOLD, 22))

    # faint chain-link pattern along sides of the bottom zone
    rnd = random.Random(SEED + 181)
    for x0 in (26, W - 46):
        y = 720
        while y < 1060:
            d.ellipse([x0, y, x0 + 20, y + 30], outline=with_alpha(BRONZE, 40))
            y += 24

    # subtle vertical divider line (plunger lane) x=760, y 380..1080
    d.line([(760, 380), (760, 1080)], fill=with_alpha(shade(STONE_LIGHT, 1.2), 70), width=2)
    d.line([(761, 380), (761, 1080)], fill=with_alpha(BLACK, 60), width=1)

    img = img.convert("RGBA")
    # force fully opaque
    a = np.array(img)
    a[:, :, 3] = 255
    img = Image.fromarray(a, "RGBA")
    return img


# ----------------------------------------------------------------------------
# 19. side_panel.png 550x1080 (OPAQUE)
# ----------------------------------------------------------------------------

def gen_side_panel():
    W, H = 550, 1080
    arr = np.zeros((H, W, 4), dtype=np.float32)
    base = np.array(mix(BG_BLUE, STONE_DARK, 0.5)[:3])
    arr[:, :, 0:3] = base
    arr[:, :, 3] = 255
    dith = bayer_dither(W, H, amount=5)
    fine = np.random.RandomState(SEED + 19).randint(-5, 6, size=(H, W)).astype(np.int16)
    arr[:, :, 0:3] = np.clip(arr[:, :, 0:3] + (dith + fine)[:, :, None], 0, 255)
    img = from_np(arr)
    d = ImageDraw.Draw(img)

    BORDER = 12
    d.rectangle([0, 0, W - 1, H - 1], outline=BRONZE, width=BORDER)
    d.rectangle([2, 2, W - 3, H - 3], outline=BRONZE_LIGHT, width=2)
    d.rectangle([BORDER - 1, BORDER - 1, W - BORDER, H - BORDER], outline=shade(BRONZE, 0.7), width=1)

    # decorative bronze inner frame
    d.rectangle([40, 60, 510, 1020], outline=BRONZE, width=3)
    d.rectangle([44, 64, 506, 1016], outline=BRONZE_LIGHT, width=1)
    d.rectangle([36, 56, 514, 1024], outline=shade(BRONZE, 0.7), width=1)
    # corner ornaments
    for (cx0, cy0) in [(40, 60), (510, 60), (40, 1020), (510, 1020)]:
        d.ellipse([cx0 - 6, cy0 - 6, cx0 + 6, cy0 + 6], outline=BRONZE_LIGHT, width=2)
        d.ellipse([cx0 - 2, cy0 - 2, cx0 + 2, cy0 + 2], fill=BRONZE)

    a = np.array(img)
    a[:, :, 3] = 255
    img = Image.fromarray(a, "RGBA")
    return img


# ----------------------------------------------------------------------------
# 20. menu_bg.png 1920x1080 (OPAQUE)
# ----------------------------------------------------------------------------

def gen_menu_bg():
    W, H = 1920, 1080
    cx, cy = 960, 540
    yy, xx = np.mgrid[0:H, 0:W]
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    maxd = math.hypot(max(cx, W - cx), max(cy, H - cy))
    t = np.clip(dist / maxd, 0, 1)

    center_c = np.array(shade(BG_BLUE, 1.35)[:3], dtype=np.float32)
    edge_c = np.array((2, 2, 4), dtype=np.float32)
    col = center_c[None, None, :] * (1 - t[:, :, None]) ** 1.1 + edge_c[None, None, :] * (1 - (1 - t[:, :, None]) ** 1.1)

    # vignette darkening
    vig = 1.0 - 0.55 * (t ** 2.2)
    col = col * vig[:, :, None]

    arr = np.zeros((H, W, 4), dtype=np.float32)
    arr[:, :, 0:3] = col
    arr[:, :, 3] = 255

    dith = bayer_dither(W, H, amount=4)
    arr[:, :, 0:3] = np.clip(arr[:, :, 0:3] + dith[:, :, None], 0, 255)

    img = from_np(arr)

    # subtle violet glow at center
    glow = radial_glow(W, H, (cx, cy), 300, VIOLET, max_alpha=55)
    paste(img, glow)

    d = ImageDraw.Draw(img)
    # large faint violet ring of fictional runes, radius ~380
    R = 380
    n = 20
    rnd = random.Random(SEED + 20)
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=with_alpha(VIOLET, 55), width=2)
    for i in range(n):
        a = math.tau * i / n
        rx, ry = cx + R * math.cos(a), cy + R * math.sin(a)
        g = 16
        style = i % 3
        col_r = with_alpha(VIOLET_LIGHT, 70)
        if style == 0:
            d.line([(rx, ry - g), (rx, ry + g)], fill=col_r, width=2)
            d.line([(rx - g * 0.6, ry), (rx + g * 0.6, ry)], fill=col_r, width=2)
        elif style == 1:
            d.polygon([(rx, ry - g), (rx + g * 0.7, ry + g * 0.5), (rx - g * 0.7, ry + g * 0.5)],
                      outline=col_r, width=2)
        else:
            d.line([(rx - g * 0.6, ry - g * 0.6), (rx + g * 0.6, ry + g * 0.6)], fill=col_r, width=2)
            d.line([(rx - g * 0.6, ry + g * 0.6), (rx + g * 0.6, ry - g * 0.6)], fill=col_r, width=2)

    a = np.array(img)
    a[:, :, 3] = 255
    img = Image.fromarray(a, "RGBA")
    return img


# ----------------------------------------------------------------------------
# 21. icon.png 128x128 - abyssal eye with violet flames
# ----------------------------------------------------------------------------

def gen_icon():
    S = 2
    w, h = 128 // S, 128 // S  # 64x64
    img = canvas(w, h)
    d = ImageDraw.Draw(img)

    # opaque dark rounded-square background
    rad = 10
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=rad, fill=mix(BG_BLUE, STONE_DARK, 0.4))
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=rad - 1, outline=shade(BRONZE, 0.8))

    cx, cy = w / 2, h / 2 + 2

    # violet flames behind the eye
    rnd = random.Random(SEED + 21)
    flame_pts = []
    n = 10
    for i in range(n):
        a = math.tau * i / n
        base_r = 20
        jag = base_r + rnd.uniform(4, 12)
        flame_pts.append((cx + jag * math.cos(a), cy + jag * math.sin(a) * 0.95))
    d.polygon(flame_pts, fill=with_alpha(VIOLET, 130))
    flame_pts2 = []
    for i in range(n):
        a = math.tau * (i + 0.5) / n
        base_r = 15
        jag = base_r + rnd.uniform(2, 8)
        flame_pts2.append((cx + jag * math.cos(a), cy + jag * math.sin(a) * 0.95))
    d.polygon(flame_pts2, fill=with_alpha(VIOLET_LIGHT, 150))

    # eye (reuse bishop_eye style at bigger scale)
    eye_w, eye_h = 26, 15
    eye = [
        (cx - eye_w / 2, cy), (cx - eye_w * 0.25, cy - eye_h / 2), (cx, cy - eye_h * 0.58),
        (cx + eye_w * 0.25, cy - eye_h / 2), (cx + eye_w / 2, cy),
        (cx + eye_w * 0.25, cy + eye_h / 2), (cx, cy + eye_h * 0.58), (cx - eye_w * 0.25, cy + eye_h / 2),
    ]
    outline_polygon(d, eye, fill=shade(mix(RED_DANGER, VIOLET, 0.6), 0.5), outline=OUTLINE)
    d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=mix(VIOLET, BLACK, 0.15), outline=OUTLINE)
    d.polygon([(cx - 1.3, cy - 6.5), (cx + 1.3, cy - 6.5), (cx + 0.8, cy + 6.5), (cx - 0.8, cy + 6.5)], fill=BLACK)
    d.point([(cx - 3, cy - 3)], fill=(255, 255, 255, 255))

    glow = radial_glow(w, h, (cx, cy), 22, VIOLET_LIGHT, max_alpha=110)
    img.alpha_composite(glow)

    img = upscale(img, 128, 128)

    a = np.array(img)
    a[:, :, 3] = 255  # icon background is opaque; rounded corners are still dark bg color (fine for a square icon)
    img = Image.fromarray(a, "RGBA")
    return img


# ----------------------------------------------------------------------------
# 22. flipper.png 128x32 - bronze flipper bat, pivot at (16,16)
# ----------------------------------------------------------------------------

def gen_flipper():
    W, H = 128, 32
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    pivot_x, pivot_y, R0 = 16, 16, 14
    tip_x, tip_y, R1 = 118, 16, 8

    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

    def local_radius(x):
        if x < pivot_x:
            return None
        if x > tip_x:
            return None
        t = (x - pivot_x) / (tip_x - pivot_x)
        return R0 + (R1 - R0) * t

    mask = np.zeros((H, W), dtype=bool)
    # tapered middle section
    xs = np.arange(W)
    for x in xs:
        if pivot_x <= x <= tip_x:
            r = local_radius(x)
            ylo, yhi = pivot_y - r, pivot_y + r
            mask[:, x] |= (yy[:, x] >= ylo) & (yy[:, x] <= yhi)
        elif x < pivot_x:
            dxp = x - pivot_x
            if abs(dxp) <= R0:
                half = math.sqrt(max(R0 ** 2 - dxp ** 2, 0))
                mask[:, x] |= (yy[:, x] >= pivot_y - half) & (yy[:, x] <= pivot_y + half)
        else:
            dxt = x - tip_x
            if abs(dxt) <= R1:
                half = math.sqrt(max(R1 ** 2 - dxt ** 2, 0))
                mask[:, x] |= (yy[:, x] >= tip_y - half) & (yy[:, x] <= tip_y + half)

    # outline mask = dilated version of mask minus mask
    dil = mask.copy()
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        dil |= np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
    outline_only = dil & ~mask

    arr = np.zeros((H, W, 4), dtype=np.uint8)
    # gradient fill: lighter near top of the paddle, darker toward bottom
    t = np.clip((yy - (pivot_y - R0)) / (2 * R0), 0, 1)
    for c in range(3):
        top_v = BRONZE_LIGHT[c]
        bot_v = shade(BRONZE, 0.65)[c]
        arr[:, :, c] = (top_v + (bot_v - top_v) * t).astype(np.uint8)
    arr[:, :, 3] = np.where(mask, 255, 0)
    arr[outline_only] = list(OUTLINE)

    img = Image.fromarray(arr, "RGBA")
    d = ImageDraw.Draw(img)

    # top highlight stripe
    for x in range(pivot_x, tip_x):
        r = local_radius(x)
        hy = pivot_y - r * 0.55
        d.point([(x, hy)], fill=with_alpha((255, 255, 255, 255), 130))

    # violet gem at the pivot
    d.ellipse([pivot_x - 4, pivot_y - 4, pivot_x + 4, pivot_y + 4], fill=mix(VIOLET, BLACK, 0.1), outline=OUTLINE)
    d.ellipse([pivot_x - 2, pivot_y - 2, pivot_x + 1, pivot_y + 1], fill=VIOLET_LIGHT)
    d.point([(pivot_x - 1, pivot_y - 1)], fill=(255, 255, 255, 255))

    img = add_noise(img, amount=6, seed=SEED + 22)
    return img


# ----------------------------------------------------------------------------
# 23. chain_link.png 32x32
# ----------------------------------------------------------------------------

def gen_chain_link():
    S = 2
    w, h = 32 // S, 32 // S  # 16x16
    img = canvas(w, h)
    cx, cy = w / 2, h / 2

    outer_w, outer_h = w * 0.42, h * 0.30
    thickness = 2.6

    mask_outer = Image.new("L", (w, h), 0)
    mo = ImageDraw.Draw(mask_outer)
    mo.ellipse([cx - outer_w, cy - outer_h, cx + outer_w, cy + outer_h], fill=255)
    mask_inner = Image.new("L", (w, h), 0)
    mi = ImageDraw.Draw(mask_inner)
    inw, inh = outer_w - thickness, outer_h - thickness
    mi.ellipse([cx - inw, cy - inh, cx + inw, cy + inh], fill=255)

    ring_mask = np.array(mask_outer).astype(bool) & ~np.array(mask_inner).astype(bool)

    arr = np.zeros((h, w, 4), dtype=np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]
    t = np.clip((yy - (cy - outer_h)) / (2 * outer_h), 0, 1)
    for c in range(3):
        top_v = BRONZE_LIGHT[c]
        bot_v = shade(BRONZE, 0.6)[c]
        arr[:, :, c] = (top_v + (bot_v - top_v) * t).astype(np.uint8)
    arr[:, :, 3] = np.where(ring_mask, 255, 0)

    dil = ring_mask.copy()
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        dil |= np.roll(np.roll(ring_mask, dy, axis=0), dx, axis=1)
    outline_only = dil & ~ring_mask
    arr[outline_only] = list(OUTLINE)

    img = Image.fromarray(arr, "RGBA")
    img = upscale(img, 32, 32)
    return img


# ----------------------------------------------------------------------------
# 24-25. slingshot_left / slingshot_right 96x224
# ----------------------------------------------------------------------------

def _slingshot(mirror=False):
    W, H = 96, 224
    S = 2
    w, h = W // S, H // S  # 48x112
    img = canvas(w, h)
    d = ImageDraw.Draw(img)

    # LEFT default: right-angle at bottom-left, vertical edge on the left,
    # hypotenuse from top-left(0,0) to bottom-right(w-1,h-1)
    tri = [(0, 0), (0, h - 1), (w - 1, h - 1)]
    if mirror:
        tri = [(w - 1 - x, y) for (x, y) in tri]

    outline_polygon(d, tri, fill=mix(STONE_DARK, BLACK, 0.3), outline=OUTLINE, width=1)

    # subtle stone shading facets
    if not mirror:
        d.polygon([(0, 0), (0, h - 1), (w * 0.4, h - 1)], fill=shade(STONE_DARK, 0.85))
    else:
        d.polygon([(w - 1, 0), (w - 1, h - 1), (w * 0.6, h - 1)], fill=shade(STONE_DARK, 0.85))

    # bronze rubber band along the hypotenuse
    if not mirror:
        p0, p1 = (0, 0), (w - 1, h - 1)
    else:
        p0, p1 = (w - 1, 0), (0, h - 1)

    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length  # normal pointing into the triangle
    if not mirror:
        if nx < 0:
            nx, ny = -nx, -ny
    else:
        if nx > 0:
            nx, ny = -nx, -ny

    band_w = 3.2
    inset = 4.5
    q0 = (p0[0] + nx * inset, p0[1] + ny * inset)
    q1 = (p1[0] + nx * inset, p1[1] + ny * inset)
    b0 = (q0[0] - nx * band_w, q0[1] - ny * band_w)
    b1 = (q1[0] - nx * band_w, q1[1] - ny * band_w)
    b2 = (q1[0] + nx * band_w, q1[1] + ny * band_w)
    b3 = (q0[0] + nx * band_w, q0[1] + ny * band_w)

    d.polygon([b0, b1, b2, b3], fill=BRONZE, outline=OUTLINE)
    hi0 = (q0[0] - nx * band_w * 0.4, q0[1] - ny * band_w * 0.4)
    hi1 = (q1[0] - nx * band_w * 0.4, q1[1] - ny * band_w * 0.4)
    d.line([hi0, hi1], fill=BRONZE_LIGHT, width=1)

    # small bronze anchor posts at both ends of the band
    for pt in (q0, q1):
        d.ellipse([pt[0] - 2, pt[1] - 2, pt[0] + 2, pt[1] + 2], fill=shade(BRONZE, 0.8), outline=OUTLINE)

    img = upscale(img, W, H)
    img = add_noise(img, amount=6, seed=SEED + (24 if not mirror else 25))
    return img


def gen_slingshot_left():
    return _slingshot(mirror=False)


def gen_slingshot_right():
    return _slingshot(mirror=True)


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

SPRITES = [
    ("ball.png", (32, 32), gen_ball),
    ("skeleton_sentry.png", (48, 48), gen_skeleton_sentry),
    ("ash_bat.png", (48, 32), gen_ash_bat),
    ("glass_guardian.png", (72, 72), gen_glass_guardian),
    ("guardian_shield.png", (96, 48), gen_guardian_shield),
    ("bishop.png", (140, 140), gen_bishop),
    ("bishop_eye.png", (56, 56), gen_bishop_eye),
    ("weakpoint.png", (36, 36), gen_weakpoint),
    ("bumper_bell.png", (88, 88), gen_bumper_bell),
    ("rune_a.png", (40, 40), gen_rune_a),
    ("rune_b.png", (40, 40), gen_rune_b),
    ("rune_c.png", (40, 40), gen_rune_c),
    ("mana_fragment.png", (20, 20), gen_mana_fragment),
    ("projectile.png", (24, 24), gen_projectile),
    ("drop_target.png", (28, 56), gen_drop_target),
    ("lock_saucer.png", (64, 64), gen_lock_saucer),
    ("portal_boss.png", (96, 96), gen_portal_boss),
    ("background_table.png", (820, 1080), gen_background_table),
    ("side_panel.png", (550, 1080), gen_side_panel),
    ("menu_bg.png", (1920, 1080), gen_menu_bg),
    ("icon.png", (128, 128), gen_icon),
    ("flipper.png", (128, 32), gen_flipper),
    ("chain_link.png", (32, 32), gen_chain_link),
    ("slingshot_left.png", (96, 224), gen_slingshot_left),
    ("slingshot_right.png", (96, 224), gen_slingshot_right),
]


def main():
    results = []
    for name, size, fn in SPRITES:
        img = fn()
        path = save_png(img, name, size)
        results.append((name, path))

    print(f"{'file':<24}{'expected':<12}{'actual':<12}{'mode':<8}{'ok':<4}")
    print("-" * 60)
    all_ok = True
    for name, size, _ in SPRITES:
        path = os.path.join(OUT_DIR, name)
        with Image.open(path) as im:
            im.load()
            actual = im.size
            mode = im.mode
            ok = (actual == size) and (mode == "RGBA")
            all_ok = all_ok and ok
            print(f"{name:<24}{str(size):<12}{str(actual):<12}{mode:<8}{'OK' if ok else 'FAIL'}")
    print("-" * 60)
    print("ALL OK" if all_ok else "SOME FILES FAILED VERIFICATION")


if __name__ == "__main__":
    main()
