"""Müzik (Aşama 9) — kat başına ambiyans döngüsü ve boss müziği, numpy ile sentez.

Görsel yönle aynı: karanlık, kanlı, vahşi. Ambiyanslar ritimsiz, uğultulu ve rahatsız edici (uyumsuz aralıklar,
nabız, damlalar, uzak metal); boss müzikleri savaş davulları, bozuk bas ve uyumsuz akorlarla.
Her parça dikişsiz döngüdür: kuyruk (yankı, uzayan notalar) parçanın başına sarılır.
TRACKS = {id: (fn, hedef_gürlük_dB)}; fn(rng) → (n, 2) stereo dizi.
"""

from __future__ import annotations

import numpy as np

from dsp import (Mix, SR, bandpass, brown, bubbles, convolve, crackle, env_bell, env_exp, env_pts, formant, glide,
                 highpass, lowpass, modal, metal_modes, n_of, osc, pink, reverb_ir, reverse, sat, smooth_noise,
                 supersaw, sweep_bp, sweep_lp, tvec, white)
import sfx


def mtof(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


class Song:
    """Zaman çizelgesi: kuru ve yankı (send) stereo yollar; render() döngüyü sarar."""

    def __init__(self, length: float, rng, rt60: float = 3.0, damp: float = 2500.0, tail: float = 6.0):
        self.length = length
        self.rng = rng
        self.rt60 = rt60
        self.damp = damp
        self.dry = Mix(length + tail, 2)
        self.wet = Mix(length + tail, 2)

    def add(self, x, t: float, gain: float = 1.0, pan: float = 0.0, rev: float = 0.3) -> None:
        t = t % self.length
        self.dry.add(x, t, gain, pan)
        if rev > 0:
            self.wet.add(x, t, gain * rev, pan)

    def add_stereo(self, left, right, t: float, gain: float = 1.0, rev: float = 0.3) -> None:
        st = np.stack([left, right], axis=1)
        self.dry.add(st, t % self.length, gain)
        if rev > 0:
            self.wet.add(st, t % self.length, gain * rev)

    def bed(self, x, gain: float = 1.0, pan: float = 0.0, rev: float = 0.2) -> None:
        """Sürekli katman (uğultu, gürültü yatağı): döngü noktasında çapraz geçişle dikişsiz, tam parça boyu."""
        self.add(seamless(x, self.length), 0.0, gain, pan, rev)

    def bed_stereo(self, left, right, gain: float = 1.0, rev: float = 0.2) -> None:
        self.add_stereo(seamless(left, self.length), seamless(right, self.length), 0.0, gain, rev)

    def render(self) -> np.ndarray:
        dry = self.dry.out()
        wet = self.wet.out()
        out = np.zeros((max(len(dry), len(wet)) + n_of(self.rt60 * 1.2), 2))
        out[:len(dry)] += dry
        for ch in range(2):
            ir = reverb_ir(self.rt60, self.rng, self.damp, 0.02 + ch * 0.007)
            w = convolve(wet[:, ch], ir)
            m = min(len(w), len(out))
            out[:m, ch] += w[:m]
        n = n_of(self.length)
        loop = out[:n].copy()
        pos = n
        while pos < len(out):
            seg = out[pos:pos + n]
            loop[:len(seg)] += seg
            pos += n
        return loop


def seamless(x, length: float, xf: float = 2.0) -> np.ndarray:
    """length sn'lik döngü: sondaki xf sn, baştakiyle eşit güçte çapraz geçer (x en az length + xf uzun olmalı)."""
    n, k = n_of(length), n_of(xf)
    x = np.asarray(x, float)
    out = x[:n].copy()
    a = np.linspace(0.0, 1.0, k)
    out[:k] = x[:k] * np.sin(a * np.pi / 2) + x[n:n + k] * np.cos(a * np.pi / 2)
    return out


def stereo_noise(d, rng, kind="brown"):
    f = brown if kind == "brown" else pink
    return f(d, rng), f(d, rng)


def drone(f: float, d: float, rng, lp: float = 180.0, lfo: float = 0.05) -> np.ndarray:
    t = tvec(d)
    x = osc(f, d) + 0.5 * osc(f * 1.003, d, "saw") + 0.3 * osc(f * 2.001, d, "saw")
    cut = lp * (1.0 + 0.6 * np.sin(2 * np.pi * lfo * t + rng.uniform(0, 6.28)))
    return sweep_lp(x, cut, 2.0)


def pad(freqs, d: float, rng, lp: float = 800.0, att: float = 2.0, rel: float = 2.5, voices: int = 4) -> np.ndarray:
    x = np.zeros(n_of(d))
    for f in freqs:
        x += supersaw(f, d, rng, voices, 0.01)
    x = lowpass(x, lp, 2.0) / max(len(freqs), 1)
    return x * env_pts(d, [(0, 0), (att, 1), (max(d - rel, att), 1), (d, 0)], 1.2)


def choir(freqs, d: float, rng, vowel: str = "o", att: float = 2.5, rel: float = 3.0) -> np.ndarray:
    x = np.zeros(n_of(d))
    t = tvec(d)
    for f in freqs:
        for k in range(3):
            vib = 1.0 + 0.006 * np.sin(2 * np.pi * rng.uniform(4.5, 5.5) * t + rng.uniform(0, 6.28))
            x += osc(f * vib * (1 + (k - 1) * 0.004), d, "saw", rng.uniform(0, 6.28))
    x = formant(x, vowel, 0.2) / max(len(freqs), 1)
    return lowpass(x, 3500) * env_pts(d, [(0, 0), (att, 1), (max(d - rel, att), 1), (d, 0)], 1.3)


def kick(rng, f0=120.0, f1=38.0, d=0.5, drive=2.0):
    return sat(sfx.thump(rng, f0, f1, d, d * 0.35, 0.5) * 1.3, drive)


def tom(rng, f=90.0, d=0.6):
    m = Mix(d)
    m.add(osc(glide(f * 1.7, f, d, 0.25), d) * env_exp(d, d * 0.35, 0.002), 0, 1.0)
    m.add(bandpass(white(0.15, rng), f * 4, 1.0) * env_exp(0.15, 0.04), 0, 0.3)
    return sat(m.out() * 1.2, 1.5)


def hat(rng, d=0.06, fc=7000.0):
    return highpass(white(d, rng), fc) * env_exp(d, d * 0.25, 0.0005)


def snare(rng, d=0.3):
    m = Mix(d)
    m.add(bandpass(white(d, rng), 1800, 1.3) * env_exp(d, 0.08, 0.001), 0, 1.0)
    m.add(osc(glide(220, 160, d), d) * env_exp(d, 0.05), 0, 0.6)
    return m.out()


def bass(f: float, d: float, rng, lp: float = 500.0, drive: float = 3.0) -> np.ndarray:
    x = osc(f, d, "saw") + osc(f * 0.5, d, "square") * 0.6 + osc(f * 1.004, d, "saw") * 0.5
    x = sweep_lp(x, lp * (0.4 + 1.6 * env_exp(d, 0.08, 0.002)), 2.0)
    return sat(x * env_pts(d, [(0, 0), (0.005, 1), (d * 0.8, 0.8), (d, 0)]) * 1.5, drive)


def stab(freqs, d: float, rng, lp: float = 1400.0) -> np.ndarray:
    x = np.zeros(n_of(d))
    for f in freqs:
        x += supersaw(f, d, rng, 5, 0.014)
    x = sweep_lp(x, lp * (0.3 + env_exp(d, 0.25, 0.01)), 2.0) / len(freqs)
    return sat(x * env_exp(d, d * 0.5, 0.01) * 2, 1.8)


def drip(rng):
    f = rng.uniform(900, 2200)
    d = 0.08
    return osc(glide(f, f * 1.8, d, 0.5), d) * env_exp(d, 0.02, 0.001)


# --- kat ambiyansları ---

def floor_1(rng):
    """Damarlı Mağara: derin uğultu, et içinden gelen nabız, damlalar, uyumsuz yükselen tınılar, uzak inilti."""
    L = 48.0
    s = Song(L, rng, 3.5, 2200)
    s.bed(drone(mtof(26), L + 4, rng, 150, 1 / 24), 0.55, -0.2, 0.2)
    s.bed(drone(mtof(33), L + 4, rng, 120, 1 / 16), 0.25, 0.3, 0.2)
    wl, wr = stereo_noise(L + 4, rng)
    s.bed_stereo(bandpass(wl, 280, 1.2) * (0.5 + smooth_noise(L + 4, 0.2, rng)),
                 bandpass(wr, 320, 1.2) * (0.5 + smooth_noise(L + 4, 0.2, rng)), 0.35, 0.3)
    beat = L / 40.0
    for i in range(40):
        hb = lowpass(sfx.heartbeat(rng, 0), 180)
        s.add(hb, i * beat, 0.5 + 0.15 * np.sin(i / 40 * 2 * np.pi), 0.0, 0.2)
    for _ in range(26):
        s.add(drip(rng), rng.uniform(0, L), rng.uniform(0.05, 0.14), rng.uniform(-0.9, 0.9), 0.8)
    for k, t0 in enumerate([4.0, 20.0, 36.0]):
        d = 9.0
        pair = [mtof(62 + (k % 2)), mtof(63 + (k % 2))]
        x = np.zeros(n_of(d))
        for f in pair:
            x += osc(f * (1 + 0.004 * np.sin(2 * np.pi * 0.3 * tvec(d))), d, "tri")
        s.add(lowpass(x, 1800) * env_pts(d, [(0, 0), (5.0, 1), (d, 0)], 1.5), t0, 0.07, rng.uniform(-0.6, 0.6), 0.9)
    for t0 in [12.0, 31.0, 44.0]:
        g = lowpass(sfx.growl(rng, 3.0, rng.uniform(60, 75), 45, "o", "u", 0.8, 2.0), 500)
        s.add(g, t0, 0.12, rng.uniform(-0.7, 0.7), 1.0)
    for _ in range(6):
        s.add(lowpass(sfx.squelch(rng, 0.4, 900, 200, 20), 1200), rng.uniform(0, L), 0.12, rng.uniform(-0.8, 0.8), 0.6)
    return s.render()


def floor_2(rng):
    """Mantar Mağaraları: hastalıklı akortsuz pad, kabarcıklar, böcek tıkırtıları, sporlar, bozuk müzik kutusu."""
    L = 48.0
    s = Song(L, rng, 3.0, 3000)
    s.bed(drone(mtof(28), L + 4, rng, 160, 1 / 12), 0.45, 0.0, 0.2)
    chords = [[40, 47, 53], [40, 46, 52], [41, 47, 53], [40, 47, 52]]
    for i, ch in enumerate(chords):
        s.add(pad([mtof(n) for n in ch], 16.0, rng, 700, 3.5, 4.0), i * 12.0, 0.22, (-0.3, 0.3)[i % 2], 0.5)
    for _ in range(18):
        s.add(bubbles(1.2, rng, 8, 150, 500, 1.4, (0.03, 0.08), 0.03), rng.uniform(0, L), 0.1, rng.uniform(-0.8, 0.8), 0.5)
    for _ in range(20):
        s.add(drip(rng), rng.uniform(0, L), 0.09, rng.uniform(-0.9, 0.9), 0.8)
    for _ in range(10):
        d = rng.uniform(0.3, 0.8)
        ch = crackle(d, rng, 160, 5500, 0.8) * env_bell(d, 0.5)
        s.add(ch, rng.uniform(0, L), 0.25, rng.uniform(-1, 1), 0.3)
    for _ in range(40):
        f = rng.uniform(2500, 6000)
        s.add(osc(f, 0.25) * env_exp(0.25, 0.06), rng.uniform(0, L), 0.03, rng.uniform(-1, 1), 1.0)
    motif = [64, 65, 64, 60, 59, 60, 64, 63]
    for rep, t0 in enumerate([6.0, 30.0]):
        for i, n in enumerate(motif):
            b = sfx.bell(rng, mtof(n) * (1 + rng.uniform(-0.006, 0.006)), 2.0, 0.8)
            s.add(lowpass(b, 3000), t0 + i * 0.55, 0.08, 0.4 - 0.1 * i, 0.8)
    return s.render()


def floor_3(rng):
    """Kül Dökümhanesi: gürleyen ocak, uzakta ritmik örs, ateş çıtırtısı, triton uğultusu, buhar, zincir."""
    L = 48.0
    s = Song(L, rng, 3.2, 2000)
    rl, rr = stereo_noise(L + 4, rng)
    s.bed_stereo(lowpass(rl, 150) * 0.9, lowpass(rr, 150) * 0.9, 0.5, 0.1)
    s.bed(drone(mtof(24), L + 4, rng, 130, 1 / 16), 0.4, -0.2, 0.2)
    s.bed(drone(mtof(30), L + 4, rng, 110, 1 / 20), 0.22, 0.3, 0.2)
    cl = crackle(L + 4, rng, 40, 2800, 1.0)
    cr = crackle(L + 4, rng, 40, 2800, 1.0)
    s.bed_stereo(cl, cr, 0.35, 0.2)
    beat = 1.0
    pattern = [0.0, 1.5, 2.0]
    for bar in range(12):
        for p in pattern:
            if bar % 4 == 3 and p == 2.0:
                continue
            h = lowpass(sfx.metal(rng, rng.uniform(760, 820), 1.5, 0.8, 9, 0.5), 2500)
            s.add(h, (bar * 4 + p) * beat, 0.16 if p == 0 else 0.1, -0.5, 1.4)
            s.add(lowpass(sfx.thump(rng, 120, 60, 0.3, 0.08), 400), (bar * 4 + p) * beat, 0.15, -0.5, 0.8)
    for t0 in [7.0, 23.0, 39.0]:
        s.add(sfx.combo_steam(rng, 0), t0, 0.12, rng.uniform(-0.8, 0.8), 0.5)
    for t0 in [15.0, 34.0]:
        d = 1.5
        chain = crackle(d, rng, 60, 2200, 1.0, 0.6) * 2 + sfx.metal(rng, 500, d, 0.2, 6, 0.1) * 0.05
        s.add(chain, t0, 0.2, rng.uniform(-0.8, 0.8), 1.0)
    return s.render()


def floor_4(rng):
    """Boşluk: dipsiz alt ses, ağır koro, ters yükselen tınılar, fısıltılar, seyrek çan."""
    L = 48.0
    s = Song(L, rng, 5.0, 2500)
    s.bed(osc(mtof(23), L + 4) * 0.8 + lowpass(osc(mtof(35), L + 4, "saw"), 120) * 0.3, 0.5, 0.0, 0.1)
    prog = [[47, 50, 54, 57], [43, 47, 50, 54], [48, 52, 55, 59], [46, 49, 54, 58]]
    for i, ch in enumerate(prog):
        s.add(choir([mtof(n) for n in ch], 15.0, rng, "o" if i % 2 == 0 else "u", 4.0, 4.0), i * 12.0, 0.2,
              (-0.25, 0.25)[i % 2], 0.8)
    for t0 in [3.0, 15.0, 27.0, 39.0]:
        b = sfx.bell(rng, mtof(rng.choice([59, 62, 66])), 2.0, 1.2)
        rv = reverse(convolve(b, reverb_ir(3.0, rng, 2000)))
        s.add(rv / (np.max(np.abs(rv)) + 1e-9), t0, 0.12, rng.uniform(-0.8, 0.8), 0.3)
    for _ in range(12):
        d = rng.uniform(1.0, 2.2)
        w = formant(white(d, rng), rng.choice(["a", "e", "i", "o"]), 0.25) * env_bell(d, 0.4, 1.3)
        w *= 0.5 + smooth_noise(d, 9, rng)
        s.add(highpass(w, 500), rng.uniform(0, L), 0.08, rng.uniform(-1, 1), 0.6)
    for t0 in [9.0, 33.0]:
        s.add(sfx.bell(rng, mtof(35), 6.0, 3.0), t0, 0.18, rng.uniform(-0.4, 0.4), 1.2)
    return s.render()


# --- boss müzikleri ---

def boss_morvath(rng):
    """100 bpm, D frig: kalp atışı davulu, bozuk bas, uyumsuz (azaltılmış) yaylı vuruşlar, üstte inleyen koro."""
    bpm = 100.0
    q = 60.0 / bpm
    bars = 16
    L = bars * 4 * q
    s = Song(L, rng, 2.2, 3000)
    riff = [38, 38, 39, 38, 41, 39, 38, 36]
    for bar in range(bars):
        t = bar * 4 * q
        for b in (0, 2):
            s.add(kick(rng, 110, 36, 0.5), t + b * q, 0.8, 0, 0.1)
            s.add(kick(rng, 90, 34, 0.4), t + b * q + q * 0.3, 0.55, 0, 0.1)
        s.add(snare(rng), t + q, 0.35, 0.1, 0.4)
        s.add(snare(rng), t + 3 * q, 0.4, -0.1, 0.4)
        for e in range(8):
            s.add(hat(rng), t + e * q / 2, 0.1 if e % 2 else 0.16, 0.4, 0.1)
        for e, n in enumerate(riff):
            s.add(bass(mtof(n), q / 2 * 0.95, rng, 450, 3.5), t + e * q / 2, 0.32, 0.0, 0.05)
        if bar % 2 == 0:
            ch = [[50, 53, 56], [51, 54, 57]][(bar // 2) % 2]
            s.add(stab([mtof(n) for n in ch], q * 1.5, rng), t, 0.3, -0.3, 0.4)
        if bar % 4 == 3:
            for k in range(4):
                s.add(tom(rng, [110, 95, 82, 70][k]), t + 2 * q + k * q / 2, 0.45, (-0.6, -0.2, 0.2, 0.6)[k], 0.3)
    for i in range(4):
        s.add(choir([mtof(n) for n in [62, 65, 68]], 4 * 4 * q, rng, "a", 1.5, 2.0), i * 16 * q, 0.12, 0.0, 0.8)
    return s.render()


def boss_mycela(rng):
    """6/8, 120 bpm (sekizlik 0,25 sn), E armonik minör: yalpalayan arpej, kabile tomları, hışırtılı çıngırak."""
    e8 = 0.25
    bars = 24
    L = bars * 6 * e8
    s = Song(L, rng, 2.0, 3500)
    arps = [[52, 55, 59, 60, 59, 55], [52, 56, 59, 63, 59, 56], [53, 57, 60, 64, 60, 57], [51, 54, 57, 60, 57, 54]]
    basses = [28, 28, 29, 27]
    for bar in range(bars):
        t = bar * 6 * e8
        s.add(tom(rng, 70, 0.7), t, 0.7, -0.1, 0.2)
        s.add(tom(rng, 95, 0.5), t + 3 * e8, 0.5, 0.3, 0.3)
        s.add(tom(rng, 120, 0.4), t + 5 * e8, 0.35, -0.4, 0.3)
        if bar % 2 == 1:
            s.add(kick(rng, 100, 34, 0.5), t + 4 * e8, 0.5, 0, 0.1)
        for k in range(6):
            sh = bandpass(white(0.1, rng), 6000, 0.8) * env_exp(0.1, 0.03)
            s.add(sh, t + k * e8, 0.18 if k % 3 == 0 else 0.1, 0.5, 0.1)
        arp = arps[(bar // 2) % 4]
        for k, n in enumerate(arp):
            d = e8 * 0.9
            f = mtof(n) * (1 + 0.01 * np.sin(2 * np.pi * 6 * tvec(d)))
            x = lowpass(osc(f, d, "square") + 0.5 * osc(f * 1.007, d, "saw"), 1800) * env_exp(d, 0.12, 0.003)
            s.add(x, t + k * e8, 0.1, (-0.5, 0.5)[k % 2], 0.4)
        s.add(bass(mtof(basses[(bar // 2) % 4]), 6 * e8 * 0.95, rng, 300, 2.5), t, 0.35, 0.0, 0.05)
    for i in range(6):
        s.add(pad([mtof(n) for n in [40, 47, 52]], 4 * 6 * e8, rng, 600, 2.0, 2.0), i * 4 * 6 * e8, 0.12, 0.0, 0.6)
    return s.render()


def boss_kordrak(rng):
    """132 bpm, C frig endüstriyel: ağır bas davul, 2 ve 4'te örs, bozuk testere bas riffi, pirinç gibi alçak vuruşlar."""
    bpm = 132.0
    q = 60.0 / bpm
    bars = 16
    L = bars * 4 * q
    s = Song(L, rng, 1.8, 2500)
    s16 = q / 4
    riff = [36, 0, 36, 36, 0, 36, 37, 0, 36, 0, 36, 36, 39, 0, 37, 0]
    for bar in range(bars):
        t = bar * 4 * q
        for b in range(4):
            s.add(kick(rng, 115, 34, 0.45, 3.0), t + b * q, 0.8, 0, 0.05)
        for b in (1, 3):
            a = sfx.metal(rng, rng.uniform(800, 860), 0.9, 0.5, 9, 0.8)
            s.add(a, t + b * q, 0.22, 0.2, 0.4)
            s.add(snare(rng, 0.25), t + b * q, 0.25, -0.1, 0.3)
        for k, n in enumerate(riff):
            if n == 0:
                continue
            d = s16 * (1.8 if k in (12, 14) else 0.8)
            s.add(bass(mtof(n + (5 if bar % 4 == 2 and k >= 8 else 0)), d, rng, 700, 4.0), t + k * s16, 0.3, 0.0, 0.03)
        for e in range(8):
            s.add(hat(rng, 0.04, 8000), t + e * q / 2, 0.08, -0.5, 0.05)
        if bar % 4 == 0:
            s.add(stab([mtof(n) for n in [48, 49, 55]], q * 3, rng, 900), t, 0.35, 0.0, 0.3)
        if bar % 8 == 7:
            for k in range(6):
                s.add(tom(rng, 120 - k * 10, 0.4), t + 2 * q + k * s16 * 1.33, 0.4, -0.5 + k * 0.2, 0.3)
    s.bed(crackle(L + 3, rng, 30, 3000, 1.0), 0.2, 0.3, 0.2)
    return s.render()


def boss_nyxthar(rng):
    """150 bpm, B minör: hızlı tom yuvarlamaları, ağır koro ilerleyişi, çan arpeji, ters yükselişler (final)."""
    bpm = 150.0
    q = 60.0 / bpm
    bars = 24
    L = bars * 4 * q
    s = Song(L, rng, 3.0, 2500)
    prog = [[47, 50, 54], [43, 47, 50], [48, 52, 55], [42, 46, 49]]
    s16 = q / 4
    for bar in range(bars):
        t = bar * 4 * q
        ch = prog[(bar // 2) % 4]
        s.add(kick(rng, 105, 32, 0.5), t, 0.8, 0, 0.1)
        s.add(kick(rng, 105, 32, 0.5), t + 2.5 * q, 0.6, 0, 0.1)
        for k in range(16):
            if k % 4 == 0 or rng.uniform() < 0.55:
                f = [140, 120, 100, 85][(k // 2) % 4]
                s.add(tom(rng, f, 0.3), t + k * s16, 0.18 + (0.12 if k % 4 == 0 else 0), (-0.5, 0.5)[k % 2], 0.2)
        s.add(snare(rng), t + q, 0.3, 0.1, 0.5)
        s.add(snare(rng), t + 3 * q, 0.3, -0.1, 0.5)
        s.add(bass(mtof(ch[0] - 12), 4 * q * 0.95, rng, 350, 2.5), t, 0.3, 0, 0.05)
        for k in range(8):
            n = ch[k % 3] + 24 + (12 if k >= 6 else 0)
            b = sfx.bell(rng, mtof(n), 0.6, 0.25)
            s.add(b, t + k * q / 2, 0.05, (-0.6, 0.6)[k % 2], 0.6)
        if bar % 2 == 0:
            s.add(choir([mtof(n) for n in ch], 8 * q + 1.0, rng, "o", 0.8, 1.2), t, 0.16, 0.0, 0.7)
        if bar % 8 == 7:
            sw = reverse(convolve(kick(rng, 90, 30, 0.6), reverb_ir(2.0, rng, 1800)))
            sw = sw / (np.max(np.abs(sw)) + 1e-9)
            s.add(sw, t + 4 * q - len(sw) / SR, 0.35, 0.0, 0.0)
    return s.render()


TRACKS = {
    "floor_1": (floor_1, -19), "floor_2": (floor_2, -19), "floor_3": (floor_3, -19), "floor_4": (floor_4, -19),
    "boss_morvath": (boss_morvath, -15), "boss_mycela": (boss_mycela, -15),
    "boss_kordrak": (boss_kordrak, -15), "boss_nyxthar": (boss_nyxthar, -15),
}
