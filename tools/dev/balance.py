#!/usr/bin/env python3
"""Aşama 10 denge simülasyonu: zindan botunu (--balance) ırk × seed için paralel çalıştırır, her kat sonundaki
"[Denge]" satırlarını toplar ve GDD hedefleriyle karşılaştıran bir tablo basar (Markdown).

Bot tam düşman sayısı ve canıyla, ölümsüz OLMADAN oynar; ölümcül hasarda ölüm sayılır ve tam canla sürer (kat süresi
ölçülebilsin diye). Bot saldırılardan kaçmaz ve odaları en kısa yoldan gezer: süreler bir insan oyuncunun alt sınırıdır.

Kullanım: python3 tools/dev/balance.py --godot=/c/.../godot_console.exe [--races=warrior,ghost,archer,magical]
          [--seeds=11,22] [--jobs=4] [--out=build/balance]
"""
import argparse
import os
import re
import statistics
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

TARGET_MIN = {1: (6, 8), 2: (7, 10), 3: (8, 12), 4: (9, 15)}
TARGET_LEVEL = {1: 15, 2: 35, 3: 55, 4: 80}
LINE = re.compile(r"\[Denge\] (.*)")


def run_one(godot: str, race: str, seed: int, out_dir: str) -> tuple:
    log = os.path.join(out_dir, "%s_%d.log" % (race, seed))
    cmd = [godot, "--headless", "--path", ".", "--fixed-fps", "60", "--", "--balance", "--seed=%d" % seed, "--race=%s" % race]
    t0 = time.time()
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        code = subprocess.call(cmd, stdout=f, stderr=subprocess.STDOUT)
    rows = []
    with open(log, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = LINE.search(line)
            if m:
                d = dict(kv.split("=", 1) for kv in m.group(1).split(" "))
                rows.append(d)
    return race, seed, code, time.time() - t0, rows


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--races", default="warrior,ghost,archer,magical")
    ap.add_argument("--seeds", default="11,22")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) // 2))
    ap.add_argument("--out", default="build/balance")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    jobs = [(r, int(s)) for r in a.races.split(",") for s in a.seeds.split(",")]
    print("Denge: %d run, %d paralel" % (len(jobs), a.jobs), flush=True)
    results = []
    with ThreadPoolExecutor(a.jobs) as ex:
        for res in ex.map(lambda j: run_one(a.godot, j[0], j[1], a.out), jobs):
            race, seed, code, wall, rows = res
            print("  %s seed %d: çıkış %d, %d kat, %.0f sn gerçek süre" % (race, seed, code, len(rows), wall), flush=True)
            results.append(res)

    # Kat bazında toplam tablo
    by_floor = {f: [] for f in (1, 2, 3, 4)}
    for _race, _seed, _code, _wall, rows in results:
        for d in rows:
            by_floor[int(d["floor"])].append(d)
    out = []
    out.append("| Kat | Hedef süre | Bot süresi (ort., min–maks) | Boss süresi | Hedef level | Level (ort.) | Ölüm/run | Alınan hasar (maks can ×) | İksir | Run sayısı |")
    out.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for f in (1, 2, 3, 4):
        ds = by_floor[f]
        if not ds:
            out.append("| %d | %d-%d dk | — | — | %d | — | — | — | — | 0 |" % (f, *TARGET_MIN[f], TARGET_LEVEL[f]))
            continue
        t = [float(d["time"]) / 60.0 for d in ds]
        bt = [float(d["boss_time"]) for d in ds]
        lv = [int(d["level"]) for d in ds]
        de = [int(d["deaths"]) for d in ds]
        dm = [float(d["dmg_pct"]) for d in ds]
        po = [int(d["potions"]) for d in ds]
        out.append("| %d | %d-%d dk | %.1f dk (%.1f–%.1f) | %.0f sn | %d | %.1f | %.2f | %.1f | %.1f | %d |" % (
            f, *TARGET_MIN[f], statistics.mean(t), min(t), max(t), statistics.mean(bt), TARGET_LEVEL[f],
            statistics.mean(lv), statistics.mean(de), statistics.mean(dm), statistics.mean(po), len(ds)))
    out.append("")
    out.append("| Irk | Seed | Kat süreleri (dk) | Toplam | Level (kat sonları) | Ölüm (katlara göre) | Son silahlar |")
    out.append("| --- | --- | --- | --- | --- | --- | --- |")
    for race, seed, code, _wall, rows in results:
        times = [float(d["time"]) / 60.0 for d in rows]
        out.append("| %s | %d | %s | %.1f dk | %s | %s | %s |" % (race, seed, " / ".join("%.1f" % x for x in times), sum(times),
            " / ".join(d["level"] for d in rows), " / ".join(d["deaths"] for d in rows),
            rows[-1]["weapons"] if rows else "— (çıkış %d)" % code))
    text = "\n".join(out)
    print(text)
    with open(os.path.join(a.out, "balance.md"), "w", encoding="utf-8") as f:
        f.write(text + "\n")


if __name__ == "__main__":
    sys.exit(main())
