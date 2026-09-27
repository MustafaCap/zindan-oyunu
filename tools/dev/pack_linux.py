"""Linux derlemesini tar.gz'ye paketler (make export-linux çağırır).

Windows'ta zip çalıştırma iznini taşımaz; tar.gz'de dosya 755 izniyle yazılır, böylece Linux'ta açınca doğrudan çalışır.
Arşivde tek klasör var: ZindanOyunu/ZindanOyunu.x86_64 (pck gömülü).

Kullanım: python3 tools/dev/pack_linux.py build/linux/ZindanOyunu.x86_64 build/zindan-oyunu-linux-vX.Y.Z.tar.gz
"""
import os
import sys
import tarfile

src, out = sys.argv[1], sys.argv[2]
if not os.path.isfile(src):
    sys.exit("derleme bulunamadı: " + src)


def executable(info: tarfile.TarInfo) -> tarfile.TarInfo:
    info.mode = 0o755
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    return info


os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
with tarfile.open(out, "w:gz", compresslevel=9) as tar:
    tar.add(src, arcname="ZindanOyunu/" + os.path.basename(src), filter=executable)
print("paketlendi:", out, "(%.1f MB)" % (os.path.getsize(out) / 1e6))
