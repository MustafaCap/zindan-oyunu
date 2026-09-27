"""Ses sentezleyici (Aşama 9) — `make sfx` bunu çalıştırır.

    blender -b --factory-startup --python tools/audio/sfx_synth.py -- [--only=hit_flesh,floor_1] [--sfx] [--music]
    (bu bilgisayarda: make sfx BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"; hepsi ~2-3 dk)

Efektler (tools/audio/sfx.py) assets/audio/sfx/<id>_<n>.wav (44,1 kHz, 16 bit, mono) olarak, müzikler
(tools/audio/music.py) assets/audio/music/<id>.ogg (Vorbis, stereo, dikişsiz döngü) olarak yazılır.
Blender'ın kendi Python'u numpy ve OGG kodlayıcısını (aud modülü) içerir; ayrıca bir şey kurmak gerekmez.
numpy kurulu herhangi bir Python 3 ile de çalışır (`python3 tools/audio/sfx_synth.py --sfx`); o zaman aud olmadığı
için müzik atlanır. Aynı tohumla (id + varyant) her seferinde aynı ses üretilir.
"""

from __future__ import annotations

import os
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import numpy as np  # noqa: E402

import dsp  # noqa: E402
import music  # noqa: E402
import sfx  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
MUSIC_BITRATE = 112000


def parse_args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out = {"only": None, "sfx": True, "music": True}
    if "--sfx" in argv or "--music" in argv:
        out["sfx"] = "--sfx" in argv
        out["music"] = "--music" in argv
    for a in argv:
        if a.startswith("--only="):
            out["only"] = set(a.split("=", 1)[1].split(","))
    return out


def seed_for(name: str, v: int) -> int:
    return zlib.crc32(("%s:%d" % (name, v)).encode("utf-8"))


def render_sfx(only) -> int:
    os.makedirs(SFX_DIR, exist_ok=True)
    written = set()
    count = 0
    for sid, (fn, variants, target) in sfx.SOUNDS.items():
        if only and sid not in only:
            continue
        for v in range(variants):
            rng = np.random.default_rng(seed_for(sid, v))
            x = np.asarray(fn(rng, v), float)
            if not np.all(np.isfinite(x)):
                raise RuntimeError("%s_%d: sayı olmayan örnek" % (sid, v + 1))
            x = dsp.trim_tail(x)
            x = dsp.loudness_norm(x, target, -1.0)
            x = dsp.fade(x, 0.0, 0.004)
            name = "%s_%d.wav" % (sid, v + 1)
            dsp.write_wav(os.path.join(SFX_DIR, name), x)
            written.add(name)
            count += 1
    if not only:
        # Artık üretilmeyen eski dosyalar silinir (Godot'nun .import dosyalarıyla birlikte)
        for f in os.listdir(SFX_DIR):
            if f.endswith(".wav") and f not in written:
                os.remove(os.path.join(SFX_DIR, f))
                imp = os.path.join(SFX_DIR, f + ".import")
                if os.path.exists(imp):
                    os.remove(imp)
    return count


def write_ogg(path: str, x: np.ndarray) -> None:
    import aud  # Blender'ın ses modülü (ffmpeg/libvorbis)
    data = np.ascontiguousarray(x.astype(np.float32))
    snd = aud.Sound.buffer(data, dsp.SR)
    snd.write(path, dsp.SR, aud.CHANNELS_STEREO, aud.FORMAT_FLOAT32, aud.CONTAINER_OGG, aud.CODEC_VORBIS, MUSIC_BITRATE)


def render_music(only) -> int:
    try:
        import aud  # noqa: F401
    except ImportError:
        print("[sfx] aud modülü yok (Blender dışında): müzik atlandı. Müzik için: make sfx BLENDER=...")
        return 0
    os.makedirs(MUSIC_DIR, exist_ok=True)
    count = 0
    for tid, (fn, target) in music.TRACKS.items():
        if only and tid not in only:
            continue
        t0 = time.time()
        rng = np.random.default_rng(seed_for(tid, 0))
        x = fn(rng)
        if not np.all(np.isfinite(x)):
            raise RuntimeError("%s: sayı olmayan örnek" % tid)
        x = dsp.loudness_norm(x, target, -1.0, 3.0)
        write_ogg(os.path.join(MUSIC_DIR, tid + ".ogg"), x)
        print("[sfx] müzik %s: %.1f sn (%.0f sn'de üretildi)" % (tid, len(x) / dsp.SR, time.time() - t0))
        count += 1
    return count


def main() -> None:
    args = parse_args()
    t0 = time.time()
    n_sfx = render_sfx(args["only"]) if args["sfx"] else 0
    print("[sfx] %d efekt dosyası yazıldı (%.0f sn)" % (n_sfx, time.time() - t0))
    n_mus = render_music(args["only"]) if args["music"] else 0
    print("[sfx] %d müzik yazıldı — toplam %.0f sn" % (n_mus, time.time() - t0))


if __name__ == "__main__":
    main()
