"""Aşama 10: sprite PNG'lerinde tamamen saydam piksellerin rengini sıfırlar (görüntü değişmez, dosya küçülür).

Aşama 8'de üretilen ışıma katmanları (<anim>_e.png) saydam piksellerin altında gereksiz renk taşıyordu; bu, .exe'ye
~37 MB fazladan veri ekliyordu (Godot kayıpsız WebP'si bu rengi de saklar). sprite_lib.emissive_layer artık temiz yazar;
bu araç mevcut dosyaları sprite'ları yeniden üretmeden (~35 dk) temizler. Yalnızca filtresiz (sprite_lib.write_png'nin
yazdığı) 8 bit RGBA PNG'lere dokunur; başkasını atlar.

Kullanım: blender -b --factory-startup --python tools/blender/clean_alpha.py -- [--pattern=_e.png] [--dry]
(Blender'ın Python'u numpy içerir; bpy kullanılmaz.)
"""
import glob
import os
import struct
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_lib as sl  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def read_png_rgba(path):
    """Filtresiz 8 bit RGBA PNG'yi H×W×4 uint8 olarak okur; uygun değilse None."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    pos, idat, w, h = 8, [], 0, 0
    while pos < len(data):
        n = struct.unpack(">I", data[pos:pos + 4])[0]
        t = data[pos + 4:pos + 8]
        d = data[pos + 8:pos + 8 + n]
        if t == b"IHDR":
            w, h, bd, ct, _c, _f, il = struct.unpack(">IIBBBBB", d)
            if bd != 8 or ct != 6 or il != 0:
                return None
        elif t == b"IDAT":
            idat.append(d)
        pos += 12 + n
    raw = np.frombuffer(zlib.decompress(b"".join(idat)), np.uint8).reshape(h, 1 + w * 4)
    if raw[:, 0].any():
        return None  # satır filtresi var: bu araç çözmez
    return raw[:, 1:].reshape(h, w, 4).copy()


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    pattern = "_e.png"
    dry = "--dry" in args
    for a in args:
        if a.startswith("--pattern="):
            pattern = a.split("=", 1)[1]
    files = sorted(glob.glob(os.path.join(ROOT, "assets", "sprites", "**", "*" + pattern), recursive=True))
    before = after = changed = skipped = 0
    for f in files:
        arr = read_png_rgba(f)
        size = os.path.getsize(f)
        before += size
        if arr is None:
            skipped += 1
            after += size
            continue
        mask = arr[..., 3] == 0
        if not arr[mask][:, :3].any():
            after += size
            continue
        arr[mask] = 0
        if not dry:
            sl.write_png(f, arr)
        changed += 1
        after += os.path.getsize(f) if not dry else size
    print("[Temizlik] %d dosya (%s), %d değişti, %d atlandı: %.1f MB → %.1f MB" % (len(files), pattern, changed, skipped,
                                                                                before / 1e6, after / 1e6))


main()
