#!/usr/bin/env python3
"""
gen_audio.py -- Procedural audio generator for "Monster Pinball" (gothic-fantasy
action pinball). Synthesizes ALL sound effects and two seamless music loops
from scratch using numpy oscillators / noise / simple FM and filters, and
writes plain 44100 Hz, 16-bit PCM, mono WAV files with the stdlib `wave`
module.

Only numpy + Python standard library are used (no scipy, no external assets,
no network access). Everything is deterministic (seeded RNG) and safe to
re-run -- it always overwrites the same output files.

Run:
    python3 tools/gen_audio.py
"""

import os
import wave
import numpy as np

# ---------------------------------------------------------------------------
# Globals / configuration
# ---------------------------------------------------------------------------

SR = 44100
RNG_SEED = 1337
rng = np.random.default_rng(RNG_SEED)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(SCRIPT_DIR)
SFX_DIR = os.path.join(PROJECT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(PROJECT, "assets", "audio", "music")

SFX_PEAK_TARGET = 0.85
MUSIC_PEAK_TARGET = 0.60


# ---------------------------------------------------------------------------
# Low-level DSP helpers
# ---------------------------------------------------------------------------

def n_samples(dur):
    return int(round(dur * SR))


def t_arr(dur):
    n = n_samples(dur)
    return np.arange(n) / SR


def sine(freq, t, phase=0.0):
    return np.sin(2.0 * np.pi * freq * t + phase)


def saw(freq, t, phase=0.0):
    """Band-unlimited sawtooth in range [-1, 1]."""
    ph = freq * t + phase / (2.0 * np.pi)
    return 2.0 * (ph - np.floor(0.5 + ph))


def square(freq, t, duty=0.5, phase=0.0):
    ph = np.mod(freq * t + phase / (2.0 * np.pi), 1.0)
    return np.where(ph < duty, 1.0, -1.0)


def chirp_sine(f_start, f_end, n, shape="lin"):
    """Sine sweep from f_start to f_end over n samples using phase
    accumulation (so instantaneous frequency is continuous)."""
    if shape == "lin":
        freq_t = np.linspace(f_start, f_end, n)
    else:
        freq_t = np.geomspace(max(f_start, 1e-3), max(f_end, 1e-3), n)
    phase = 2.0 * np.pi * np.cumsum(freq_t) / SR
    return np.sin(phase), freq_t


def white_noise(n):
    if n <= 0:
        return np.zeros(0)
    return rng.uniform(-1.0, 1.0, n)


def exp_env(n, tau, sr=SR):
    tau = max(tau, 1e-6)
    tt = np.arange(n) / sr
    return np.exp(-tt / tau)


def adsr(n, a=0.01, d=0.05, s=0.6, r=0.1, sr=SR):
    a_n = max(int(a * sr), 1)
    d_n = max(int(d * sr), 1)
    r_n = max(int(r * sr), 1)
    s_n = max(n - a_n - d_n - r_n, 0)
    env = np.concatenate([
        np.linspace(0.0, 1.0, a_n, endpoint=False),
        np.linspace(1.0, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0.0, r_n),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    else:
        env = env[:n]
    return env


def fade_io(x, fade_in_ms=1.5, fade_out_ms=12.0, sr=SR):
    x = x.copy()
    n = len(x)
    fi = min(int(sr * fade_in_ms / 1000.0), n // 2)
    fo = min(int(sr * fade_out_ms / 1000.0), n // 2)
    if fi > 1:
        x[:fi] *= np.linspace(0.0, 1.0, fi)
    if fo > 1:
        x[-fo:] *= np.linspace(1.0, 0.0, fo)
    return x


def pad_to(x, n):
    if len(x) >= n:
        return x[:n].copy()
    return np.concatenate([x, np.zeros(n - len(x))])


def sum_events(events, total_len=None):
    """events: list of (delay_samples, array). Sums them into one buffer."""
    if total_len is None:
        total_len = max(d + len(y) for d, y in events)
    out = np.zeros(total_len)
    for d, y in events:
        end = min(total_len, d + len(y))
        if end > d:
            out[d:end] += y[: end - d]
    return out


def ma_lowpass(x, cutoff, sr=SR, passes=3):
    """Vectorized approximate low-pass via repeated moving-average
    (box) convolution -- fully numpy, no python-level sample loop."""
    n = len(x)
    if n == 0:
        return x.copy()
    if cutoff <= 0:
        return np.zeros_like(x)
    window = max(int(round(sr / (cutoff * 2.0))), 1)
    # Cap the kernel to the buffer length so `mode="same"` always returns
    # an array of the same length as the input (np.convolve otherwise
    # returns len(kernel) when kernel is longer than the input).
    window = min(window, n)
    if window <= 1:
        return x.copy()
    kernel = np.ones(window) / window
    y = x
    for _ in range(passes):
        y = np.convolve(y, kernel, mode="same")
    return y


def ma_highpass(x, cutoff, sr=SR, passes=3):
    return x - ma_lowpass(x, cutoff, sr, passes)


def bandpass(x, center, bw, sr=SR):
    lo_cut = max(center - bw / 2.0, 20.0)
    hi_cut = max(center + bw / 2.0, lo_cut + 10.0)
    y = ma_lowpass(x, hi_cut, sr)
    y = y - ma_lowpass(y, lo_cut, sr)
    return y


def onepole_lowpass(x, cutoff, sr=SR):
    """True recursive one-pole low-pass. Only used on short buffers
    (a plain python loop -- fine for < ~0.5s of audio)."""
    if cutoff >= sr / 2:
        return x.copy()
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / sr)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def simple_reverb(x, sr=SR, decay=0.5, delay_ms=35.0, n_taps=10, mix_amt=0.35):
    """Cheap Schroeder-ish reverb: a handful of decaying delayed copies
    summed together (extends the buffer with a decaying tail)."""
    d = max(int(sr * delay_ms / 1000.0), 1)
    out_len = len(x) + d * n_taps
    out = np.zeros(out_len)
    out[: len(x)] += x
    for i in range(1, n_taps + 1):
        amp = (decay ** i) * mix_amt
        start = d * i
        out[start:start + len(x)] += x * amp
    return out


def crossfade_filter_sweep(x, sr, cutoff_start, cutoff_end, shape=None):
    """Smoothly sweeps a low-pass cutoff over the buffer by crossfading
    between two statically-filtered versions -- avoids clicks that a
    segment-by-segment filter would introduce."""
    n = len(x)
    dark = ma_lowpass(x, cutoff_start, sr)
    bright = ma_lowpass(x, cutoff_end, sr)
    if shape is None:
        mix_env = np.linspace(0.0, 1.0, n)
    else:
        mix_env = shape
    return dark * (1.0 - mix_env) + bright * mix_env


def normalize_peak(x, target=0.85):
    peak = np.max(np.abs(x)) if len(x) else 0.0
    if peak < 1e-9:
        return x
    return x * (target / peak)


def to_i16(x):
    x = np.clip(x, -1.0, 1.0)
    return (x * 32767.0).astype(np.int16)


def write_wav(path, x, sr=SR):
    assert not np.isnan(x).any(), f"NaN samples produced for {path}"
    assert not np.isinf(x).any(), f"Inf samples produced for {path}"
    data = to_i16(x)
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(data.tobytes())


# ---------------------------------------------------------------------------
# Musical note helpers
# ---------------------------------------------------------------------------

NOTE_BASE = {
    "C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6, "E": -5,
    "F": -4, "F#": -3, "Gb": -3, "G": -2, "G#": -1, "Ab": -1, "A": 0,
    "A#": 1, "Bb": 1, "B": 2,
}


def note_freq(note):
    name = note[:-1]
    octave = int(note[-1])
    semitone = NOTE_BASE[name] + (octave - 4) * 12
    return 440.0 * (2.0 ** (semitone / 12.0))


def fm_bell(carrier, mod_ratio, index0, tau_index, dur, tau_amp,
            extra_partials=None, strike_noise=0.0):
    """Classic FM bell: sin(2*pi*fc*t + I(t)*sin(2*pi*fm*t)), I(t) decaying
    faster than the overall amplitude envelope -- gives a bright metallic
    attack settling into a pure(ish) tone. `extra_partials` is a list of
    (freq_ratio, amp, tau) inharmonic partials added on top for extra
    "bronze/cursed bell" shimmer."""
    t = t_arr(dur)
    n = len(t)
    mod_freq = carrier * mod_ratio
    index = index0 * np.exp(-t / max(tau_index, 1e-6))
    y = np.sin(2.0 * np.pi * carrier * t + index * np.sin(2.0 * np.pi * mod_freq * t))
    amp_env = np.exp(-t / max(tau_amp, 1e-6))
    y = y * amp_env
    if extra_partials:
        for ratio, amp, tau in extra_partials:
            y = y + amp * np.sin(2.0 * np.pi * carrier * ratio * t) * np.exp(-t / max(tau, 1e-6))
    if strike_noise > 0.0:
        strike = white_noise(n) * exp_env(n, 0.006) * strike_noise
        y = y + strike
    return y


# ===========================================================================
# SFX generators
# ===========================================================================

def gen_flipper_up():
    dur = 0.12
    t = t_arr(dur)
    n = len(t)
    thump = sine(95, t) * exp_env(n, 0.028) * 0.75
    thump2 = sine(150, t) * exp_env(n, 0.015) * 0.3
    noise = white_noise(n)
    click = bandpass(noise, 3500, 3500) * exp_env(n, 0.006) * 1.3
    x = thump + thump2 + click
    return x


def gen_flipper_down():
    dur = 0.1
    t = t_arr(dur)
    n = len(t)
    thump = sine(68, t) * exp_env(n, 0.038) * 0.85
    noise = white_noise(n) * exp_env(n, 0.02) * 0.12
    return thump + noise


def gen_bumper():
    y = fm_bell(830.0, 1.4, 5.0, 0.05, 0.6, 0.35,
                extra_partials=[(2.0, 0.30, 0.25), (2.76, 0.15, 0.15)],
                strike_noise=0.25)
    return y * 0.9


def gen_slingshot():
    dur = 0.15
    n = n_samples(dur)
    noise = white_noise(n)
    slap = bandpass(noise, 1500, 1400) * exp_env(n, 0.022) * 1.1
    zap, _ = chirp_sine(280, 2400, n)
    zap = zap * exp_env(n, 0.03) * 0.45
    return slap + zap


def gen_target():
    dur = 0.2
    t = t_arr(dur)
    n = len(t)
    tock = sine(1200, t) * exp_env(n, 0.025) * 0.8
    click_noise = white_noise(n) * exp_env(n, 0.005) * 0.3
    delay = int(0.04 * SR)
    blip_n = n - delay
    blip, _ = chirp_sine(700, 1700, blip_n)
    blip = blip * exp_env(blip_n, 0.05) * 0.5
    blip_full = np.zeros(n)
    blip_full[delay:] = blip
    return tock + click_noise + blip_full


def gen_drop_target():
    dur = 0.3
    t = t_arr(dur)
    n = len(t)
    clack = bandpass(white_noise(n), 800, 1000) * exp_env(n, 0.02) * 1.2
    thump = sine(180, t) * exp_env(n, 0.03) * 0.55
    tone, _ = chirp_sine(800, 200, n)
    tone = tone * exp_env(n, 0.15) * 0.5
    return clack + thump + tone


def gen_drop_bank_complete():
    notes = ["D5", "F5", "A5"]
    step = 0.22
    events = []
    for i, nt in enumerate(notes):
        f = note_freq(nt)
        y = fm_bell(f, 1.5, 4.0, 0.04, 0.5, 0.3,
                    extra_partials=[(2.0, 0.25, 0.2)], strike_noise=0.1)
        events.append((int(i * step * SR), y))
    return sum_events(events)


def gen_rollover():
    dur = 0.15
    t = t_arr(dur)
    n = len(t)
    tick_len = int(0.004 * SR)
    tick = white_noise(tick_len) * np.linspace(1.0, 0.0, tick_len)
    tick_full = np.zeros(n)
    tick_full[:tick_len] = tick * 0.5
    blip = sine(1000, t) * exp_env(n, 0.05) * 0.6
    return tick_full + blip


def gen_launch():
    dur = 0.4
    n = n_samples(dur)
    noise = white_noise(n)
    rise = int(n * 0.5)
    env = np.concatenate([np.linspace(0.0, 1.0, rise), np.linspace(1.0, 0.0, n - rise)])
    whoosh = bandpass(noise, 900, 800) * env * 0.65
    snap_start = int(n * 0.78)
    snap_n = n - snap_start
    snap = white_noise(snap_n) * exp_env(snap_n, 0.02) * 0.9
    snap_full = np.zeros(n)
    snap_full[snap_start:] = snap
    return whoosh + snap_full


def gen_drain():
    dur = 0.9
    n = n_samples(dur)
    womp, _ = chirp_sine(300, 55, n)
    womp = womp * exp_env(n, 0.5) * 0.8
    x = simple_reverb(womp, decay=0.5, delay_ms=60, n_taps=8, mix_amt=0.3)
    return x[: n_samples(0.95)]


def gen_ball_save():
    notes = ["D5", "F5", "A5", "D6", "F6"]
    step = 0.09
    events = []
    for i, nt in enumerate(notes):
        f = note_freq(nt)
        tn = t_arr(0.25)
        y = sine(f, tn) * exp_env(len(tn), 0.12) * 0.5
        y = y + sine(f * 2, tn) * exp_env(len(tn), 0.06) * 0.2
        events.append((int(i * step * SR), y))
    return sum_events(events)


def gen_enemy_hit():
    dur = 0.2
    t = t_arr(dur)
    n = len(t)
    noise = white_noise(n)
    crunch = bandpass(noise, 500, 800) * exp_env(n, 0.04)
    thump = sine(120, t) * exp_env(n, 0.03) * 0.4
    return crunch + thump


def gen_enemy_crit():
    dur = 0.3
    t = t_arr(dur)
    n = len(t)
    noise = white_noise(n)
    impact = bandpass(noise, 350, 700) * exp_env(n, 0.06) * 1.1
    thump = sine(90, t) * exp_env(n, 0.05) * 0.5
    accent = pad_to(fm_bell(1800, 2.0, 3.0, 0.02, 0.15, 0.08), n)
    return impact + thump + accent * 0.6


def gen_enemy_death():
    dur = 0.6
    n = n_samples(dur)
    x = np.zeros(n)
    for _ in range(14):
        start = int(rng.integers(0, max(n - 200, 1)))
        blen = int(rng.integers(200, 900))
        blen = min(blen, n - start)
        if blen <= 0:
            continue
        burst = white_noise(blen)
        burst = ma_highpass(burst, 1500)
        burst = burst * (np.linspace(1.0, 0.0, blen) ** 2) * rng.uniform(0.2, 0.6)
        x[start:start + blen] += burst
    lowsweep, _ = chirp_sine(400, 80, n)
    lowsweep = lowsweep * exp_env(n, 0.3) * 0.4
    return x * 0.9 + lowsweep


def gen_guardian_shield():
    dur = 0.25
    n = n_samples(dur)
    clink, _ = chirp_sine(3200, 2600, n)
    clink = clink * exp_env(n, 0.05) * 0.8
    t = t_arr(dur)
    clink2 = sine(4700, t) * exp_env(n, 0.03) * 0.4
    return clink + clink2


def gen_boss_hit():
    dur = 0.5
    t = t_arr(dur)
    n = len(t)
    thump, _ = chirp_sine(130, 50, n)
    thump = thump * exp_env(n, 0.15) * 0.9
    base = note_freq("D3")
    choir = (saw(base, t) + saw(base * 1.01, t) + saw(base * 0.99, t) + 0.5 * saw(base * 1.5, t)) / 3.5
    choir = ma_lowpass(choir, 500) * exp_env(n, 0.3) * 0.5
    return thump + choir


def gen_boss_phase():
    dur = 1.5
    t = t_arr(dur)
    n = len(t)
    d2 = note_freq("D2")
    drone = (saw(d2, t) + saw(d2 * 1.01, t) + saw(d2 * 0.99, t)) / 3.0
    mix_env = np.linspace(0.0, 1.0, n) ** 1.5
    y = crossfade_filter_sweep(drone, SR, 150, 1400, shape=mix_env)
    rise_env = np.linspace(0.15, 0.9, n)
    y = y * rise_env
    bell = fm_bell(note_freq("D5"), 1.5, 5.0, 0.1, 0.6, 0.4, strike_noise=0.1)
    bell_start = int(0.85 * SR)
    bell_full = np.zeros(n)
    end = min(n, bell_start + len(bell))
    bell_full[bell_start:end] += bell[: end - bell_start]
    return y + bell_full * 0.7


def gen_boss_death():
    dur = 2.0
    n = n_samples(dur)
    x = np.zeros(n)
    for _ in range(40):
        start = int(rng.integers(0, max(int(n * 0.3), 1)))
        blen = int(rng.integers(300, 1500))
        blen = min(blen, n - start)
        if blen <= 0:
            continue
        burst = white_noise(blen)
        burst = ma_highpass(burst, 1200)
        burst = burst * (np.linspace(1.0, 0.0, blen) ** 2) * rng.uniform(0.3, 0.8)
        x[start:start + blen] += burst
    roar_tone, _ = chirp_sine(500, 40, n)
    roar_dark = ma_lowpass(white_noise(n), 300)
    roar = (roar_tone * 0.6 + roar_dark * 0.6) * (np.linspace(0.9, 0.0, n) ** 0.7)
    x = x * 0.7 + roar
    x = simple_reverb(x, decay=0.6, delay_ms=80, n_taps=10, mix_amt=0.35)
    return x[: n_samples(2.15)]


def gen_magic_on():
    dur = 0.8
    n = n_samples(dur)
    base = note_freq("D5")
    x = np.zeros(n)
    for i, h in enumerate([1, 2, 3, 4, 5]):
        delay = int(i * 0.06 * SR)
        ln = n - delay
        if ln <= 0:
            continue
        tn = np.arange(ln) / SR
        seg = sine(base * h, tn) * exp_env(ln, 0.3) * (0.5 / h)
        x[delay:delay + ln] += seg
    for _ in range(10):
        start = int(rng.integers(0, max(n - 500, 1)))
        f = rng.uniform(2000, 5000)
        ln = int(rng.integers(200, 600))
        ln = min(ln, n - start)
        if ln <= 0:
            continue
        tn = np.arange(ln) / SR
        blip = np.sin(2.0 * np.pi * f * tn) * np.exp(-tn / 0.03) * 0.15
        x[start:start + ln] += blip
    return x


def gen_magic_off():
    dur = 0.5
    n = n_samples(dur)
    freqs = [note_freq("A5"), note_freq("F5"), note_freq("D5")]
    x = np.zeros(n)
    for i, f in enumerate(freqs):
        delay = int(i * 0.07 * SR)
        ln = n - delay
        if ln <= 0:
            continue
        seg, _ = chirp_sine(f, f * 0.6, ln)
        tn = np.arange(ln) / SR
        seg = seg * np.exp(-tn / 0.25) * 0.4
        x[delay:delay + ln] += seg
    return x


def gen_mana_pickup():
    return fm_bell(note_freq("A6"), 2.0, 3.0, 0.03, 0.28, 0.18, strike_noise=0.15)


def gen_multiball_start():
    notes = ["D5", "F5", "A5", "D6", "F6", "A6"]
    step = 0.13
    events = []
    for i, nt in enumerate(notes):
        f = note_freq(nt)
        y = fm_bell(f, 1.4, 4.0, 0.05, 0.7, 0.4,
                    extra_partials=[(2.0, 0.2, 0.3)], strike_noise=0.1)
        events.append((int(i * step * SR), y))
    return sum_events(events)


def gen_lock():
    dur = 0.5
    t = t_arr(dur)
    n = len(t)
    thump = sine(85, t) * exp_env(n, 0.08) * 0.8
    click = white_noise(int(0.01 * SR))
    click_full = np.zeros(n)
    click_full[:len(click)] = click * np.linspace(1.0, 0.0, len(click)) * 0.3
    x = thump + click_full
    x = simple_reverb(x, decay=0.45, delay_ms=90, n_taps=6, mix_amt=0.3)
    return x[: int(SR * 0.55)]


def gen_jackpot():
    dur = 1.2
    n = n_samples(dur)
    t = t_arr(dur)
    chord_notes = ["D4", "F#4", "A4", "D5"]
    chord = np.zeros(n)
    for nt in chord_notes:
        f = note_freq(nt)
        chord += (saw(f, t) * 0.5 + sine(f, t) * 0.5) * 0.25
    chord = chord * adsr(n, a=0.02, d=0.1, s=0.7, r=0.4)
    bell_notes = ["D6", "F#6", "A6"]
    events = []
    for i, nt in enumerate(bell_notes):
        f = note_freq(nt)
        y = fm_bell(f, 1.5, 4.0, 0.04, 0.6, 0.35, strike_noise=0.1)
        events.append((int(i * 0.15 * SR), y))
    bells = sum_events(events, total_len=n)
    return chord * 0.7 + bells * 0.6


def gen_projectile_break():
    dur = 0.2
    t = t_arr(dur)
    n = len(t)
    noise = white_noise(n)
    dark_pop = ma_lowpass(noise, 900) * exp_env(n, 0.03) * 1.1
    click = sine(300, t) * exp_env(n, 0.008) * 0.5
    return dark_pop + click


def gen_projectile_hit_ball():
    dur = 0.3
    t = t_arr(dur)
    n = len(t)
    thump = sine(100, t) * exp_env(n, 0.08) * 0.7
    buzz = square(60, t) * exp_env(n, 0.15) * 0.3
    buzz = ma_lowpass(buzz, 800)
    return thump + buzz


def gen_tilt_warning():
    dur = 0.2
    t = t_arr(dur)
    n = len(t)
    buzz = square(220, t) * adsr(n, a=0.005, d=0.02, s=0.8, r=0.05)
    return buzz * 0.6


def gen_tilt():
    dur = 0.8
    n = n_samples(dur)
    siren_dur = 0.45
    nn = n_samples(siren_dur)
    tn = t_arr(siren_dur)
    lfo = square(6, tn)
    freq_choice = np.where(lfo > 0, 300.0, 450.0)
    phase = 2.0 * np.pi * np.cumsum(freq_choice) / SR
    siren = np.sign(np.sin(phase)) * 0.5
    siren_full = np.zeros(n)
    siren_full[:nn] = siren
    sd_n = n - nn
    shutdown, _ = chirp_sine(400, 40, sd_n)
    shutdown = shutdown * np.linspace(0.7, 0.0, sd_n)
    shutdown_full = np.zeros(n)
    shutdown_full[nn:] = shutdown
    return siren_full + shutdown_full


def gen_nudge():
    dur = 0.12
    t = t_arr(dur)
    n = len(t)
    thump = sine(110, t) * exp_env(n, 0.03) * 0.8
    noise = white_noise(n) * exp_env(n, 0.01) * 0.2
    return thump + noise


def gen_ui_move():
    dur = 0.06
    t = t_arr(dur)
    n = len(t)
    return sine(900, t) * exp_env(n, 0.02) * 0.6


def gen_ui_confirm():
    notes = [600, 900]
    step = 0.07
    events = []
    for i, f in enumerate(notes):
        tn = t_arr(0.08)
        y = sine(f, tn) * exp_env(len(tn), 0.04) * 0.6
        events.append((int(i * step * SR), y))
    return sum_events(events)


def gen_ui_back():
    dur = 0.12
    n = n_samples(dur)
    y, _ = chirp_sine(700, 350, n)
    return y * exp_env(n, 0.05) * 0.6


def gen_game_over():
    notes = ["D4", "C4", "A3", "D3"]
    step = 0.4
    events = []
    for i, nt in enumerate(notes):
        f = note_freq(nt)
        tn = t_arr(0.5)
        y = (saw(f, tn) * 0.5 + sine(f, tn) * 0.5) * exp_env(len(tn), 0.35) * 0.6
        events.append((int(i * step * SR), y))
    x = sum_events(events)
    x = simple_reverb(x, decay=0.55, delay_ms=100, n_taps=8, mix_amt=0.3)
    return x


def gen_victory():
    notes = ["D5", "F#5", "A5", "D6"]
    step = 0.28
    events = []
    for i, nt in enumerate(notes):
        f = note_freq(nt)
        tn = t_arr(0.5)
        y = (saw(f, tn) * 0.4 + square(f, tn) * 0.3) * adsr(len(tn), a=0.01, d=0.05, s=0.7, r=0.3) * 0.5
        events.append((int(i * step * SR), y))
    chord_delay = int(4 * step * SR)
    tn = t_arr(1.2)
    chord = np.zeros(len(tn))
    for nt in ["D5", "F#5", "A5", "D6"]:
        f = note_freq(nt)
        chord += saw(f, tn) * 0.25
    chord = chord * adsr(len(chord), a=0.02, d=0.1, s=0.7, r=0.6) * 0.5
    events.append((chord_delay, chord))
    for i, nt in enumerate(["D6", "F#6", "A6"]):
        f = note_freq(nt)
        y = fm_bell(f, 1.5, 4.0, 0.04, 0.6, 0.35, strike_noise=0.1)
        events.append((int((i * 0.15 + 0.2) * SR), y))
    return sum_events(events)


def gen_skeleton_attack():
    dur = 0.4
    n = n_samples(dur)
    x = np.zeros(n)
    n_clicks = 12
    click_span = int(n * 0.6)
    for i in range(n_clicks):
        pos = int(i * click_span / n_clicks + rng.uniform(-100, 100))
        pos = max(0, min(pos, n - 50))
        ln = int(rng.integers(80, 200))
        ln = min(ln, n - pos)
        if ln <= 0:
            continue
        c = white_noise(ln)
        c = ma_highpass(c, 3000)
        c = c * np.linspace(1.0, 0.0, ln) * rng.uniform(0.4, 0.9)
        x[pos:pos + ln] += c
    noise2 = white_noise(n)
    swish_env = np.concatenate([np.linspace(0.0, 1.0, n // 2), np.linspace(1.0, 0.0, n - n // 2)])
    swish = bandpass(noise2, 1500, 1500) * swish_env * 0.5
    return x * 0.8 + swish


def gen_portal_open():
    dur = 1.2
    t = t_arr(dur)
    n = len(t)
    noise = white_noise(n)
    whoosh = ma_lowpass(noise, 150) * np.linspace(0.2, 0.8, n) * 0.6
    tone, freq_t = chirp_sine(80, 260, n)
    tone = tone * np.linspace(0.1, 0.7, n) * 0.5
    phase = 2.0 * np.pi * np.cumsum(freq_t) / SR
    reso = 2.0 * (np.mod(phase / (2.0 * np.pi) + 0.5, 1.0) - 0.5)
    reso = ma_lowpass(reso, 800) * np.linspace(0.05, 0.4, n)
    return whoosh + tone + reso


SFX_GENERATORS = [
    ("flipper_up.wav", gen_flipper_up),
    ("flipper_down.wav", gen_flipper_down),
    ("bumper.wav", gen_bumper),
    ("slingshot.wav", gen_slingshot),
    ("target.wav", gen_target),
    ("drop_target.wav", gen_drop_target),
    ("drop_bank_complete.wav", gen_drop_bank_complete),
    ("rollover.wav", gen_rollover),
    ("launch.wav", gen_launch),
    ("drain.wav", gen_drain),
    ("ball_save.wav", gen_ball_save),
    ("enemy_hit.wav", gen_enemy_hit),
    ("enemy_crit.wav", gen_enemy_crit),
    ("enemy_death.wav", gen_enemy_death),
    ("guardian_shield.wav", gen_guardian_shield),
    ("boss_hit.wav", gen_boss_hit),
    ("boss_phase.wav", gen_boss_phase),
    ("boss_death.wav", gen_boss_death),
    ("magic_on.wav", gen_magic_on),
    ("magic_off.wav", gen_magic_off),
    ("mana_pickup.wav", gen_mana_pickup),
    ("multiball_start.wav", gen_multiball_start),
    ("lock.wav", gen_lock),
    ("jackpot.wav", gen_jackpot),
    ("projectile_break.wav", gen_projectile_break),
    ("projectile_hit_ball.wav", gen_projectile_hit_ball),
    ("tilt_warning.wav", gen_tilt_warning),
    ("tilt.wav", gen_tilt),
    ("nudge.wav", gen_nudge),
    ("ui_move.wav", gen_ui_move),
    ("ui_confirm.wav", gen_ui_confirm),
    ("ui_back.wav", gen_ui_back),
    ("game_over.wav", gen_game_over),
    ("victory.wav", gen_victory),
    ("skeleton_attack.wav", gen_skeleton_attack),
    ("portal_open.wav", gen_portal_open),
]


# ===========================================================================
# Music generators (seamless loops)
# ===========================================================================

def make_seamless(x, loop_len, xfade_len):
    """Crossfades the tail of a slightly-longer-than-loop buffer back into
    its head, so that looping x[:loop_len] plays with no seam."""
    head = x[:xfade_len]
    tail = x[loop_len:loop_len + xfade_len]
    fade_in = np.linspace(0.0, 1.0, xfade_len)
    fade_out = 1.0 - fade_in
    blended = head * fade_in + tail * fade_out
    out = x[:loop_len].copy()
    out[:xfade_len] = blended
    return out


def gen_ambient_loop():
    bpm = 80.0
    beat = 60.0 / bpm          # 0.75 s
    bar = beat * 4.0           # 3.0 s
    bars = 8
    loop_dur = bar * bars      # 24.0 s
    xfade_dur = bar            # 1 bar crossfade
    total_dur = loop_dur + xfade_dur
    n_total = n_samples(total_dur)
    t = t_arr(total_dur)

    # Dark sustained drone: detuned saws on D2, lowpassed ~400 Hz
    d2 = note_freq("D2")
    drone_raw = (saw(d2, t) + saw(d2 * 1.006, t) + saw(d2 * 0.994, t)) / 3.0
    drone = ma_lowpass(drone_raw, 400)
    swell = 0.5 + 0.5 * np.sin(2.0 * np.pi * (1.0 / 9.0) * t)
    drone = drone * (0.5 + 0.3 * swell) * 0.5

    # Deep sub pulse on beat 1 of each bar
    sub = np.zeros(n_total)
    n_bars_total = int(np.ceil(total_dur / bar)) + 1
    for b in range(n_bars_total):
        start = int(b * bar * SR)
        if start >= n_total:
            break
        ln = min(int(0.4 * SR), n_total - start)
        tn = np.arange(ln) / SR
        pulse = np.sin(2.0 * np.pi * 55.0 * tn) * np.exp(-tn / 0.25) * 0.7
        sub[start:start + ln] += pulse

    # Slow arpeggiated bell notes every 2 beats: D F A C (Dm7)
    arp_notes = ["D4", "F4", "A4", "C5"]
    step = beat * 2.0
    n_steps = int(np.ceil(total_dur / step)) + 1
    bell_events = []
    for i in range(n_steps):
        start = int(i * step * SR)
        if start >= n_total:
            break
        f = note_freq(arp_notes[i % len(arp_notes)])
        y = fm_bell(f, 1.4, 3.0, 0.15, 2.5, 1.2,
                    extra_partials=[(2.0, 0.15, 0.8)])
        bell_events.append((start, y * 0.35))
    bell = sum_events(bell_events, total_len=n_total)

    # Subtle noise "wind"
    wind = ma_lowpass(white_noise(n_total), 500)
    wind_env = 0.03 + 0.02 * np.sin(2.0 * np.pi * (1.0 / 13.0) * t)
    wind = wind * wind_env

    x = drone + sub + bell + wind
    x = simple_reverb(x, decay=0.35, delay_ms=150, n_taps=4, mix_amt=0.15)
    x = pad_to(x, n_total)

    loop_len = n_samples(loop_dur)
    xfade_len = n_samples(xfade_dur)
    return make_seamless(x, loop_len, xfade_len)


def gen_boss_loop():
    bpm = 100.0
    beat = 60.0 / bpm          # 0.6 s
    bar = beat * 4.0           # 2.4 s
    bars = 8
    loop_dur = bar * bars      # 19.2 s
    xfade_dur = bar
    total_dur = loop_dur + xfade_dur
    n_total = n_samples(total_dur)
    t = t_arr(total_dur)

    # Aggressive detuned-saw bass riff: D D F D C D A G per bar (eighth notes)
    riff = ["D2", "D2", "F2", "D2", "C2", "D2", "A1", "G1"]
    note_dur = beat / 2.0
    n_eighths = int(np.ceil(total_dur / note_dur)) + 1
    bass = np.zeros(n_total)
    for i in range(n_eighths):
        start = int(i * note_dur * SR)
        if start >= n_total:
            break
        f = note_freq(riff[i % len(riff)])
        ln = min(int(note_dur * SR * 1.05), n_total - start)
        if ln <= 0:
            continue
        tn = np.arange(ln) / SR
        note = (saw(f, tn) + saw(f * 1.01, tn) + saw(f * 0.99, tn)) / 3.0
        note = ma_lowpass(note, 900)
        env = np.exp(-tn / 0.22)
        bass[start:start + ln] += note * env * 0.5

    # Driving pulse: kick-like sub thump every beat, low tom on off-beats
    perc = np.zeros(n_total)
    n_beats = int(np.ceil(total_dur / beat)) + 1
    for i in range(n_beats):
        start = int(i * beat * SR)
        if start >= n_total:
            break
        ln = min(int(0.25 * SR), n_total - start)
        if ln <= 0:
            continue
        kick, _ = chirp_sine(140, 50, ln)
        tn = np.arange(ln) / SR
        kick = kick * np.exp(-tn / 0.12)
        perc[start:start + ln] += kick * 0.8

        tom_start = int((i * beat + beat / 2.0) * SR)
        if tom_start < n_total:
            ln2 = min(int(0.2 * SR), n_total - tom_start)
            if ln2 > 0:
                tn2 = np.arange(ln2) / SR
                tom = np.sin(2.0 * np.pi * 90.0 * tn2) * np.exp(-tn2 / 0.1)
                perc[tom_start:tom_start + ln2] += tom * 0.5

    # Distorted bell hit every bar
    n_bars_total = int(np.ceil(total_dur / bar)) + 1
    bell_events = []
    for b in range(n_bars_total):
        start = int(b * bar * SR)
        if start >= n_total:
            break
        y = fm_bell(note_freq("D5"), 1.6, 6.0, 0.08, 1.0, 0.5,
                    extra_partials=[(2.3, 0.3, 0.3)])
        y = np.tanh(y * 2.5) * 0.5
        bell_events.append((start, y))
    bell = sum_events(bell_events, total_len=n_total)

    # Dark choir-like sustained pad
    d3 = note_freq("D3")
    pad_raw = (saw(d3, t) + saw(d3 * 1.01, t) + saw(d3 * 0.99, t) + 0.5 * saw(d3 * 1.5, t)) / 3.5
    pad = ma_lowpass(pad_raw, 600) * 0.25

    x = bass + perc + bell + pad
    x = simple_reverb(x, decay=0.3, delay_ms=100, n_taps=4, mix_amt=0.12)
    x = pad_to(x, n_total)

    loop_len = n_samples(loop_dur)
    xfade_len = n_samples(xfade_dur)
    return make_seamless(x, loop_len, xfade_len)


MUSIC_GENERATORS = [
    ("ambient_loop.wav", gen_ambient_loop),
    ("boss_loop.wav", gen_boss_loop),
]


# ===========================================================================
# Main
# ===========================================================================

def main():
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)

    results = []

    for fname, genfunc in SFX_GENERATORS:
        rng_state = rng.bit_generator.state  # keep determinism reproducible per-file too
        x = genfunc()
        x = fade_io(x, fade_in_ms=1.0, fade_out_ms=15.0)
        x = normalize_peak(x, SFX_PEAK_TARGET)
        path = os.path.join(SFX_DIR, fname)
        write_wav(path, x)
        results.append(("sfx/" + fname, len(x) / SR, float(np.max(np.abs(x)))))

    for fname, genfunc in MUSIC_GENERATORS:
        x = genfunc()
        x = normalize_peak(x, MUSIC_PEAK_TARGET)
        path = os.path.join(MUSIC_DIR, fname)
        write_wav(path, x)
        results.append(("music/" + fname, len(x) / SR, float(np.max(np.abs(x)))))

    print(f"{'file':32s} {'dur(s)':>8s} {'peak':>8s}")
    print("-" * 50)
    for name, dur, peak in results:
        print(f"{name:32s} {dur:8.3f} {peak:8.4f}")

    n_nan = sum(1 for _ in [] )  # placeholder, real NaN check happens in write_wav
    print("-" * 50)
    print(f"Generated {len(results)} files. All peaks <= {max(SFX_PEAK_TARGET, MUSIC_PEAK_TARGET):.2f}, "
          f"no NaNs (checked at write time).")


if __name__ == "__main__":
    main()
