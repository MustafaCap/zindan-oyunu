"""Aşama 10: sprite dokularının içe aktarma sıkıştırması (kullanıcı kararı). Renk ve normal sayfaları (ör. idle.png,
idle_n.png) %85 kaliteli kayıplı WebP olarak içe aktarılır (.exe ~189 → ~146 MB, gözle fark yok); ışıma katmanları
(*_e.png) kayıpsız kalır (zaten küçükler ve ışıma kenarları kayıplı sıkıştırmada lekelenir). Kaynak PNG'ler depoda
kayıpsız durur; yalnızca .import dosyalarındaki compress/mode ve compress/lossy_quality değişir.

Kullanım: python3 tools/dev/texture_compress.py [--quality=0.85]   (make textures; make sprites sonunda kendisi çalışır)
Sonra: godot --headless --path . --import (değişen dokular yeniden içe aktarılır).
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPRITES = os.path.join(ROOT, "assets", "sprites")


def main():
    quality = 0.85
    for a in sys.argv[1:]:
        if a.startswith("--quality="):
            quality = float(a.split("=", 1)[1])
    changed = total = 0
    for base, _dirs, files in os.walk(SPRITES):
        for f in files:
            if not f.endswith(".png.import"):
                continue
            total += 1
            path = os.path.join(base, f)
            with open(path, encoding="utf-8", newline="") as fh:
                text = fh.read()
            lossy = not f.endswith("_e.png.import")
            new = re.sub(r"(?m)^compress/mode=\d+", "compress/mode=%d" % (1 if lossy else 0), text)
            new = re.sub(r"(?m)^compress/lossy_quality=[0-9.]+", "compress/lossy_quality=%s" % quality, new)
            if new != text:
                with open(path, "w", encoding="utf-8", newline="") as fh:
                    fh.write(new)
                changed += 1
    print("[Doku] %d .import dosyası, %d değişti (renk/normal: kayıplı WebP %%%d, ışıma: kayıpsız)" % (total, changed, round(quality * 100)))


main()
