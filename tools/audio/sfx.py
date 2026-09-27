"""Ses efekti tarifleri (Aşama 9) — görsel yönle aynı: karanlık, kanlı, vahşi.

Her tarif fn(rng, v) → mono dizi (v: varyant sırası). SOUNDS = {id: (fn, varyant_sayısı, hedef_gürlük_dB)}.
Oyun data/audio.json > sounds içindeki id'leri kullanır; her varyant assets/audio/sfx/<id>_<n>.wav olarak yazılır.
Katmanlar: ıslak et (squelch), kemik çatırtısı (crack), alçak gövde darbesi (thump), hışırtı (whoosh), paslı metal
(modal), gürleme (growl), yankı (zindan taşı).
"""

from __future__ import annotations

import numpy as np

from dsp import (Mix, SR, bandpass, brown, bubbles, crackle, env_bell, env_exp, env_pts, formant, formant_sweep, glide,
                 highpass, lowpass, metal_modes, modal, n_of, osc, pluck, reverb, reverse, sat, smooth_noise, supersaw,
                 sweep_bp, sweep_lp, tvec, white)


# --- katmanlar ---

def logcurve(d: float, pts) -> np.ndarray:
    """(oran, Hz) noktalarından log-frekansta eğri (d sn uzunluğunda)."""
    t = np.linspace(0.0, 1.0, n_of(d))
    return np.exp(np.interp(t, [p[0] for p in pts], [np.log(p[1]) for p in pts]))


def thump(rng, f0=130.0, f1=45.0, d=0.3, tau=0.08, click=0.25):
    x = osc(glide(f0, f1, d, 0.35), d) * env_exp(d, tau, 0.0015)
    if click:
        c = highpass(white(0.008, rng), 1800) * env_exp(0.008, 0.002, 0.0)
        x[:len(c)] += c * click
    return x


def whoosh(rng, d=0.2, f0=500.0, f1=2400.0, f2=800.0, bw=0.8, peak=0.45, power=1.8, grit=0.0):
    n = white(d, rng)
    if grit:
        n = n + grit * brown(d, rng)
    fc = logcurve(d, [(0, f0), (peak, f1), (1, f2)])
    return sweep_bp(n, fc, bw) * env_bell(d, peak, power)


def squelch(rng, d=0.2, f_hi=2600.0, f_lo=450.0, grains=16, wet=1.0):
    """Islak et: süzgeci kapanan pütürlü gürültü + aşağı kayan kabarcıklar."""
    n = white(d, rng) * (0.25 + np.power(smooth_noise(d, 70, rng), 3) * 1.5)
    x = sweep_lp(n, logcurve(d, [(0, f_hi), (1, f_lo)]), 2.0) * env_exp(d, d * 0.32, 0.002)
    b = bubbles(d * 0.9, rng, grains, 160, 650, 0.55, (0.012, 0.04), 0.012)
    m = Mix(d).add(x).add(b, 0.004, 0.5 * wet)
    return m.out()


def crack(rng, d=0.05, fc=3200.0, rate=500.0, decay=0.01, body=0.5):
    """Kemik çatırtısı: yoğun dürtüler + sert geçiş."""
    x = crackle(d, rng, rate, fc, 1.1, decay) * 3.0
    b = highpass(white(0.004, rng), 1500) * body
    x[:len(b)] += b
    return x


def rubble(rng, d=0.8, fc=900.0, rate=160.0, decay=0.25, low=0.6):
    x = crackle(d, rng, rate, fc, 1.3, decay) * 2.0
    r = lowpass(brown(d, rng), 500) * env_exp(d, decay, 0.005) * low
    return x + r


def metal(rng, f0=420.0, d=0.8, tau=0.5, count=8, hit=0.3):
    x = modal(d, metal_modes(f0, count, rng, tau), rng)
    h = highpass(white(0.01, rng), 2500) * env_exp(0.01, 0.003, 0.0) * hit
    x[:len(h)] += h * 3
    return x


def bell(rng, f0=440.0, d=2.0, tau=1.2):
    ratios = [(0.5, 1.2, 0.5), (1.0, 1.0, 1.0), (1.19, 0.6, 0.45), (1.5, 0.5, 0.35), (2.0, 0.45, 0.4), (2.52, 0.3, 0.2), (3.0, 0.2, 0.15)]
    return modal(d, [(f0 * r, tau * k, a) for r, k, a in ratios], rng)


def growl(rng, d=0.5, f0=140.0, f1=70.0, v0="a", v1="u", rough=0.5, drive=2.5):
    """Gırtlaktan gürleme/uluma: titreşimli testere + alt oktav + nefes, formantla."""
    n = n_of(d)
    vib = 1.0 + rough * 0.06 * (smooth_noise(d, 30, rng) - 0.5) + 0.02 * np.sin(2 * np.pi * 6 * tvec(d))
    f = glide(f0, f1, d, 0.8) * vib
    src = osc(f, d, "saw") + 0.6 * osc(f * 0.5, d, "saw") + rough * 0.5 * white(d, rng)
    x = formant_sweep(src, v0, v1) if v0 != v1 else formant(src, v0)
    return sat(x * 2.0, drive) * env_pts(d, [(0, 0), (0.04, 1), (d * 0.7, 0.8), (d, 0)])


def zap(rng, d=0.3, f=90.0, bright=4000.0):
    jit = f * (0.7 + 0.8 * smooth_noise(d, 45, rng))
    buzz = osc(jit, d, "square") * (smooth_noise(d, 90, rng) > 0.35)
    cr = crackle(d, rng, 1400, bright, 1.2, d * 0.35) * 3
    x = highpass(buzz, 200) * 0.5 + cr
    return sat(x * env_exp(d, d * 0.4, 0.001) * 1.5, 3.0)


def fire_roar(rng, d=0.5, lo=300.0, hi=1800.0):
    n = white(d, rng) * (0.4 + smooth_noise(d, 25, rng))
    x = sweep_lp(n, logcurve(d, [(0, lo), (0.3, hi), (1, lo)]), 1.5)
    return x * env_bell(d, 0.25, 1.2) + crackle(d, rng, 90, 3200, 1.0) * 1.5


def explosion(rng, d=0.9, low=35.0):
    n = white(d, rng)
    x = sweep_lp(n, logcurve(d, [(0, 7000), (0.15, 1500), (1, 200)]), 2.0) * env_exp(d, d * 0.22, 0.001)
    b = thump(rng, 95, low, d, d * 0.3, 0.4)
    deb = crackle(d, rng, 120, 1400, 1.2, d * 0.3) * 1.5
    return sat((x + b * 1.2 + deb) * 1.3, 2.5)


def verb(rng, x, rt=0.9, mix=0.3, damp=3000.0):
    return reverb(x, rt, mix, rng, damp)


def chord(rng, freqs, d, shape="saw", lp=900.0, att=0.3):
    m = np.zeros(n_of(d))
    for f in freqs:
        m += supersaw(f, d, rng, 3, 0.008, shape)
    return lowpass(m, lp) * env_pts(d, [(0, 0), (att, 1), (d * 0.6, 0.7), (d, 0)])


def cloth(rng, d=0.2, rate=22.0):
    n = lowpass(white(d, rng), 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * rate * tvec(d)) ** 2)
    return n * env_bell(d, 0.3, 1.5)


def coin(rng, f0=None):
    f0 = f0 or rng.uniform(3000, 4200)
    x = modal(0.35, [(f0, 0.09, 1.0), (f0 * 1.5, 0.06, 0.5), (f0 * 2.7, 0.04, 0.3), (f0 * 0.62, 0.12, 0.3)], rng)
    return x


# --- tarifler ---

def hit_flesh(rng, v):
    m = Mix(0.3)
    m.add(thump(rng, rng.uniform(135, 175), 48, 0.22, 0.055, 0.3), 0, 0.9)
    m.add(squelch(rng, rng.uniform(0.13, 0.19)), 0.002, 0.8)
    m.add(crack(rng, 0.03, rng.uniform(2200, 3000), 380), 0, 0.25)
    return sat(m.out() * 1.3, 1.6)


def hit_heavy(rng, v):
    m = Mix(0.45)
    m.add(thump(rng, rng.uniform(100, 125), 36, 0.38, 0.11, 0.4), 0, 1.0)
    m.add(squelch(rng, 0.26, 2200, 380, 24), 0.004, 0.95)
    m.add(crack(rng, 0.06, 1900, 700, 0.015), 0.002, 0.55)
    m.add(lowpass(brown(0.35, rng), 250) * env_exp(0.35, 0.1), 0, 0.5)
    return sat(m.out() * 1.4, 2.0)


def hit_crit(rng, v):
    m = Mix(0.8)
    m.add(hit_heavy(rng, v), 0, 0.9)
    m.add(metal(rng, rng.uniform(1700, 2100), 0.6, 0.28, 6, 0.1), 0, 0.3)
    m.add(crack(rng, 0.08, 3000, 900, 0.02, 0.8), 0.003, 0.8)
    return verb(rng, m.out(), 0.7, 0.18)


def hit_bone(rng, v):
    m = Mix(0.25)
    for i in range(rng.integers(3, 6)):
        dd = rng.uniform(0.008, 0.016)
        c = bandpass(white(dd, rng), rng.uniform(1100, 2600), 0.6) * env_exp(dd, dd * 0.3, 0.0)
        m.add(c * 3, rng.uniform(0, 0.05), rng.uniform(0.4, 1.0))
    m.add(thump(rng, 230, 120, 0.12, 0.03, 0.2), 0, 0.5)
    m.add(crack(rng, 0.06, 3000, 450, 0.02), 0, 0.5)
    return m.out()


def hit_stone(rng, v):
    m = Mix(0.35)
    m.add(lowpass(brown(0.2, rng), 900) * env_exp(0.2, 0.05), 0, 0.9)
    m.add(crack(rng, 0.05, 1500, 600, 0.012), 0, 0.8)
    m.add(thump(rng, 95, 50, 0.2, 0.06), 0, 0.7)
    m.add(rubble(rng, 0.3, 1000, 120, 0.08, 0.2), 0.01, 0.5)
    return sat(m.out() * 1.3, 1.8)


def hit_metal(rng, v):
    m = Mix(0.7)
    m.add(metal(rng, rng.uniform(360, 470), 0.7, 0.3, 7, 0.4), 0, 0.55)
    m.add(thump(rng, 160, 70, 0.18, 0.05), 0, 0.7)
    m.add(squelch(rng, 0.1), 0.004, 0.3)
    return m.out()


def hit_ghost(rng, v):
    m = Mix(0.5)
    m.add(whoosh(rng, 0.3, 280, rng.uniform(800, 1100), 180, 0.6, 0.15, 1.3), 0, 0.8)
    t = tvec(0.35)
    m.add(osc(glide(110, 70, 0.35), 0.35) * env_exp(0.35, 0.12) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t)), 0, 0.6)
    tail = reverse(verb(rng, highpass(white(0.02, rng), 900) * env_exp(0.02, 0.005), 0.4, 1.0))
    m.add(tail[:n_of(0.25)], 0, 0.3)
    return m.out()


def hit_block(rng, v):
    m = Mix(1.0)
    m.add(metal(rng, rng.uniform(270, 330), 1.0, 0.45, 9, 0.5), 0, 0.7)
    m.add(thump(rng, 170, 90, 0.15, 0.04), 0, 0.6)
    return verb(rng, m.out(), 0.8, 0.2)


def hit_immune(rng, v):
    m = Mix(0.25)
    m.add(lowpass(thump(rng, 230, 150, 0.15, 0.04, 0.1), 900), 0, 1.0)
    m.add(lowpass(white(0.08, rng), 600) * env_exp(0.08, 0.02), 0, 0.5)
    return m.out()


def execute(rng, v):
    m = Mix(1.4)
    m.add(whoosh(rng, 0.14, 700, 3000, 1200, 0.6, 0.7, 1.4), 0, 0.6)
    m.add(thump(rng, 90, 28, 0.6, 0.2, 0.5), 0.1, 1.1)
    m.add(squelch(rng, 0.4, 2000, 300, 30), 0.1, 1.0)
    m.add(crack(rng, 0.1, 2000, 900, 0.03, 1.0), 0.1, 0.9)
    return verb(rng, sat(m.out() * 1.4, 2.2), 1.0, 0.25)


def swing_blade(rng, v):
    m = Mix(0.3)
    m.add(whoosh(rng, rng.uniform(0.17, 0.23), rng.uniform(450, 600), rng.uniform(2200, 3000), 800, 0.7, 0.4), 0, 1.0)
    m.add(metal(rng, rng.uniform(2400, 2900), 0.25, 0.1, 4, 0.0), 0.03, 0.04)
    return m.out()


def swing_heavy(rng, v):
    return whoosh(rng, rng.uniform(0.28, 0.34), 220, rng.uniform(1100, 1450), 380, 0.85, 0.5, 1.6, 0.6)


def punch(rng, v):
    m = Mix(0.15)
    m.add(whoosh(rng, 0.09, 700, rng.uniform(1600, 2000), 900, 0.9, 0.55, 1.4), 0, 1.0)
    m.add(crackle(0.08, rng, 180, 3600, 1.0, 0.03) * 2, 0.02, 0.3)
    return m.out()


def thrust(rng, v):
    return whoosh(rng, 0.13, 900, rng.uniform(2800, 3400), 1900, 0.6, 0.6, 1.3)


def stab(rng, v):
    m = Mix(0.4)
    m.add(whoosh(rng, 0.16, 1400, 3200, 500, 0.6, 0.3, 1.2), 0, 0.9)
    m.add(osc(glide(300, 90, 0.2), 0.2) * env_exp(0.2, 0.06) * 0.4, 0.08)
    return m.out()


def spin(rng, v):
    d = 0.5
    fc = 1000 * np.power(2.4, np.sin(2 * np.pi * 2.2 * tvec(d) - np.pi / 2))
    x = sweep_bp(white(d, rng), fc, 0.7) * env_bell(d, 0.4, 1.2)
    return x + metal(rng, 2600, d, 0.12, 4, 0.0) * 0.03


def throw_whirl(rng, v):
    d = 0.55
    am = np.power(np.sin(2 * np.pi * 13 * tvec(d)), 2)
    return sweep_bp(white(d, rng), logcurve(d, [(0, 700), (1, 1400)]), 0.8) * am * env_bell(d, 0.2, 1.0)


def slam(rng, v):
    m = Mix(1.0)
    m.add(thump(rng, 85, 30, 0.7, 0.22, 0.5), 0, 1.1)
    m.add(rubble(rng, 0.7, 700, 260, 0.15, 0.8), 0.005, 0.8)
    m.add(lowpass(white(0.4, rng), 450) * env_exp(0.4, 0.1), 0, 0.6)
    return sat(m.out() * 1.3, 2.0)


def ground_slam_big(rng, v):
    return verb(rng, slam(rng, v) + explosion(rng, 1.0, 26) * 0.5, 1.4, 0.3, 2000)


def bow(rng, v):
    m = Mix(0.6)
    m.add(pluck(rng.uniform(88, 110), 0.5, rng, 0.993, 0.85) * env_exp(0.5, 0.18), 0, 1.0)
    m.add(whoosh(rng, 0.16, 1500, 3300, 2200, 0.6, 0.3, 1.2), 0.012, 0.35)
    m.add(thump(rng, 200, 120, 0.06, 0.015, 0.2), 0, 0.3)
    return lowpass(m.out(), 7000)


def bow_heavy(rng, v):
    m = Mix(0.9)
    m.add(pluck(70, 0.8, rng, 0.995, 0.9) * env_exp(0.8, 0.3), 0, 1.0)
    m.add(whoosh(rng, 0.3, 900, 3600, 1800, 0.6, 0.25, 1.2), 0.01, 0.6)
    m.add(thump(rng, 160, 60, 0.3, 0.08), 0, 0.6)
    return m.out()


def crossbow(rng, v):
    m = Mix(0.5)
    m.add(highpass(white(0.005, rng), 3000) * 2.0, 0, 0.8)
    m.add(modal(0.2, [(rng.uniform(850, 1000), 0.05, 1.0), (2100, 0.03, 0.5)], rng), 0, 0.4)
    m.add(pluck(rng.uniform(120, 140), 0.3, rng, 0.99, 0.9) * env_exp(0.3, 0.08), 0.004, 0.8)
    m.add(thump(rng, 230, 120, 0.1, 0.025), 0.004, 0.6)
    return m.out()


def crossbow_fan(rng, v):
    m = Mix(0.7)
    for i in range(5):
        m.add(crossbow(rng, v), i * 0.018, 0.55)
    return m.out()


def cast(rng, v):
    d = 0.4
    base = [196.0, 220.0, 233.1, 261.6][v % 4]
    f = glide(base, base * 1.5, d, 0.6)
    mod = osc(f * 1.41, d) * 3.0 * env_exp(d, 0.15)
    car = np.sin(2 * np.pi * np.cumsum(f) / SR + mod) + 0.6 * osc(f * 1.06, d)
    sh = sweep_bp(white(d, rng), logcurve(d, [(0, 2000), (1, 6000)]), 0.6) * (smooth_noise(d, 60, rng) ** 2)
    x = (car * 0.5 + sh * 0.6) * env_pts(d, [(0, 0), (0.03, 1), (d, 0)], 1.3)
    return verb(rng, x, 0.8, 0.3)


def cast_multi(rng, v):
    m = Mix(0.6)
    m.add(crackle(0.4, rng, 90, 2500, 0.9) * 2.0 * env_bell(0.4, 0.3), 0, 0.6)
    m.add(cast(rng, v), 0.02, 0.8)
    m.add(cloth(rng, 0.3, 30), 0, 0.4)
    return m.out()


def orb_cast(rng, v):
    d = 0.6
    f = glide(90, 200, d, 0.7)
    x = sweep_lp(osc(f, d, "saw") + 0.5 * osc(f * 1.01, d, "saw"), logcurve(d, [(0, 300), (1, 2600)]), 2.0)
    x = x + osc(55, d) * 0.6
    return verb(rng, sat(x * env_pts(d, [(0, 0), (0.5, 1), (d, 0)], 1.2), 2.0), 0.9, 0.25)


def rune(rng, v):
    d = 0.35
    t = tvec(d)
    x = osc(rng.uniform(65, 75), d) + 0.4 * lowpass(osc(140, d, "saw"), 600)
    x *= (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * env_exp(d, 0.14, 0.01)
    sh = bandpass(white(d, rng), 5000, 0.5) * env_exp(d, 0.08) * 0.3
    return verb(rng, x + sh, 0.7, 0.25)


def rune_arm(rng, v):
    m = Mix(0.6)
    m.add(rune(rng, v), 0, 1.0)
    m.add(highpass(white(0.004, rng), 3000), 0.3, 0.8)
    return m.out()


def rune_blast(rng, v):
    m = Mix(1.0)
    m.add(explosion(rng, 0.7, 35), 0, 0.9)
    m.add(bandpass(white(0.5, rng), 3000, 0.7) * env_exp(0.5, 0.12), 0, 0.4)
    return verb(rng, m.out(), 1.0, 0.25)


def explosion_small(rng, v):
    return verb(rng, explosion(rng, 0.7, 35), 0.8, 0.22)


def explosion_fire(rng, v):
    m = Mix(1.0)
    m.add(explosion(rng, 0.7, 35), 0, 0.8)
    m.add(fire_roar(rng, 0.8, 250, 1500), 0.02, 0.8)
    return verb(rng, m.out(), 0.9, 0.22)


def flesh_burst(rng, v):
    m = Mix(1.0)
    m.add(explosion(rng, 0.6, 38), 0, 0.7)
    m.add(squelch(rng, 0.45, 2000, 300, 40), 0, 1.1)
    m.add(squelch(rng, 0.2, 2500, 500, 10), 0.12, 0.6)
    return verb(rng, sat(m.out() * 1.2, 1.8), 0.8, 0.2)


def arrow_impact(rng, v):
    m = Mix(0.2)
    m.add(thump(rng, 420, 200, 0.05, 0.015, 0.3), 0, 0.8)
    m.add(crack(rng, 0.03, 2600, 400, 0.01), 0, 0.4)
    m.add(whoosh(rng, 0.08, 3000, 4000, 2500, 0.5, 0.1, 1.0), 0, 0.2)
    return m.out()


def storm_pulse(rng, v):
    m = Mix(0.8)
    m.add(crackle(0.3, rng, 1200, 4200, 1.3, 0.05) * 3, 0, 0.7)
    m.add(sweep_lp(white(0.6, rng), logcurve(0.6, [(0, 3500), (1, 180)]), 2.0) * env_exp(0.6, 0.15), 0, 0.8)
    m.add(thump(rng, 75, 35, 0.5, 0.15), 0, 0.8)
    return sat(m.out(), 2.0)


def el_fire(rng, v):
    m = Mix(0.5)
    m.add(fire_roar(rng, 0.42, 280, rng.uniform(2000, 2800)), 0, 1.0)
    return m.out()


def el_water(rng, v):
    m = Mix(0.4)
    s = sweep_lp(highpass(white(0.25, rng), 700), logcurve(0.25, [(0, 7000), (1, 1400)]), 2.0) * env_exp(0.25, 0.06)
    m.add(s, 0, 0.8)
    m.add(bubbles(0.35, rng, 14, 400, 1500, 1.8, (0.02, 0.05), 0.02), 0.02, 0.6)
    return m.out()


def el_lightning(rng, v):
    return zap(rng, rng.uniform(0.22, 0.3), rng.uniform(70, 110), 4200)


def el_poison(rng, v):
    m = Mix(0.45)
    m.add(bubbles(0.4, rng, 22, 150, 600, 1.4, (0.02, 0.06), 0.02), 0, 0.8)
    m.add(highpass(white(0.35, rng), 4000) * env_bell(0.35, 0.2, 1.5) * (0.5 + smooth_noise(0.35, 40, rng)), 0, 0.3)
    return m.out()


def el_ice(rng, v):
    m = Mix(0.4)
    f0 = rng.uniform(2200, 2800)
    m.add(modal(0.35, metal_modes(f0, 6, rng, 0.18), rng), 0, 0.4)
    m.add(crack(rng, 0.04, 5000, 800, 0.008, 0.5), 0, 0.6)
    m.add(highpass(white(0.2, rng), 6000) * env_exp(0.2, 0.05), 0, 0.3)
    return m.out()


def el_dark(rng, v):
    d = 0.45
    sw = reverse(bandpass(white(d, rng), 600, 0.8) * env_exp(d, 0.12))
    drone = lowpass(osc(55, d, "saw") + osc(58.3, d, "saw"), 300) * env_bell(d, 0.6, 1.0)
    return sw * 0.8 + drone * 0.5


def freeze(rng, v):
    m = Mix(0.7)
    for i in range(8):
        f = 1800 * (1.12 ** i) * rng.uniform(0.97, 1.03)
        m.add(modal(0.3, [(f, 0.12, 1.0), (f * 2.4, 0.06, 0.4)], rng), i * 0.035, 0.35)
    m.add(crack(rng, 0.06, 4500, 900, 0.015), 0.28, 0.7)
    return verb(rng, m.out(), 0.9, 0.3)


def combo_electroshock(rng, v):
    m = Mix(1.0)
    for i in range(4):
        m.add(zap(rng, 0.3, rng.uniform(60, 120), 3800), i * 0.09, 0.8)
    m.add(thump(rng, 80, 35, 0.4, 0.12), 0, 0.8)
    return verb(rng, m.out(), 0.9, 0.25)


def combo_melt(rng, v):
    m = Mix(1.2)
    m.add(thump(rng, 70, 24, 0.9, 0.3, 0.5), 0, 1.2)
    m.add(fire_roar(rng, 0.9, 200, 1400), 0, 0.8)
    m.add(highpass(white(1.1, rng), 3000) * env_exp(1.1, 0.4, 0.05) * (0.4 + smooth_noise(1.1, 50, rng)), 0.05, 0.5)
    return verb(rng, sat(m.out(), 2.0), 1.2, 0.25)


def combo_freeze(rng, v):
    m = Mix(1.0)
    m.add(freeze(rng, v), 0, 0.9)
    m.add(thump(rng, 90, 40, 0.5, 0.14), 0.25, 0.7)
    m.add(crack(rng, 0.1, 3500, 1200, 0.03, 1.0), 0.26, 0.9)
    return m.out()


def combo_shatter(rng, v):
    m = Mix(1.0)
    for _ in range(45):
        f = np.exp(rng.uniform(np.log(1800), np.log(7500)))
        m.add(modal(0.25, [(f, rng.uniform(0.03, 0.15), 1.0), (f * 1.7, 0.03, 0.3)], rng), rng.exponential(0.08), rng.uniform(0.1, 0.35))
    m.add(crack(rng, 0.08, 4000, 1500, 0.02, 1.0), 0, 1.0)
    m.add(thump(rng, 120, 50, 0.3, 0.08), 0, 0.7)
    return verb(rng, m.out(), 1.1, 0.25)


def combo_poison_burst(rng, v):
    m = Mix(1.1)
    m.add(flesh_burst(rng, v), 0, 0.9)
    m.add(bubbles(0.9, rng, 40, 120, 500, 1.3, (0.03, 0.08), 0.03), 0.05, 0.6)
    m.add(highpass(white(0.8, rng), 3500) * env_exp(0.8, 0.25, 0.02), 0.02, 0.3)
    return m.out()


def combo_steam(rng, v):
    d = 1.1
    x = highpass(white(d, rng), 2200) * env_pts(d, [(0, 0), (0.15, 1), (d, 0)], 1.4) * (0.6 + 0.4 * smooth_noise(d, 20, rng))
    return x + lowpass(brown(d, rng), 200) * env_bell(d, 0.2) * 0.5


def combo_rot(rng, v):
    d = 1.1
    m = Mix(d)
    m.add(bubbles(d, rng, 50, 80, 280, 0.8, (0.04, 0.1), 0.04), 0, 0.9)
    m.add(lowpass(osc(44, d, "saw") + osc(46.5, d, "saw"), 280) * env_bell(d, 0.3, 1.0), 0, 0.6)
    m.add(squelch(rng, 0.4, 1500, 250, 30), 0, 0.8)
    m.add(growl(rng, 0.8, 70, 45, "o", "u", 0.8, 3.0), 0.1, 0.25)
    return m.out()


def death_flesh(rng, v):
    m = Mix(1.0)
    m.add(thump(rng, 105, 34, 0.5, 0.15, 0.4), 0, 1.0)
    m.add(squelch(rng, 0.42, 2200, 280, 36), 0, 1.1)
    m.add(squelch(rng, 0.15, 2600, 600, 8), rng.uniform(0.12, 0.2), 0.6)
    m.add(growl(rng, rng.uniform(0.45, 0.6), rng.uniform(130, 170), 55, "o", "u", 0.7, 2.5), 0.02, 0.28)
    return sat(m.out() * 1.2, 1.8)


def death_bone(rng, v):
    m = Mix(0.9)
    m.add(crackle(0.9, rng, 110, 1900, 1.2, 0.25) * 3.0, 0, 1.0)
    for _ in range(6):
        m.add(hit_bone(rng, v), rng.exponential(0.12), rng.uniform(0.3, 0.7))
    m.add(thump(rng, 150, 70, 0.3, 0.08), 0.05, 0.6)
    return m.out()


def death_ghost(rng, v):
    d = rng.uniform(0.8, 1.0)
    f = glide(rng.uniform(360, 420), 170, d, 1.2) * (1 + 0.02 * np.sin(2 * np.pi * 5.5 * tvec(d)))
    src = osc(f, d, "saw") + 0.5 * white(d, rng)
    x = formant_sweep(src, "e", "u") * env_pts(d, [(0, 0), (0.08, 1), (d, 0)], 1.2)
    return verb(rng, x, 1.8, 0.5, 2500)


def death_stone(rng, v):
    m = Mix(1.1)
    m.add(rubble(rng, 1.0, 900, 220, 0.3, 1.0), 0, 1.0)
    m.add(thump(rng, 65, 32, 0.6, 0.2), 0, 0.9)
    return m.out()


def death_metal(rng, v):
    m = Mix(1.0)
    for i in range(3):
        m.add(metal(rng, rng.uniform(250, 420), 0.8, 0.35, 7, 0.4), i * rng.uniform(0.08, 0.15), 0.5)
    m.add(rubble(rng, 0.7, 1200, 120, 0.2, 0.3), 0.05, 0.6)
    m.add(death_flesh(rng, v), 0, 0.5)
    return m.out()


def death_elite(rng, v):
    m = Mix(1.6)
    m.add(thump(rng, 55, 24, 1.2, 0.4, 0.3), 0, 1.0)
    m.add(chord(rng, [55.0, 65.4, 82.4], 1.4, "saw", 500, 0.02), 0, 0.5)
    return verb(rng, m.out(), 2.0, 0.35, 2000)


def boss_death(rng, v):
    m = Mix(3.5)
    m.add(growl(rng, 2.4, 95, 38, "a", "u", 0.9, 3.0), 0, 0.8)
    m.add(thump(rng, 50, 20, 3.0, 0.9, 0.3), 0, 1.0)
    m.add(lowpass(brown(3.5, rng), 220) * env_pts(3.5, [(0, 0), (0.1, 1), (3.5, 0)], 1.5), 0, 0.9)
    m.add(rubble(rng, 2.5, 800, 150, 0.8, 0.4), 0.2, 0.6)
    m.add(explosion(rng, 1.5, 25), 0.05, 0.6)
    return verb(rng, sat(m.out(), 1.8), 3.0, 0.4, 1800)


def enemy_swing(rng, v):
    return whoosh(rng, rng.uniform(0.22, 0.28), 330, rng.uniform(1300, 1700), 450, 0.9, 0.45, 1.5, 0.5)


def enemy_bow(rng, v):
    m = Mix(0.4)
    m.add(pluck(rng.uniform(110, 130), 0.35, rng, 0.99, 0.8) * env_exp(0.35, 0.1), 0, 1.0)
    m.add(whoosh(rng, 0.14, 1400, 3000, 2000, 0.6, 0.3), 0.01, 0.3)
    return m.out()


def spit(rng, v):
    m = Mix(0.3)
    m.add(squelch(rng, 0.12, 3000, 800, 6), 0, 0.9)
    m.add(whoosh(rng, 0.18, 1500, 1800, 500, 0.8, 0.2), 0.02, 0.5)
    m.add(bubbles(0.15, rng, 6, 300, 900, 1.5), 0, 0.4)
    return m.out()


def splat(rng, v):
    m = Mix(0.3)
    m.add(squelch(rng, 0.22, 2400, 350, 20), 0, 1.0)
    m.add(thump(rng, 180, 80, 0.1, 0.03), 0, 0.4)
    return m.out()


def fireball(rng, v):
    return fire_roar(rng, 0.55, 350, 1900)


def shadow_bolt(rng, v):
    m = Mix(0.5)
    m.add(el_dark(rng, v)[::-1][:n_of(0.4)], 0, 0.7)
    m.add(whoosh(rng, 0.3, 300, 900, 250, 0.7, 0.3), 0, 0.7)
    return m.out()


def spore(rng, v):
    m = Mix(0.4)
    m.add(bandpass(white(0.3, rng), 1200, 1.0) * env_bell(0.3, 0.15, 1.5), 0, 0.7)
    m.add(bubbles(0.25, rng, 5, 400, 1200, 1.3), 0.02, 0.4)
    return m.out()


def beam(rng, v):
    d = 0.55
    f = glide(170, 380, d, 0.5)
    t = tvec(d)
    x = osc(f * (1 + 0.03 * np.sin(2 * np.pi * 23 * t)), d, "saw")
    x = sweep_bp(x, logcurve(d, [(0, 500), (0.5, 2400), (1, 1200)]), 1.0)
    m = Mix(d)
    m.add(sat(x * env_pts(d, [(0, 0), (0.05, 1), (d * 0.8, 0.8), (d, 0)]) * 2, 2.0), 0, 0.8)
    m.add(squelch(rng, 0.12), 0, 0.4)
    return m.out()


def bite(rng, v):
    m = Mix(0.35)
    m.add(whoosh(rng, 0.1, 600, 1600, 700, 0.8, 0.5), 0, 0.5)
    for i in range(2):
        c = bandpass(white(0.012, rng), 1800, 0.6) * env_exp(0.012, 0.003, 0.0)
        m.add(c * 3, 0.08 + i * 0.03, 0.9)
    m.add(growl(rng, 0.25, 180, 120, "a", "a", 0.9, 3.0), 0.02, 0.4)
    return m.out()


def scream(rng, v):
    d = 0.95
    f = glide(rng.uniform(520, 600), 900, d, 0.6) * (1 + 0.04 * smooth_noise(d, 20, rng))
    src = osc(f, d, "saw") + osc(f * 1.03, d, "saw") + white(d, rng) * 0.6
    x = formant_sweep(src, "a", "i", 0.22) * env_pts(d, [(0, 0), (0.1, 1), (d * 0.7, 0.9), (d, 0)])
    return verb(rng, sat(x * 2, 2.0), 1.4, 0.4)


def void_pull(rng, v):
    d = 1.0
    m = Mix(d)
    m.add(reverse(whoosh(rng, d, 300, 1400, 200, 0.8, 0.2, 1.5)), 0, 0.9)
    m.add(osc(glide(35, 55, d), d) * env_pts(d, [(0, 0), (0.85, 1), (d, 0)]), 0, 0.8)
    return m.out()


def summon(rng, v):
    d = 1.0
    m = Mix(1.4)
    sw = reverse(verb(rng, chord(rng, [73.4, 87.3, 103.8], 0.3, "saw", 700, 0.01), 1.0, 1.0))
    m.add(sw, 0, 0.7)
    m.add(formant(white(d, rng), "o") * env_bell(d, 0.7, 1.2) * 0.8, 0, 0.4)
    m.add(thump(rng, 80, 40, 0.4, 0.12), len(sw) / SR - 0.02, 0.7)
    return m.out()


def spawn_flesh(rng, v):
    m = Mix(0.8)
    m.add(squelch(rng, 0.5, 1800, 250, 40), 0, 1.0)
    m.add(growl(rng, 0.4, 220, 160, "e", "o", 0.8, 2.5), 0.1, 0.25)
    return m.out()


def heal_spell(rng, v):
    m = Mix(1.2)
    m.add(bell(rng, 523.3, 1.2, 0.5), 0, 0.5)
    m.add(bell(rng, 622.3, 1.1, 0.45), 0.12, 0.4)
    m.add(bandpass(white(0.8, rng), 5000, 0.5) * env_bell(0.8, 0.3) * smooth_noise(0.8, 30, rng), 0, 0.15)
    return verb(rng, m.out(), 1.4, 0.4)


def stealth(rng, v):
    d = 0.6
    m = Mix(d)
    m.add(whoosh(rng, d, 1200, 700, 200, 0.8, 0.1, 1.0), 0, 0.8)
    m.add(osc(glide(220, 80, d), d, "tri") * env_exp(d, 0.2) * 0.3, 0, 1.0)
    return verb(rng, m.out(), 1.0, 0.35)


def telegraph(rng, v):
    d = 0.5
    x = osc(55, d) + 0.5 * lowpass(osc(110, d, "saw"), 400) + 0.2 * highpass(white(d, rng), 5000)
    return x * env_pts(d, [(0, 0), (0.35, 1), (d, 0)], 1.4)


def ground_slam(rng, v):
    return slam(rng, v)


def anvil_slam(rng, v):
    m = Mix(1.5)
    m.add(metal(rng, rng.uniform(780, 900), 1.5, 0.9, 10, 0.6), 0, 0.5)
    m.add(slam(rng, v), 0, 1.0)
    return verb(rng, m.out(), 1.4, 0.3)


def dark_burst(rng, v):
    m = Mix(0.9)
    m.add(explosion(rng, 0.6, 30), 0, 0.6)
    m.add(el_dark(rng, v), 0, 0.8)
    m.add(growl(rng, 0.5, 90, 60, "o", "u", 1.0, 3.0), 0, 0.3)
    return verb(rng, m.out(), 1.3, 0.35, 2000)


def dark_slash(rng, v):
    m = Mix(0.6)
    m.add(whoosh(rng, 0.25, 250, 1500, 300, 0.7, 0.5, 1.4), 0, 0.9)
    m.add(el_dark(rng, v), 0, 0.5)
    return m.out()


def root_burst(rng, v):
    m = Mix(0.6)
    m.add(rubble(rng, 0.5, 700, 250, 0.12, 0.8), 0, 0.9)
    m.add(thump(rng, 110, 45, 0.3, 0.08), 0, 0.8)
    m.add(crackle(0.3, rng, 300, 900, 1.0, 0.08) * 2, 0.02, 0.5)
    return m.out()


def lava_fill(rng, v):
    d = 1.4
    m = Mix(d)
    m.add(bubbles(d, rng, 45, 60, 220, 0.9, (0.05, 0.12), 0.05), 0, 1.0)
    m.add(lowpass(brown(d, rng), 180) * env_pts(d, [(0, 0), (0.3, 1), (d, 0)]), 0, 0.8)
    m.add(fire_roar(rng, d, 200, 900), 0, 0.5)
    return m.out()


def gas(rng, v):
    d = 0.9
    return bandpass(white(d, rng), 1600, 1.4) * env_pts(d, [(0, 0), (0.08, 1), (d, 0)], 1.8) * (0.6 + 0.4 * smooth_noise(d, 12, rng))


def void_rift(rng, v):
    d = 1.2
    m = Mix(d)
    m.add(void_pull(rng, v), 0, 0.8)
    m.add(verb(rng, osc(glide(80, 40, 0.6), 0.6, "saw") * env_exp(0.6, 0.2), 1.2, 0.5, 1500), 0.3, 0.5)
    return m.out()


def boss_scream(rng, v):
    return scream(rng, v) * 1.0


def gaze_beam(rng, v):
    d = 1.4
    f = 95 * (1 + 0.05 * np.sin(2 * np.pi * 3 * tvec(d)))
    x = osc(f, d, "saw") + osc(f * 1.5, d, "saw") * 0.5 + osc(f * 0.5, d) * 0.8
    x = sweep_bp(x, logcurve(d, [(0, 300), (0.2, 1800), (1, 900)]), 1.2)
    return verb(rng, sat(x * env_pts(d, [(0, 0), (0.1, 1), (d * 0.8, 0.9), (d, 0)]) * 2, 2.5), 1.0, 0.3)


def eyelid(rng, v):
    m = Mix(1.0)
    m.add(squelch(rng, 0.6, 1500, 200, 40, 1.2), 0, 1.0)
    m.add(growl(rng, 0.9, 80, 55, "o", "u", 0.6, 2.0), 0.05, 0.4)
    return m.out()


def plates_break(rng, v):
    m = Mix(1.2)
    for _ in range(8):
        m.add(metal(rng, rng.uniform(300, 900), 0.6, 0.25, 6, 0.5), rng.exponential(0.12), rng.uniform(0.3, 0.6))
    m.add(slam(rng, v), 0, 0.8)
    return verb(rng, m.out(), 1.2, 0.3)


def nyx_found(rng, v):
    m = Mix(1.5)
    m.add(scream(rng, v)[:n_of(0.5)] * env_exp(0.5, 0.2), 0, 0.5)
    m.add(bell(rng, 207.7, 1.5, 0.8), 0, 0.6)
    return verb(rng, m.out(), 1.8, 0.4)


def torch_light(rng, v):
    m = Mix(0.8)
    m.add(fire_roar(rng, 0.7, 250, 2200), 0, 1.0)
    m.add(thump(rng, 140, 60, 0.2, 0.05), 0, 0.4)
    return m.out()


def roar_morvath(rng, v):
    m = Mix(2.2)
    m.add(growl(rng, 1.8, 120, 70, "a", "o", 0.8, 3.0), 0, 1.0)
    m.add(squelch(rng, 1.0, 1400, 200, 60, 1.2), 0.1, 0.7)
    m.add(thump(rng, 60, 30, 1.0, 0.4), 0, 0.6)
    return verb(rng, m.out(), 2.2, 0.35, 2200)


def roar_mycela(rng, v):
    d = 1.6
    m = Mix(2.2)
    f = glide(460, 300, d, 0.7)
    src = osc(f, d, "saw") + white(d, rng) * 1.2
    m.add(formant_sweep(src, "i", "a") * env_pts(d, [(0, 0), (0.1, 1), (d, 0)]), 0, 0.8)
    m.add(highpass(white(d, rng), 3000) * env_bell(d, 0.3), 0, 0.5)
    m.add(bubbles(d, rng, 30, 100, 400, 0.8, (0.04, 0.1), 0.04), 0, 0.4)
    return verb(rng, sat(m.out() * 1.5, 2.0), 2.0, 0.35)


def roar_kordrak(rng, v):
    m = Mix(2.5)
    m.add(growl(rng, 2.0, 75, 45, "o", "a", 1.0, 4.0), 0, 1.0)
    m.add(metal(rng, 180, 2.0, 1.0, 8, 0.2), 0, 0.3)
    m.add(rubble(rng, 1.5, 700, 120, 0.5, 0.8), 0.1, 0.5)
    m.add(fire_roar(rng, 1.5, 150, 700), 0, 0.4)
    return verb(rng, m.out(), 2.0, 0.3, 1800)


def roar_nyxthar(rng, v):
    d = 2.0
    m = Mix(3.0)
    for i, mul in enumerate([1.0, 1.5, 0.75]):
        f = glide(300 * mul, 150 * mul, d, 1.0) * (1 + 0.03 * np.sin(2 * np.pi * 5 * tvec(d) + i))
        src = osc(f, d, "saw") + white(d, rng) * 0.4
        m.add(formant_sweep(src, "o", "u") * env_pts(d, [(0, 0), (0.3, 1), (d, 0)], 1.2), i * 0.05, 0.5)
    m.add(reverse(verb(rng, osc(55, 0.3) * env_exp(0.3, 0.1), 1.5, 1.0)), 0, 0.4)
    return verb(rng, m.out(), 3.0, 0.5, 2000)


def dash(rng, v):
    m = Mix(0.25)
    m.add(whoosh(rng, 0.18, 700, rng.uniform(2000, 2500), 600, 0.8, 0.35), 0, 1.0)
    m.add(cloth(rng, 0.18), 0, 0.4)
    return m.out()


def player_hurt(rng, v):
    m = Mix(0.35)
    m.add(thump(rng, 140, 60, 0.2, 0.06, 0.3), 0, 0.9)
    m.add(squelch(rng, 0.12), 0, 0.5)
    m.add(growl(rng, 0.2, rng.uniform(140, 170), 110, "u", "o", 0.8, 2.5), 0.01, 0.45)
    return m.out()


def heartbeat(rng, v):
    m = Mix(0.5)
    m.add(lowpass(thump(rng, 62, 40, 0.18, 0.05, 0.0), 220), 0, 1.0)
    m.add(lowpass(thump(rng, 55, 38, 0.18, 0.05, 0.0), 220), 0.22, 0.7)
    return m.out()


def player_death(rng, v):
    m = Mix(3.0)
    m.add(thump(rng, 90, 30, 0.8, 0.25, 0.4), 0, 1.0)
    m.add(squelch(rng, 0.4, 1800, 250, 30), 0, 0.8)
    m.add(growl(rng, 1.4, 130, 60, "a", "u", 0.6, 2.0), 0.05, 0.45)
    m.add(heartbeat(rng, v), 0.9, 0.9)
    m.add(heartbeat(rng, v) * 0.6, 1.8, 0.6)
    m.add(lowpass(chord(rng, [36.7, 43.7, 55.0], 2.5, "saw", 300, 0.8), 400), 0.4, 0.5)
    return verb(rng, m.out(), 2.5, 0.35, 1600)


def potion_drink(rng, v):
    m = Mix(0.8)
    m.add(osc(glide(700, 320, 0.04), 0.04) * env_exp(0.04, 0.012), 0, 0.5)
    for k in range(3):
        m.add(bubbles(0.12, rng, 4, 120, 260, 1.4, (0.04, 0.08), 0.03), 0.1 + k * 0.2, 0.9)
        m.add(lowpass(thump(rng, 120, 80, 0.1, 0.03, 0.0), 400), 0.12 + k * 0.2, 0.5)
    return m.out()


def potion_pickup(rng, v):
    m = Mix(0.4)
    m.add(modal(0.3, [(1850, 0.12, 1.0), (4300, 0.05, 0.4), (2950, 0.08, 0.3)], rng), 0, 0.6)
    m.add(modal(0.3, [(1960, 0.1, 1.0), (4500, 0.04, 0.3)], rng), 0.06, 0.4)
    return m.out()


def weapon_swap(rng, v):
    m = Mix(0.4)
    m.add(sweep_bp(white(0.25, rng), logcurve(0.25, [(0, 2000), (1, 5500)]), 0.5) * env_bell(0.25, 0.6, 1.3) * (0.5 + smooth_noise(0.25, 60, rng)), 0, 0.7)
    m.add(metal(rng, 1300, 0.3, 0.12, 5, 0.2), 0.2, 0.25)
    return m.out()


def level_up(rng, v):
    m = Mix(3.0)
    notes = [110.0, 130.8, 164.8, 220.0, 261.6]
    for i, f in enumerate(notes):
        m.add(bell(rng, f * 2, 2.0, 0.9), i * 0.09, 0.35)
    m.add(chord(rng, [110.0, 138.6, 164.8], 2.4, "saw", 1200, 0.4), 0.1, 0.35)
    m.add(thump(rng, 70, 35, 0.8, 0.3, 0.2), 0, 0.6)
    return verb(rng, m.out(), 2.5, 0.35)


def second_chance(rng, v):
    m = Mix(2.5)
    sw = reverse(verb(rng, thump(rng, 80, 30, 0.5, 0.2, 0.3), 0.6, 1.0))
    m.add(sw, 0, 0.8)
    m.add(chord(rng, [146.8, 174.6, 220.0, 293.7], 1.8, "saw", 1500, 0.5), len(sw) / SR - 0.2, 0.4)
    m.add(bell(rng, 587.3, 2.0, 1.0), len(sw) / SR, 0.4)
    return verb(rng, m.out(), 1.8, 0.3)


def deny(rng, v):
    m = Mix(0.3)
    for i in range(2):
        m.add(lowpass(osc(98, 0.08, "square"), 500) * env_exp(0.08, 0.03, 0.003), i * 0.09, 0.8)
    return m.out()


def shield_rush(rng, v):
    m = Mix(0.8)
    m.add(metal(rng, 620, 0.6, 0.25, 7, 0.3), 0, 0.4)
    m.add(sweep_bp(white(0.2, rng), logcurve(0.2, [(0, 2500), (1, 6000)]), 0.4) * env_exp(0.2, 0.06), 0, 0.5)
    m.add(whoosh(rng, 0.4, 300, 1600, 400, 0.9, 0.35, 1.3, 0.6), 0.05, 0.9)
    m.add(crackle(0.4, rng, 120, 3000, 1.0) * 1.5, 0.05, 0.3)
    return m.out()


def phase(rng, v):
    d = 0.7
    m = Mix(d + 0.5)
    m.add(reverse(whoosh(rng, d, 300, 1300, 200, 0.6, 0.3, 1.3)), 0, 0.8)
    m.add(osc(glide(440, 330, d), d, "tri") * env_bell(d, 0.4) * 0.3, 0, 1.0)
    return verb(rng, m.out(), 1.2, 0.4)


def shadow_step(rng, v):
    m = Mix(0.5)
    m.add(reverse(whoosh(rng, 0.2, 400, 2000, 300, 0.6, 0.3)), 0, 0.8)
    m.add(zap(rng, 0.12, 60, 2500) * 0.5, 0.18, 0.8)
    m.add(whoosh(rng, 0.2, 2000, 600, 200, 0.6, 0.05, 1.0), 0.2, 0.6)
    return m.out()


def back_leap(rng, v):
    m = Mix(0.4)
    m.add(whoosh(rng, 0.25, 500, 2200, 1500, 0.8, 0.5), 0, 0.9)
    m.add(cloth(rng, 0.25, 18), 0, 0.5)
    return m.out()


def arrow_rain(rng, v):
    m = Mix(1.2)
    m.add(bow(rng, v), 0, 0.6)
    for i in range(7):
        m.add(whoosh(rng, 0.35, 4000, 2500, 1500, 0.4, 0.8, 1.0), 0.15 + i * 0.05 + rng.uniform(0, 0.03), 0.35)
    return m.out()


def flight(rng, v):
    d = 0.9
    t = tvec(d)
    m = Mix(1.2)
    m.add(lowpass(white(d, rng), 1500) * np.power(np.sin(2 * np.pi * 5 * t), 4) * env_bell(d, 0.3), 0, 0.8)
    m.add(chord(rng, [220.0, 261.6, 311.1], d, "saw", 1600, 0.4), 0, 0.3)
    return verb(rng, m.out(), 1.2, 0.3)


def storm_cast(rng, v):
    d = 0.7
    m = Mix(d)
    m.add(lowpass(brown(d, rng), 300) * env_pts(d, [(0, 0), (0.6, 1), (d, 0)]), 0, 0.9)
    m.add(crackle(d, rng, 250, 3500, 1.2) * env_pts(d, [(0, 0), (d, 1)]) * 3, 0, 0.5)
    return m.out()


def door_slam(rng, v):
    m = Mix(1.4)
    m.add(metal(rng, rng.uniform(130, 150), 1.2, 0.6, 9, 0.7), 0, 0.6)
    m.add(thump(rng, 95, 38, 0.5, 0.15, 0.5), 0, 1.0)
    m.add(crackle(0.6, rng, 220, 2600, 1.0, 0.15) * 2, 0.01, 0.6)
    return verb(rng, sat(m.out(), 1.5), 1.4, 0.35, 2500)


def door_open(rng, v):
    d = 0.9
    m = Mix(1.5)
    grind = bandpass(white(d, rng), 1100, 0.9) * (0.3 + np.power(smooth_noise(d, 35, rng), 2) * 1.5) * env_pts(d, [(0, 0), (0.1, 1), (d * 0.8, 0.8), (d, 0)])
    m.add(grind, 0, 0.7)
    creak = osc(95 * (1 + 0.2 * smooth_noise(d, 8, rng)), d, "saw")
    m.add(bandpass(creak, 900, 0.7) * env_bell(d, 0.5, 1.0), 0, 0.3)
    m.add(metal(rng, 180, 0.8, 0.35, 7, 0.4), d - 0.05, 0.5)
    return verb(rng, m.out(), 1.2, 0.3)


def wave_start(rng, v):
    m = Mix(2.5)
    m.add(thump(rng, 78, 52, 0.9, 0.35, 0.2) + lowpass(white(0.9, rng), 250) * env_exp(0.9, 0.08) * 0.5, 0, 1.0)
    d = 1.6
    f = 73.4 * (1 + 0.012 * np.sin(2 * np.pi * 5 * tvec(d)))
    horn = sweep_lp(osc(f, d, "saw") + osc(f * 1.005, d, "saw"), logcurve(d, [(0, 300), (0.3, 1000), (1, 350)]), 2.0)
    m.add(formant(horn, "o") * env_pts(d, [(0, 0), (0.25, 1), (d * 0.7, 0.8), (d, 0)]), 0.15, 0.8)
    return verb(rng, m.out(), 2.2, 0.35, 2000)


def room_clear(rng, v):
    m = Mix(3.0)
    m.add(bell(rng, 110.0, 2.5, 1.4), 0, 0.6)
    m.add(bell(rng, 164.8, 2.2, 1.2), 0.08, 0.4)
    return verb(rng, m.out(), 2.0, 0.35)


def chest_open(rng, v):
    d = 0.55
    m = Mix(0.9)
    m.add(highpass(white(0.005, rng), 2500) * 2, 0, 0.6)
    creak = osc(rng.uniform(140, 200) * (1 + 0.3 * smooth_noise(d, 12, rng)), d, "saw")
    m.add(bandpass(creak, 800, 0.6) * env_bell(d, 0.4, 1.0), 0.03, 0.6)
    m.add(thump(rng, 120, 60, 0.25, 0.07), d, 0.7)
    return m.out()


def trap_arm(rng, v):
    m = Mix(1.1)
    for i, at in enumerate([0.0, 0.3, 0.52, 0.68, 0.8]):
        m.add(modal(0.1, [(2400 + i * 150, 0.02, 1.0)], rng), at, 0.6)
        m.add(highpass(white(0.003, rng), 3000), at, 0.6)
    d = 0.9
    m.add(highpass(white(d, rng), 3000) * env_pts(d, [(0, 0), (d, 1)], 2.0), 0, 0.4)
    return m.out()


def coin_pick(rng, v):
    m = Mix(0.4)
    m.add(coin(rng), 0, 1.0)
    m.add(coin(rng) * 0.5, rng.uniform(0.02, 0.05), 1.0)
    return m.out()


def item_pickup(rng, v):
    m = Mix(0.5)
    m.add(metal(rng, rng.uniform(650, 760), 0.4, 0.14, 6, 0.3), 0, 0.5)
    m.add(lowpass(white(0.1, rng), 900) * env_exp(0.1, 0.03), 0, 0.5)
    m.add(cloth(rng, 0.15), 0.02, 0.4)
    return m.out()


def loot_common(rng, v):
    return lowpass(thump(rng, 180, 90, 0.15, 0.04, 0.2), 1200)


def loot_rare(rng, v):
    m = Mix(1.2).add(bell(rng, 880.0, 1.2, 0.6), 0, 0.6).add(bandpass(white(0.6, rng), 6000, 0.5) * env_exp(0.6, 0.2), 0, 0.1)
    return verb(rng, m.out(), 1.2, 0.3)


def loot_epic(rng, v):
    m = Mix(1.8)
    m.add(bell(rng, 659.3, 1.5, 0.8), 0, 0.5)
    m.add(bell(rng, 784.0, 1.5, 0.8), 0.12, 0.5)
    m.add(chord(rng, [329.6, 392.0, 493.9], 1.2, "saw", 2000, 0.3), 0, 0.15)
    return verb(rng, m.out(), 1.6, 0.35)


def loot_legendary(rng, v):
    m = Mix(3.5)
    m.add(thump(rng, 60, 28, 1.0, 0.4, 0.3), 0, 0.8)
    for i, f in enumerate([220.0, 261.6, 329.6, 440.0, 523.3]):
        m.add(bell(rng, f * 2, 2.2, 1.0), 0.05 + i * 0.1, 0.35)
    m.add(chord(rng, [110.0, 164.8, 220.0, 277.2], 2.6, "saw", 1500, 0.6), 0.1, 0.4)
    return verb(rng, m.out(), 3.0, 0.4)


def wall_crack(rng, v):
    m = Mix(0.5)
    m.add(crack(rng, 0.06, 1400, 700, 0.02, 1.0), 0, 1.0)
    m.add(thump(rng, 150, 80, 0.2, 0.05), 0, 0.7)
    m.add(rubble(rng, 0.4, 1100, 80, 0.1, 0.2), 0.02, 0.5)
    return m.out()


def wall_break(rng, v):
    m = Mix(2.0)
    m.add(rubble(rng, 1.6, 900, 260, 0.45, 1.0), 0, 1.0)
    m.add(explosion(rng, 1.0, 28), 0, 0.6)
    return verb(rng, m.out(), 1.6, 0.3, 2200)


def secret_found(rng, v):
    m = Mix(3.0)
    sw = reverse(verb(rng, highpass(white(0.3, rng), 3000) * env_exp(0.3, 0.1), 0.8, 1.0))
    m.add(sw, 0, 0.4)
    t0 = len(sw) / SR - 0.05
    for i, f in enumerate([220.0, 261.6, 311.1]):
        m.add(bell(rng, f * 2, 2.2, 1.0), t0 + i * 0.07, 0.35)
    return verb(rng, m.out(), 2.4, 0.35)


def stairs(rng, v):
    m = Mix(3.0)
    for i in range(5):
        step = Mix(0.12).add(thump(rng, 160, 80, 0.12, 0.03, 0.4)).add(white(0.05, rng) * env_exp(0.05, 0.01), 0, 0.3).out()
        m.add(lowpass(step, 1500), i * 0.3, 0.8 * (0.8 ** i))
    m.add(whoosh(rng, 1.6, 200, 600, 120, 1.0, 0.5, 1.0, 0.5), 0.3, 0.6)
    return verb(rng, m.out(), 2.6, 0.45, 1800)


def floor_enter(rng, v):
    m = Mix(3.5)
    m.add(thump(rng, 50, 24, 2.0, 0.7, 0.2), 0, 1.0)
    m.add(lowpass(brown(3.0, rng), 160) * env_pts(3.0, [(0, 0), (0.2, 1), (3.0, 0)], 1.4), 0, 0.8)
    return verb(rng, m.out(), 3.0, 0.4, 1500)


def buy(rng, v):
    m = Mix(0.6)
    for _ in range(9):
        m.add(coin(rng), rng.uniform(0, 0.25), rng.uniform(0.3, 0.7))
    return m.out()


def sell(rng, v):
    m = Mix(0.5)
    for i in range(3):
        m.add(coin(rng), i * rng.uniform(0.05, 0.09), 0.6)
    return m.out()


def anvil(rng, v):
    m = Mix(2.0)
    m.add(metal(rng, rng.uniform(820, 900), 2.0, 1.1, 10, 0.8), 0, 0.7)
    m.add(thump(rng, 220, 110, 0.1, 0.03), 0, 0.5)
    return verb(rng, m.out(), 1.2, 0.25)


def reroll(rng, v):
    m = Mix(1.2)
    m.add(cast(rng, v), 0, 0.7)
    m.add(bell(rng, 740.0, 1.0, 0.5), 0.25, 0.4)
    return m.out()


def ui_click(rng, v):
    m = Mix(0.08)
    m.add(osc(glide(1500 + v * 200, 700, 0.03), 0.03) * env_exp(0.03, 0.008, 0.0005), 0, 0.6)
    m.add(lowpass(white(0.01, rng), 3000) * env_exp(0.01, 0.002, 0.0), 0, 0.5)
    return m.out()


def ui_hover(rng, v):
    return osc(2600, 0.02) * env_exp(0.02, 0.004, 0.0005) * 0.5


def ui_open(rng, v):
    m = Mix(0.4)
    m.add(lowpass(white(0.25, rng), 1400) * env_bell(0.25, 0.4, 1.4), 0, 0.8)
    m.add(thump(rng, 120, 70, 0.15, 0.04, 0.1), 0.12, 0.5)
    return m.out()


def ui_close(rng, v):
    m = Mix(0.3)
    m.add(lowpass(white(0.18, rng), 1100) * env_bell(0.18, 0.2, 1.4), 0, 0.8)
    m.add(thump(rng, 100, 60, 0.12, 0.03, 0.1), 0.05, 0.5)
    return m.out()


def ui_drag(rng, v):
    return Mix(0.2).add(metal(rng, 1100, 0.2, 0.06, 4, 0.2), 0, 0.5).add(cloth(rng, 0.1), 0, 0.5).out()


def ui_drop(rng, v):
    m = Mix(0.3)
    m.add(lowpass(thump(rng, 170, 90, 0.12, 0.03, 0.2), 1500), 0, 0.8)
    m.add(metal(rng, 800, 0.25, 0.08, 4, 0.1), 0, 0.3)
    return m.out()


def reward_open(rng, v):
    m = Mix(2.5)
    sw = reverse(verb(rng, chord(rng, [110.0, 130.8, 164.8], 0.25, "saw", 1200, 0.02), 0.5, 1.0))
    m.add(sw, 0, 0.5)
    m.add(bell(rng, 440.0, 1.8, 1.0), len(sw) / SR - 0.05, 0.4)
    return verb(rng, m.out(), 1.5, 0.3)


def reward_pick(rng, v):
    m = Mix(1.5)
    m.add(thump(rng, 90, 40, 0.5, 0.15, 0.3), 0, 0.8)
    m.add(bell(rng, 329.6, 1.4, 0.8), 0, 0.45)
    m.add(metal(rng, 500, 0.6, 0.3, 6, 0.3), 0, 0.2)
    return verb(rng, m.out(), 1.3, 0.3)


def victory(rng, v):
    m = Mix(6.0)
    m.add(thump(rng, 55, 25, 1.5, 0.6, 0.3), 0, 1.0)
    m.add(chord(rng, [110.0, 130.8, 164.8], 1.4, "saw", 1400, 0.3), 0, 0.4)
    m.add(chord(rng, [98.0, 123.5, 146.8], 1.2, "saw", 1400, 0.3), 1.2, 0.4)
    m.add(chord(rng, [110.0, 138.6, 164.8, 220.0], 3.0, "saw", 1800, 0.4), 2.3, 0.5)
    for i, f in enumerate([440.0, 554.4, 659.3, 880.0]):
        m.add(bell(rng, f, 2.5, 1.2), 2.3 + i * 0.12, 0.3)
    m.add(thump(rng, 50, 25, 1.5, 0.6, 0.2), 2.3, 0.8)
    return verb(rng, m.out(), 3.0, 0.35)


def defeat(rng, v):
    m = Mix(6.0)
    for i, f in enumerate([110.0, 103.8, 98.0, 82.4]):
        m.add(bell(rng, f, 3.0, 1.8), i * 0.9, 0.45)
    m.add(chord(rng, [55.0, 65.4, 77.8], 4.5, "saw", 500, 1.0), 0.2, 0.5)
    m.add(lowpass(brown(4.5, rng), 150) * env_bell(4.5, 0.3, 1.2), 0, 0.6)
    return verb(rng, m.out(), 3.5, 0.4, 1600)


# id: (fonksiyon, varyant sayısı, hedef gürlük dB [en gür 100 ms'nin RMS'i])
SOUNDS = {
    # vuruşlar
    "hit_flesh": (hit_flesh, 4, -13), "hit_heavy": (hit_heavy, 3, -11), "hit_crit": (hit_crit, 3, -11),
    "hit_bone": (hit_bone, 4, -14), "hit_stone": (hit_stone, 3, -13), "hit_metal": (hit_metal, 3, -14),
    "hit_ghost": (hit_ghost, 3, -15), "hit_block": (hit_block, 3, -13), "hit_immune": (hit_immune, 2, -16),
    "execute": (execute, 1, -10),
    # oyuncu saldırıları
    "swing_blade": (swing_blade, 4, -17), "swing_heavy": (swing_heavy, 3, -16), "punch": (punch, 4, -18),
    "thrust": (thrust, 3, -17), "stab": (stab, 2, -16), "spin": (spin, 2, -15), "throw_whirl": (throw_whirl, 2, -16),
    "slam": (slam, 2, -12), "bow": (bow, 4, -16), "bow_heavy": (bow_heavy, 2, -14), "crossbow": (crossbow, 3, -15),
    "crossbow_fan": (crossbow_fan, 2, -14), "cast": (cast, 4, -17), "cast_multi": (cast_multi, 2, -16),
    "orb_cast": (orb_cast, 2, -15), "rune": (rune, 3, -16), "rune_arm": (rune_arm, 2, -16),
    "rune_blast": (rune_blast, 3, -12), "explosion_small": (explosion_small, 3, -12),
    "explosion_fire": (explosion_fire, 2, -12), "flesh_burst": (flesh_burst, 2, -12),
    "arrow_impact": (arrow_impact, 3, -17), "storm_pulse": (storm_pulse, 3, -14),
    # elementler ve kombolar
    "el_fire": (el_fire, 3, -18), "el_water": (el_water, 3, -18), "el_lightning": (el_lightning, 3, -18),
    "el_poison": (el_poison, 3, -19), "el_ice": (el_ice, 3, -18), "el_dark": (el_dark, 3, -18),
    "freeze": (freeze, 1, -15),
    "combo_electroshock": (combo_electroshock, 1, -11), "combo_melt": (combo_melt, 1, -11),
    "combo_freeze": (combo_freeze, 1, -12), "combo_shatter": (combo_shatter, 1, -11),
    "combo_poison_burst": (combo_poison_burst, 1, -11), "combo_steam": (combo_steam, 1, -14),
    "combo_rot": (combo_rot, 1, -13),
    # ölümler
    "death_flesh": (death_flesh, 4, -12), "death_bone": (death_bone, 3, -13), "death_ghost": (death_ghost, 3, -14),
    "death_stone": (death_stone, 2, -12), "death_metal": (death_metal, 2, -12), "death_elite": (death_elite, 2, -12),
    "boss_death": (boss_death, 1, -9),
    # düşman saldırıları ve yetenekleri
    "enemy_swing": (enemy_swing, 3, -17), "enemy_bow": (enemy_bow, 3, -17), "spit": (spit, 3, -16),
    "splat": (splat, 3, -16), "fireball": (fireball, 2, -16), "shadow_bolt": (shadow_bolt, 2, -16),
    "spore": (spore, 2, -18), "beam": (beam, 2, -15), "bite": (bite, 3, -15), "scream": (scream, 2, -13),
    "void_pull": (void_pull, 2, -14), "summon": (summon, 2, -14), "spawn_flesh": (spawn_flesh, 2, -15),
    "heal_spell": (heal_spell, 2, -16), "stealth": (stealth, 2, -16), "ground_slam": (ground_slam, 2, -12),
    # boss'lar
    "telegraph": (telegraph, 2, -20), "anvil_slam": (anvil_slam, 2, -10), "dark_burst": (dark_burst, 2, -12),
    "dark_slash": (dark_slash, 2, -14), "root_burst": (root_burst, 2, -13), "lava_fill": (lava_fill, 1, -14),
    "gas": (gas, 2, -17), "void_rift": (void_rift, 1, -14), "boss_scream": (boss_scream, 1, -11),
    "gaze_beam": (gaze_beam, 1, -13), "eyelid": (eyelid, 1, -12), "plates_break": (plates_break, 1, -10),
    "nyx_found": (nyx_found, 1, -12), "torch_light": (torch_light, 1, -15),
    "roar_morvath": (roar_morvath, 1, -10), "roar_mycela": (roar_mycela, 1, -10),
    "roar_kordrak": (roar_kordrak, 1, -10), "roar_nyxthar": (roar_nyxthar, 1, -10),
    # oyuncu
    "dash": (dash, 3, -18), "player_hurt": (player_hurt, 3, -13), "heartbeat": (heartbeat, 1, -14),
    "player_death": (player_death, 1, -10), "potion_drink": (potion_drink, 2, -15),
    "potion_pickup": (potion_pickup, 1, -18), "weapon_swap": (weapon_swap, 3, -19), "level_up": (level_up, 1, -12),
    "second_chance": (second_chance, 1, -12), "deny": (deny, 2, -20),
    "shield_rush": (shield_rush, 1, -14), "ground_slam_big": (ground_slam_big, 1, -10), "phase": (phase, 1, -16),
    "shadow_step": (shadow_step, 1, -15), "back_leap": (back_leap, 1, -17), "arrow_rain": (arrow_rain, 1, -15),
    "flight": (flight, 1, -16), "storm_cast": (storm_cast, 1, -15),
    # dünya
    "door_slam": (door_slam, 2, -12), "door_open": (door_open, 1, -15), "wave_start": (wave_start, 2, -13),
    "room_clear": (room_clear, 1, -15), "chest_open": (chest_open, 2, -15), "trap_arm": (trap_arm, 1, -15),
    "coin": (coin_pick, 4, -20), "item_pickup": (item_pickup, 2, -16), "loot_common": (loot_common, 1, -18),
    "loot_rare": (loot_rare, 1, -17), "loot_epic": (loot_epic, 1, -15), "loot_legendary": (loot_legendary, 1, -12),
    "wall_crack": (wall_crack, 3, -14), "wall_break": (wall_break, 1, -11), "secret_found": (secret_found, 1, -14),
    "stairs": (stairs, 1, -14), "floor_enter": (floor_enter, 1, -12), "buy": (buy, 2, -17), "sell": (sell, 1, -17),
    "anvil": (anvil, 2, -14), "reroll": (reroll, 1, -16),
    # arayüz ve müzik vurguları
    "ui_click": (ui_click, 2, -22), "ui_hover": (ui_hover, 1, -30), "ui_open": (ui_open, 1, -20),
    "ui_close": (ui_close, 1, -21), "ui_drag": (ui_drag, 1, -22), "ui_drop": (ui_drop, 1, -20),
    "reward_open": (reward_open, 1, -15), "reward_pick": (reward_pick, 1, -14),
    "victory": (victory, 1, -11), "defeat": (defeat, 1, -12),
}
