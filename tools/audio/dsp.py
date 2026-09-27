"""DSP yardımcıları (Aşama 9) — yalnızca numpy ile ses sentezi.

Osilatörler, gürültüler, zarflar, FFT tabanlı filtreler (sabit ve zamanla değişen), evrişimli yankı (reverb),
modal sentez (metal, çan), Karplus-Strong tel, formant (ses/koro), doygunluk, karıştırma ve WAV yazımı.
scipy gerekmez; Blender'ın Python'u (numpy dahil) ya da numpy kurulu herhangi bir Python 3 yeter.
"""

from __future__ import annotations

import wave

import numpy as np

SR = 44100


# --- zaman ve zarflar ---

def n_of(d: float) -> int:
    return max(1, int(round(d * SR)))


def tvec(d: float) -> np.ndarray:
    return np.arange(n_of(d)) / SR


def silence(d: float) -> np.ndarray:
    return np.zeros(n_of(d))


def fit(x, n: int) -> np.ndarray:
    """Sayıyı ya da diziyi n uzunluğa getirir (kısa dizi son değeriyle uzatılır)."""
    if np.ndim(x) == 0:
        return np.full(n, float(x))
    x = np.asarray(x, float)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.full(n - len(x), x[-1] if len(x) else 0.0)])


def env_exp(d: float, tau: float, attack: float = 0.002) -> np.ndarray:
    """Üstel sönüm (tau sn), kısa doğrusal atakla."""
    t = tvec(d)
    e = np.exp(-t / max(tau, 1e-4))
    if attack > 0:
        e *= np.clip(t / attack, 0.0, 1.0)
    return e


def env_pts(d: float, pts, power: float = 1.0) -> np.ndarray:
    """Noktalardan (sn, değer) doğrusal zarf; power > 1 yumuşak/eğik."""
    t = tvec(d)
    ts = [p[0] for p in pts]
    vs = [p[1] for p in pts]
    e = np.interp(t, ts, vs)
    return np.power(np.clip(e, 0.0, None), power) if power != 1.0 else e


def env_bell(d: float, peak: float = 0.4, power: float = 1.6) -> np.ndarray:
    """0'dan yükselip peak oranında tepe yapan ve sönen zarf (hışırtılar için)."""
    return env_pts(d, [(0.0, 0.0), (d * peak, 1.0), (d, 0.0)], power)


def glide(f0: float, f1: float, d: float, curve: float = 1.0) -> np.ndarray:
    """Üstel perde kayması f0 → f1 (curve < 1 hızlı başta, > 1 sonda)."""
    k = np.power(np.linspace(0.0, 1.0, n_of(d)), curve)
    return f0 * np.power(f1 / f0, k)


# --- kaynaklar ---

def osc(freq, d: float, shape: str = "sine", phase: float = 0.0) -> np.ndarray:
    n = n_of(d)
    f = fit(freq, n)
    ph = phase + 2.0 * np.pi * np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(ph)
    frac = (ph / (2.0 * np.pi)) % 1.0
    if shape == "saw":
        return 2.0 * frac - 1.0
    if shape == "square":
        return np.where(frac < 0.5, 1.0, -1.0)
    if shape == "tri":
        return 4.0 * np.abs(frac - 0.5) - 1.0
    raise ValueError(shape)


def supersaw(freq, d: float, rng, voices: int = 5, detune: float = 0.012, shape: str = "saw") -> np.ndarray:
    """Birbirine göre hafif akortsuz çoklu dalga (kalın pad/koro)."""
    out = np.zeros(n_of(d))
    for i in range(voices):
        k = (i - (voices - 1) / 2) / max((voices - 1) / 2, 1)
        out += osc(fit(freq, n_of(d)) * (1.0 + detune * k), d, shape, rng.uniform(0, 2 * np.pi))
    return out / np.sqrt(voices)


def white(d: float, rng) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n_of(d))


def brown(d: float, rng) -> np.ndarray:
    x = np.cumsum(rng.normal(0.0, 1.0, n_of(d)))
    x = highpass(x, 18.0, 1)
    return x / (np.max(np.abs(x)) + 1e-9)


def pink(d: float, rng) -> np.ndarray:
    x = rng.normal(0.0, 1.0, n_of(d))
    y = spec(x, lambda f: 1.0 / np.sqrt(np.maximum(f, 20.0)))
    return y / (np.max(np.abs(y)) + 1e-9)


def smooth_noise(d: float, rate: float, rng) -> np.ndarray:
    """rate Hz hızında yumuşak rastgele eğri (0..1) — titreşim, dalgalanma."""
    n = n_of(d)
    k = max(int(d * rate) + 2, 2)
    pts = rng.uniform(0.0, 1.0, k)
    xs = np.linspace(0, n - 1, k)
    return np.interp(np.arange(n), xs, pts)


# --- FFT filtreleri ---

def spec(x: np.ndarray, resp) -> np.ndarray:
    """Sıfır fazlı sabit filtre: resp(f) genlik yanıtı (f Hz dizisi)."""
    n = len(x)
    pad = min(n, SR // 2)
    size = 1 << int(np.ceil(np.log2(n + pad)))
    X = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1.0 / SR)
    return np.fft.irfft(X * resp(f), size)[:n]


def r_lp(fc, order: float = 2.0):
    return lambda f: 1.0 / np.sqrt(1.0 + np.power(f / fc, 2.0 * order))


def r_hp(fc, order: float = 2.0):
    return lambda f: 1.0 / np.sqrt(1.0 + np.power(fc / np.maximum(f, 1e-3), 2.0 * order))


def r_bp(fc, bw: float = 1.0):
    """Log-frekansta Gauss bant (bw oktav genişliğinde)."""
    return lambda f: np.exp(-0.5 * np.square(np.log2(np.maximum(f, 1.0) / fc) / bw))


def lowpass(x, fc: float, order: float = 2.0):
    return spec(x, r_lp(fc, order))


def highpass(x, fc: float, order: float = 2.0):
    return spec(x, r_hp(fc, order))


def bandpass(x, fc: float, bw: float = 1.0):
    return spec(x, r_bp(fc, bw))


def eq(x, bands) -> np.ndarray:
    """bands: [(fc, dB, bw_oktav)] tepe/çukur ekolayzır."""
    def resp(f):
        r = np.ones_like(f)
        for fc, db, bw in bands:
            r = r * (1.0 + (10 ** (db / 20.0) - 1.0) * r_bp(fc, bw)(f))
        return r
    return spec(x, resp)


def stft_filter(x: np.ndarray, resp_at, win: int = 1024, hop: int = 256) -> np.ndarray:
    """Zamanla değişen filtre: resp_at(t_sn[F,1], f_hz[1,K]) → yanıt matrisi. Hann penceresi, %75 örtüşme."""
    n = len(x)
    pad = np.concatenate([np.zeros(win), x, np.zeros(win)])
    frames = np.lib.stride_tricks.sliding_window_view(pad, win)[::hop]
    w = np.hanning(win + 1)[:-1]
    F = np.fft.rfft(frames * w, axis=1)
    f = np.fft.rfftfreq(win, 1.0 / SR)
    starts = np.arange(frames.shape[0]) * hop
    tc = (starts + win / 2 - win) / SR
    Y = np.fft.irfft(F * resp_at(tc[:, None], f[None, :]), win, axis=1)
    out = np.zeros(len(pad))
    for i, s in enumerate(starts):
        out[s:s + win] += Y[i]
    return out[win:win + n] / 2.0


def _curve_at(curve: np.ndarray):
    idx = np.arange(len(curve)) / SR
    return lambda t: np.interp(t, idx, curve)


def sweep_bp(x, fc_curve, bw: float = 1.0):
    """Merkezi zamanla kayan bant geçiren (fc_curve: örnek başına Hz)."""
    c = _curve_at(fit(fc_curve, len(x)))
    return stft_filter(x, lambda t, f: np.exp(-0.5 * np.square(np.log2(np.maximum(f, 1.0) / c(t)) / bw)))


def sweep_lp(x, fc_curve, order: float = 2.0):
    c = _curve_at(fit(fc_curve, len(x)))
    return stft_filter(x, lambda t, f: 1.0 / np.sqrt(1.0 + np.power(f / c(t), 2.0 * order)))


VOWELS = {
    "a": [(800, 1.0), (1150, 0.6), (2900, 0.25)],
    "o": [(450, 1.0), (800, 0.5), (2830, 0.15)],
    "u": [(325, 1.0), (700, 0.35), (2530, 0.1)],
    "e": [(400, 1.0), (1700, 0.45), (2600, 0.2)],
    "i": [(280, 1.0), (2250, 0.35), (2900, 0.2)],
}


def formant(x, vowel: str = "a", bw: float = 0.18, shift: float = 1.0):
    peaks = VOWELS[vowel]

    def resp(f):
        r = np.full_like(f, 0.03)
        for fc, g in peaks:
            r = r + g * r_bp(fc * shift, bw)(f)
        return r
    return spec(x, resp)


def formant_sweep(x, v0: str, v1: str, bw: float = 0.18):
    """İki ünlü arasında kayan formant (uluma, çığlık)."""
    p0, p1 = VOWELS[v0], VOWELS[v1]
    n = len(x)
    k = _curve_at(np.linspace(0.0, 1.0, n))

    def resp(t, f):
        kk = k(t)
        r = np.full(np.broadcast_shapes(t.shape, f.shape), 0.03)
        for (f0, g0), (f1, g1) in zip(p0, p1):
            fc = f0 + (f1 - f0) * kk
            g = g0 + (g1 - g0) * kk
            r = r + g * np.exp(-0.5 * np.square(np.log2(np.maximum(f, 1.0) / fc) / bw))
        return r
    return stft_filter(x, resp)


# --- evrişim ve yankı ---

def convolve(x, ir) -> np.ndarray:
    n = len(x) + len(ir) - 1
    size = 1 << int(np.ceil(np.log2(n)))
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]


def reverb_ir(rt60: float, rng, damp: float = 3500.0, predelay: float = 0.012, early: int = 8) -> np.ndarray:
    """Zindan yankısı: üstel sönen gürültü; tizler daha hızlı söner (karanlık taş oda). Enerjisi 1."""
    d = rt60 * 1.1 + predelay
    t = tvec(d)
    noise = rng.normal(0.0, 1.0, len(t))
    lo = lowpass(noise, damp, 1.5) * np.power(10.0, -3.0 * t / rt60)
    hi = highpass(noise, damp, 1.5) * np.power(10.0, -3.0 * t / (rt60 * 0.3))
    ir = lo + 0.6 * hi
    ir *= np.clip((t - predelay) / 0.004, 0.0, 1.0)
    for _ in range(early):
        at = predelay + rng.uniform(0.003, 0.05)
        i = int(at * SR)
        if i < len(ir):
            ir[i] += rng.choice([-1, 1]) * rng.uniform(1.5, 4.0) * np.exp(-at / 0.05)
    return ir / (np.sqrt(np.sum(ir * ir)) + 1e-9)


def reverb(x, rt60: float, mix: float, rng, damp: float = 3500.0, predelay: float = 0.012) -> np.ndarray:
    wet = convolve(x, reverb_ir(rt60, rng, damp, predelay))
    out = wet * mix
    out[:len(x)] += x * (1.0 - mix * 0.5)
    return out


# --- modal, tel, kabarcık, çıtırtı ---

def modal(d: float, modes, rng=None, jitter: float = 0.0) -> np.ndarray:
    """Vurulan cisim: modes = [(Hz, sönüm_tau_sn, genlik)]."""
    t = tvec(d)
    out = np.zeros(len(t))
    for f, tau, a in modes:
        if f >= SR / 2:
            continue
        ff = f * (1.0 + (rng.uniform(-jitter, jitter) if rng is not None and jitter else 0.0))
        ph = rng.uniform(0, 2 * np.pi) if rng is not None else 0.0
        out += a * np.exp(-t / tau) * np.sin(2 * np.pi * ff * t + ph)
    return out


def metal_modes(f0: float, count: int, rng, tau: float = 0.8, spread: float = 1.0):
    """Çan/örs benzeri uyumsuz kısmi sesler."""
    ratios = [1.0, 2.32, 4.25, 6.63, 9.38, 12.6, 16.2, 20.1, 2.76, 5.4, 8.9, 13.3]
    out = []
    for i in range(count):
        r = ratios[i % len(ratios)] * (1.0 + rng.uniform(-0.03, 0.03) * spread)
        out.append((f0 * r, tau / (1.0 + i * 0.35), 1.0 / (1.0 + i * 0.55)))
    return out


def pluck(freq: float, d: float, rng, damp: float = 0.996, bright: float = 0.6) -> np.ndarray:
    """Karplus-Strong tel (yay kirişi, arbalet). Periyot bloklarıyla vektörleştirildi."""
    period = max(int(SR / freq), 2)
    n = n_of(d)
    y = np.zeros(n + period + 1)
    burst = rng.uniform(-1.0, 1.0, period)
    burst = bright * burst + (1.0 - bright) * np.convolve(burst, np.ones(4) / 4, mode="same")
    y[:period] = burst
    s = period
    while s < n:
        e = min(s + period, n)
        prev = y[s - period:e - period]
        prev1 = y[s - period - 1:e - period - 1] if s - period - 1 >= 0 else np.concatenate([[0.0], y[:e - period - 1]])
        y[s:e] = damp * 0.5 * (prev + prev1)
        s = e
    return y[:n]


def bubbles(d: float, rng, count: int, f_lo: float = 300, f_hi: float = 1200, up: float = 1.6,
            dur=(0.015, 0.06), tau: float = 0.02) -> np.ndarray:
    """Kabarcıklar: kısa, yukarı kayan sinüs cıvıltıları (su, zehir, glup)."""
    out = np.zeros(n_of(d))
    for _ in range(count):
        dd = rng.uniform(*dur)
        f0 = np.exp(rng.uniform(np.log(f_lo), np.log(f_hi)))
        x = osc(glide(f0, f0 * up, dd), dd) * env_exp(dd, tau, 0.001)
        at = rng.uniform(0, max(d - dd, 0.0))
        i = int(at * SR)
        out[i:i + len(x)] += x[:len(out) - i] * rng.uniform(0.3, 1.0)
    return out


def crackle(d: float, rng, rate: float, fc: float = 3000, bw: float = 1.2, decay=None) -> np.ndarray:
    """Seyrek dürtüler (ateş çıtırtısı, kıvılcım, kemik tıkırtısı). decay verilirse yoğunluk zamanla söner."""
    n = n_of(d)
    x = np.zeros(n)
    count = max(int(rate * d), 1)
    if decay:
        times = -np.log(1 - rng.uniform(0, 1 - np.exp(-d / decay), count)) * decay
    else:
        times = rng.uniform(0, d, count)
    idx = np.clip((times * SR).astype(int), 0, n - 1)
    x[idx] += np.minimum(rng.pareto(2.5, count), 4.0) * rng.choice([-1, 1], count)
    return bandpass(x, fc, bw)


# --- dinamik ve karıştırma ---

def sat(x, drive: float = 2.0) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


def fold(x, amount: float = 1.5) -> np.ndarray:
    """Dalga katlama (sert, kirli distorsiyon)."""
    return np.sin(x * amount * np.pi / 2)


def reverse(x) -> np.ndarray:
    return np.asarray(x)[::-1].copy()


def peak_norm(x, db: float = -1.0) -> np.ndarray:
    p = np.max(np.abs(x)) + 1e-12
    return x * (10 ** (db / 20.0) / p)


def fade(x, fin: float = 0.0, fout: float = 0.005) -> np.ndarray:
    x = np.array(x, float)
    a, b = n_of(fin) if fin > 0 else 0, n_of(fout) if fout > 0 else 0
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


class Mix:
    """Katmanları zamana yerleştirip toplar (gerekirse uzar)."""

    def __init__(self, d: float = 0.0, channels: int = 1):
        self.ch = channels
        self.buf = np.zeros((n_of(d) if d > 0 else 1, channels)) if channels > 1 else np.zeros(n_of(d) if d > 0 else 1)

    def add(self, x, at: float = 0.0, gain: float = 1.0, pan: float = 0.0) -> "Mix":
        x = np.asarray(x, float)
        i = int(round(at * SR))
        need = i + len(x)
        if need > len(self.buf):
            extra = need - len(self.buf)
            shape = (extra, self.ch) if self.ch > 1 else (extra,)
            self.buf = np.concatenate([self.buf, np.zeros(shape)])
        if self.ch > 1:
            if x.ndim == 1:
                gl = np.cos((pan + 1) * np.pi / 4) * np.sqrt(2)
                gr = np.sin((pan + 1) * np.pi / 4) * np.sqrt(2)
                self.buf[i:need, 0] += x * gain * gl
                self.buf[i:need, 1] += x * gain * gr
            else:
                self.buf[i:need] += x * gain
        else:
            self.buf[i:need] += x * gain
        return self

    def out(self) -> np.ndarray:
        return self.buf


def trim_tail(x, thresh_db: float = -55.0, keep: float = 0.01) -> np.ndarray:
    """Sondaki sessizliği atar."""
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    th = np.max(a) * 10 ** (thresh_db / 20.0)
    idx = np.nonzero(a > th)[0]
    end = min(len(x), (idx[-1] if len(idx) else 0) + n_of(keep))
    return x[:max(end, n_of(0.02))]


def loudness_norm(x, rms_db: float = -15.0, peak_db: float = -1.0, window: float = 0.1, max_limit_db: float = 10.0) -> np.ndarray:
    """En gürültülü pencerenin RMS'i rms_db olacak şekilde ölçekler (sesler arası tutarlı gürlük). Sivri tepeler
    yüzünden hedefe ulaşılamıyorsa en fazla max_limit_db kadar fazladan kazanç verilir ve tepeler yumuşak sınırlanır
    (tanh) — çıtırtı ve kırılma seslerinde sert, kirli bir geçiş bırakır."""
    m = x if x.ndim == 1 else np.mean(x, axis=1)
    w = max(min(n_of(window), len(m)), 1)
    c = np.convolve(m * m, np.ones(w) / w, mode="valid")
    rms = np.sqrt(np.max(c)) + 1e-12
    peak = np.max(np.abs(x)) + 1e-12
    ceil = 10 ** (peak_db / 20.0)
    g_rms = 10 ** (rms_db / 20.0) / rms
    g_peak = ceil / peak
    if g_rms <= g_peak:
        return x * g_rms
    y = x * min(g_rms, g_peak * 10 ** (max_limit_db / 20.0))
    knee = 0.5 * ceil
    a = np.abs(y)
    over = a > knee
    y[over] = np.sign(y[over]) * (knee + (ceil - knee) * np.tanh((a[over] - knee) / (ceil - knee)))
    return y


def write_wav(path: str, x, sr: int = SR) -> None:
    x = np.asarray(x, float)
    ch = 1 if x.ndim == 1 else x.shape[1]
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
