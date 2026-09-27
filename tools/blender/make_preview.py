"""Sprite önizleme sayfası (Aşama 8, geliştirme aracı): bir karakterin tüm animasyonlarını 8 yönde, seçilen silahla
oynatan tek dosyalık HTML üretir (sayfalar içine gömülür). Blender'ın Python'uyla ya da herhangi bir Python 3 ile çalışır:

    python tools/blender/make_preview.py warrior build/sprites_preview/warrior.html
"""

import base64
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def b64(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")


def main():
    cid = sys.argv[1] if len(sys.argv) > 1 else "warrior"
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "build", "sprites_preview", cid + ".html")
    cdir = os.path.join(ROOT, "assets", "sprites", "characters", cid)
    wdir = os.path.join(ROOT, "assets", "sprites", "weapons")
    with open(os.path.join(cdir, "meta.json"), encoding="utf-8") as f:
        meta = json.load(f)
    with open(os.path.join(wdir, "weapons.json"), encoding="utf-8") as f:
        wmeta = json.load(f)
    images = {"a_" + k: b64(os.path.join(cdir, v["file"])) for k, v in meta["anims"].items()}
    for k, v in wmeta.items():
        images["w_" + k] = b64(os.path.join(wdir, v["file"]))
    html = TEMPLATE.replace("__META__", json.dumps(meta)).replace("__WMETA__", json.dumps(wmeta)) \
        .replace("__IMAGES__", json.dumps(images)).replace("__TITLE__", cid.capitalize())
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write(html)
    print("önizleme:", out)


TEMPLATE = r"""<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__ sprite önizleme</title>
<style>
:root { --bg:#16131a; --panel:#221d27; --text:#ece6f0; --muted:#a49aad; --accent:#3f8cf2; }
body { margin:0; background:var(--bg); color:var(--text); font:15px/1.4 system-ui, "Segoe UI", sans-serif; }
main { max-width:1200px; margin:0 auto; padding:16px; }
h1 { font-size:20px; margin:0 0 4px; } p { color:var(--muted); margin:0 0 12px; }
.bar { display:flex; flex-wrap:wrap; gap:6px; align-items:center; margin:8px 0; }
.bar span { color:var(--muted); margin-right:4px; min-width:70px; }
button { background:var(--panel); color:var(--text); border:1px solid #3a3342; border-radius:6px; padding:6px 10px; cursor:pointer; font:inherit; }
button.on { border-color:var(--accent); background:#1d3350; }
canvas { display:block; width:100%; height:auto; border-radius:8px; margin-top:8px; image-rendering:auto; }
</style></head><body><main>
<h1>__TITLE__ — sprite önizleme (Aşama 8)</h1>
<p>8 yön (üstte doğu, saat yönünde), oyundaki gibi ayrı katman silahla. Oyunda ayrıca normal haritasıyla meşale/büyü ışığı alır.</p>
<div class="bar" id="anims"><span>Animasyon</span></div>
<div class="bar" id="weapons"><span>Silah</span></div>
<div class="bar" id="floors"><span>Zemin</span></div>
<div class="bar" id="zooms"><span>Boyut</span></div>
<canvas id="c" width="1160" height="520"></canvas>
</main><script>
const META = __META__, WMETA = __WMETA__, IMAGES = __IMAGES__;
const KARO = 45.254834, S = META.scale;
const img = {}; for (const k in IMAGES) { const i = new Image(); i.src = IMAGES[k]; img[k] = i; }
let anim = "walk", weapon = "blade", floor = "#5a3a44", zoom = 1.0, t0 = performance.now();
const floors = {"1. kat":"#5a3a44","2. kat":"#3d5a3a","3. kat":"#5a3a24","4. kat":"#2a2440"};
function bar(id, items, get, set) {
  const el = document.getElementById(id);
  for (const [label, val] of items) {
    const b = document.createElement("button"); b.textContent = label;
    b.onclick = () => { set(val); t0 = performance.now(); refresh(); };
    b.dataset.v = val; el.appendChild(b);
  }
  const refresh = () => el.querySelectorAll("button").forEach(b => b.classList.toggle("on", b.dataset.v === String(get())));
  refresh(); return refresh;
}
const names = {idle:"Bekleme", walk:"Yürüme", attack:"Saldırı", cast:"Atış/Büyü", punch_r:"Sağ yumruk", punch_l:"Sol yumruk", hit:"Hasar", death:"Ölüm", rush:"Kalkan Hücumu"};
const r1 = bar("anims", Object.keys(META.anims).map(a => [names[a] || a, a]), () => anim, v => anim = v);
const r2 = bar("weapons", [["Yok", ""], ...Object.keys(WMETA).map(w => [{blade:"Kılıç", axe:"Balta", fist:"Demir yumruk", scythe:"Tırpan", dagger:"Hançer", mace:"Gürz", bow:"Yay", crossbow:"Arbalet", spear:"Mızrak", tome:"Kitap", staff:"Asa", rune:"Rün"}[w] || w, w])], () => weapon, v => weapon = v);
const r3 = bar("floors", Object.entries(floors), () => floor, v => floor = v);
const r4 = bar("zooms", [["Oyundaki (×0,8)", "0.8"], ["×1", "1"], ["×1,6", "1.6"]], () => String(zoom), v => zoom = parseFloat(v));
const cv = document.getElementById("c"), cx = cv.getContext("2d");
function drawWeapon(h, x, y, z) {
  const w = WMETA[weapon], im = img["w_" + weapon]; if (!w || !im.complete) return;
  const j = ((Math.round(h[2] / (360 / w.yaws)) % w.yaws) + w.yaws) % w.yaws;
  let pi = 0; w.pitches.forEach((p, i) => { if (Math.abs(p - h[3]) < Math.abs(w.pitches[pi] - h[3])) pi = i; });
  const c = w.cell, d = c * z;
  cx.drawImage(im, j * c, pi * c, c, c, x + h[0] * S * z - d / 2, y + h[1] * S * z - d / 2, d, d);
}
function frame(now) {
  cx.fillStyle = floor; cx.fillRect(0, 0, cv.width, cv.height);
  const a = META.anims[anim], im = img["a_" + anim];
  const tt = (now - t0) / 1000; let f = Math.floor(tt * a.fps);
  f = a.loop ? f % a.frames : Math.min(f, a.frames - 1);
  if (!a.loop && tt > a.frames / a.fps + 0.8) t0 = now;
  const z = zoom, colW = cv.width / 4;
  for (let d = 0; d < 8; d++) {
    const x = colW * (d % 4) + colW / 2, y = d < 4 ? 210 : 460;
    cx.fillStyle = "rgba(0,0,0,0.35)"; cx.beginPath();
    cx.ellipse(x, y, (META.width * 0.5 + 4) * S * z, (META.width * 0.25 + 2) * S * z, 0, 0, 7); cx.fill();
    const w = WMETA[weapon], hold = !(anim === "death" && f >= 3);
    const hs = [];
    if (hold && a.hand) hs.push(a.hand[d][f]);
    if (hold && weapon === "fist" && a.hand_l) hs.push(a.hand_l[d][f]);
    const beh = hs.map(h => w && (h[4] + h[5] * w.length / KARO * 0.5 > 0));
    hs.forEach((h, i) => { if (beh[i]) drawWeapon(h, x, y, z); });
    if (im.complete) cx.drawImage(im, f * a.cell[0], d * a.cell[1], a.cell[0], a.cell[1],
      x - a.anchor[0] * z, y - a.anchor[1] * z, a.cell[0] * z, a.cell[1] * z);
    hs.forEach((h, i) => { if (!beh[i]) drawWeapon(h, x, y, z); });
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
</script></body></html>
"""

if __name__ == "__main__":
    main()
