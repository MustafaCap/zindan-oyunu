"""Sprite üretici (Aşama 8) — Blender içinde çalışır:

    blender -b --factory-startup --python tools/blender/render_sprites.py -- [--only=warrior,blade,tiles1,icons,props]
                                                                              [--out=assets/sprites] [--anims=idle,walk]
(ya da make sprites BLENDER=...; --only verilmezse her şey üretilir, ~35 dk)

Karakterler (4 ırk, 20 düşman, 4 boss; characters.py, enemies.py): 8 yön × animasyonlar (bekleme, yürüme, saldırı, büyü/atış,
yumruklar, hasar alma, ölüm; Warrior'da Kalkan Hücumu; boss durum varyantları _closed / _p2). Her animasyon ayrı bir sayfa:
satırlar yön (cart açısı d × 45°, 0 = doğu, saat yönünde), sütunlar kareler. <anim>.png gölgeli renk (2×), <anim>_n.png
normal haritası (1×), <anim>_e.png ışıyan parçalar (gözler; varsa). meta.json: kare boyu, çapa (ayak), fps, döngü, iki elin
konumu/açısı ve karakter boyu.
Silahlar (weapons.py): 16 dönüş × 4 eğim; <silah>.png renk, _n normal, _g parıltı maskesi (element rengiyle boyanır).
Karolar (tiles.py): tiles/floor<N>.png, blocks<N>.png (1×). Oda nesneleri (props.py) ve arayüz ikonları (icons.py).
--anims ve --out yalnızca geliştirme denemesi içindir. Önizleme sayfası: make_preview.py.
"""

import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import numpy as np  # noqa: E402

import sprite_lib as sl  # noqa: E402
import characters  # noqa: E402
import enemies  # noqa: E402
import tiles  # noqa: E402
import icons  # noqa: E402
import props  # noqa: E402
import weapons  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCALE = 2                   # render çözünürlüğü = dünya pikseli × 2 (oyunda 0,5 ölçekle çizilir)
CHAR_CELL = (104, 104)       # dünya pikseli; kırpılmadan önceki hücre
CHAR_ANCHOR = (52, 78)      # ayakların hücredeki yeri
OUTLINE = 2                 # dış çizgi (render pikseli)


def _args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"only": None, "out": os.path.join(ROOT, "assets", "sprites"), "anims": None}
    for a in argv:
        if a.startswith("--anims="):
            # yalnızca geliştirme denemesi için (meta eksik kalır; --out ile başka klasöre yazın)
            out["anims"] = set(a.split("=", 1)[1].split(","))
        elif a.startswith("--only="):
            out["only"] = set(a.split("=", 1)[1].split(","))
        elif a.startswith("--out="):
            out["out"] = os.path.abspath(a.split("=", 1)[1])
    return out


def _bbox(alpha_stack):
    """Tüm karelerin birleşik kutusu (alfa > 0,01), 2'nin katına genişletilmiş."""
    any_a = (alpha_stack > 0.01).any(axis=0)
    ys, xs = np.nonzero(any_a)
    if len(xs) == 0:
        return 0, 0, 2, 2
    x0, x1 = xs.min() - 1, xs.max() + 2
    y0, y1 = ys.min() - 1, ys.max() + 2
    x0 -= x0 % 2
    y0 -= y0 % 2
    x1 += x1 % 2
    y1 += y1 % 2
    h, w = alpha_stack.shape[1:3]
    return max(x0, 0), max(y0, 0), min(x1, w), min(y1, h)


def render_character(cid, out_dir, tmp):
    t0 = time.time()
    sl.reset_scene()
    m = sl.Model(cid)
    spec = ALL_MODELS[cid](m)
    cell = spec.get("cell", CHAR_CELL)
    anchor = spec.get("anchor", CHAR_ANCHOR)
    cw, ch = cell[0] * SCALE, cell[1] * SCALE
    ax, ay = anchor[0] * SCALE, anchor[1] * SCALE
    grid = sl.Grid(8, 1, cw, ch, ax, ay, SCALE)
    grid.setup_camera()
    for d in range(8):
        grid.add_instance(m.coll, d, 0, -45.0 * d)
    meta = {"id": cid, "scale": SCALE, "dirs": 8, "anims": {}}
    height = 0.0
    width = 0.0
    previews = []
    for name, frames, fps, loop, fn in spec["anims"]:
        if ANIM_FILTER and name not in ANIM_FILTER:
            continue
        colors, alphas, normals, hands, hands_l, emits = [], [], [], [], [], []
        for f in range(frames):
            t = f / frames if loop else f / max(frames - 1, 1)
            m.pose(fn(t))
            p = sl.render_passes(tmp, "%s_%s_%d" % (cid, name, f))
            rgb, a = sl.toon(p, OUTLINE)
            nrm, na = sl.normal_rgb(p, OUTLINE)
            colors.append(np.concatenate([rgb, a[..., None]], axis=-1))
            normals.append(np.concatenate([nrm, na[..., None]], axis=-1))
            alphas.append(a)
            if name == "idle" and f == 0:
                ys, xs = np.nonzero(p["alpha"][:, :cw] > 0.5)
                height = (ay - ys.min()) / SCALE
                width = (xs.max() - xs.min()) / SCALE
            hands.append(_hand_data(m, spec, spec["hand"]) if spec.get("hand") else None)
            hands_l.append(_hand_data(m, spec, spec["hand_l"]) if spec.get("hand_l") else None)
            emits.append(sl.emissive_layer(p))
        # Kareleri hücrelere böl: [kare][yön]
        stack_a = np.stack([a[:, d * cw:(d + 1) * cw] for a in alphas for d in range(8)])
        x0, y0, x1, y1 = (int(v) for v in _bbox(stack_a))
        w, h = x1 - x0, y1 - y0
        sheet = np.zeros((8 * h, frames * w, 4), np.float32)
        nsheet = np.zeros((8 * h, frames * w, 4), np.float32)
        for f in range(frames):
            for d in range(8):
                sheet[d * h:(d + 1) * h, f * w:(f + 1) * w] = colors[f][y0:y1, d * cw + x0:d * cw + x1]
                nsheet[d * h:(d + 1) * h, f * w:(f + 1) * w] = normals[f][y0:y1, d * cw + x0:d * cw + x1]
        previews.append(sheet)
        sl.write_png(os.path.join(out_dir, name + ".png"), sheet)
        sl.write_png(os.path.join(out_dir, name + "_n.png"), sl.downsample2(nsheet))
        entry = {"file": name + ".png", "normal": name + "_n.png", "frames": frames, "fps": fps, "loop": loop,
                 "cell": [w, h], "anchor": [ax - x0, ay - y0]}
        if spec.get("hand"):
            # [yön][kare] = [x, y, cart_açı, eğim, derinlik, ileri_derinlik]; x, y dünya pikseli (ayağa göre)
            entry["hand"] = [[hands[f][d] for f in range(frames)] for d in range(8)]
        if spec.get("hand_l"):
            entry["hand_l"] = [[hands_l[f][d] for f in range(frames)] for d in range(8)]
        if any(e is not None for e in emits):
            # Karanlıkta parlayan parçalar (gözler): oyunda ışıktan etkilenmeyen ayrı katman
            esheet = np.zeros((8 * h, frames * w, 4), np.float32)
            for f in range(frames):
                if emits[f] is None:
                    continue
                for d in range(8):
                    esheet[d * h:(d + 1) * h, f * w:(f + 1) * w] = emits[f][y0:y1, d * cw + x0:d * cw + x1]
            sl.write_png(os.path.join(out_dir, name + "_e.png"), esheet)
            entry["emissive"] = name + "_e.png"
        meta["anims"][name] = entry
        print("[sprites] %s/%s: %d kare, hücre %dx%d" % (cid, name, frames, w, h))
    meta["height"] = round(float(height), 1)
    meta["width"] = round(float(width), 1)
    _preview(cid, previews)
    meta["walk_stride"] = round(spec.get("stride", 1.4) * sl.MODEL_SCALE, 2)
    sl.write_json(os.path.join(out_dir, "meta.json"), meta)
    print("[sprites] %s bitti (%.1f sn)" % (cid, time.time() - t0))


def _preview(cid, sheets, bg=(0.35, 0.23, 0.27)):
    """Geliştirme önizlemesi: tüm animasyon sayfaları yan yana, zemin renginde (build/sprites_preview/<id>.png)."""
    gap = 16
    h = max(s.shape[0] for s in sheets)
    w = sum(s.shape[1] for s in sheets) + gap * (len(sheets) + 1)
    img = np.zeros((h + gap * 2, w, 3), np.float32)
    img[:] = bg
    x = gap
    for s in sheets:
        a = s[..., 3:4]
        region = img[gap:gap + s.shape[0], x:x + s.shape[1]]
        region[:] = s[..., :3] * a + region * (1.0 - a)
        x += s.shape[1] + gap
    sl.write_png(os.path.join(ROOT, "build", "sprites_preview", cid + ".png"),
                 np.concatenate([img, np.ones(img.shape[:2] + (1,), np.float32)], axis=-1))


def _hand_data(m, spec, joint):
    """8 yön için silah elinin ekran konumu (dünya pikseli, ayağa göre), cart açısı, eğimi ve kameraya göre derinliği."""
    p, fwd = m.local_point(joint, spec["grip"])
    torso, _ = m.local_point("torso")
    out = []
    for d in range(8):
        rot = sl.Matrix.Rotation(math.radians(-45.0 * d), 3, "Z")
        pw = rot @ p
        fw = rot @ fwd
        tw = rot @ torso
        x = pw.dot(sl.CAM_RIGHT) * sl.KARO_PX * sl.MODEL_SCALE
        y = -pw.dot(sl.CAM_UP) * sl.KARO_PX * sl.MODEL_SCALE
        yaw = math.degrees(math.atan2(-fw.y, fw.x))
        pitch = math.degrees(math.asin(max(-1.0, min(1.0, fw.z))))
        depth = (pw - tw).dot(sl.CAM_FWD)
        out.append([round(x, 2), round(y, 2), round(yaw, 1), round(pitch, 1), round(depth, 3),
                    round(fw.dot(sl.CAM_FWD), 3)])
    return out


def render_weapon(wid, out_dir, tmp, meta):
    t0 = time.time()
    sl.reset_scene()
    m = sl.Model("w_" + wid)
    weapons.WEAPONS[wid](m)
    import bpy
    bpy.context.view_layer.update()
    r = weapons.reach(m)
    cell = int(math.ceil((r * 2.0 * sl.KARO_PX * sl.MODEL_SCALE + 8) / 2.0)) * 2 * SCALE
    yaws, pitches = weapons.YAWS, weapons.PITCHES
    grid = sl.Grid(yaws, len(pitches), cell, cell, cell // 2, cell // 2, SCALE)
    grid.setup_camera()
    for pi, pitch in enumerate(pitches):
        for j in range(yaws):
            grid.add_instance(m.coll, j, pi, -360.0 / yaws * j, pitch)
    p = sl.render_passes(tmp, "w_" + wid)
    rgb, a = sl.toon(p, OUTLINE)
    nrm, na = sl.normal_rgb(p, OUTLINE)
    sl.write_png(os.path.join(out_dir, wid + ".png"), np.concatenate([rgb, a[..., None]], axis=-1))
    sl.write_png(os.path.join(out_dir, wid + "_n.png"), sl.downsample2(np.concatenate([nrm, na[..., None]], axis=-1)))
    # Parıltı maskesi: beyaz, alfa = maske (oyunda element rengiyle boyanıp silahın üstüne çizilir)
    g = np.clip(p["glow"] * p["alpha"], 0.0, 1.0)
    sl.write_png(os.path.join(out_dir, wid + "_g.png"), np.concatenate([np.ones(g.shape + (3,), np.float32), g[..., None]], axis=-1))
    meta[wid] = {"file": wid + ".png", "normal": wid + "_n.png", "glow": wid + "_g.png", "cell": cell,
                 "yaws": yaws, "pitches": pitches, "length": round(r * sl.KARO_PX * sl.MODEL_SCALE, 1)}
    print("[sprites] silah %s: hücre %d (%.1f sn)" % (wid, cell, time.time() - t0))


def render_tiles(floor, out_dir, tmp):
    """Katın karo atlasları (1×): floor<N>.png (4 zemin varyantı, 64×32) ve blocks<N>.png (3 duvar, 2 sütun, kapı,
    çatlak duvar; 64×72, tabanın ortası (32, 56)). _n normal, _e ışıma (varsa). Dış çizgi yok."""
    t0 = time.time()
    for kind, names, cw, ch, ax, ay in (("floor", ["floor%d" % v for v in range(tiles.FLOOR_VARIANTS)], 64, 32, 32, 16),
                                        ("blocks", tiles.BLOCKS, 64, 72, 32, 56)):
        sl.reset_scene()
        grid = sl.Grid(len(names), 1, cw * SCALE, ch * SCALE, ax * SCALE, ay * SCALE, SCALE, model_scale=False)
        grid.setup_camera()
        for i, name in enumerate(names):
            m = sl.Model("t_%s" % name)
            if kind == "floor":
                tiles.floor_tile(m, floor, i, seed=floor * 100 + i)
            else:
                tiles.block(m, floor, name, seed=floor * 100 + 50 + i)
            grid.add_instance(m.coll, i, 0, 0.0)
        p = sl.render_passes(tmp, "tiles%d_%s" % (floor, kind))
        rgb, a = sl.toon(p, 0)
        nrm, na = sl.normal_rgb(p, 0)
        base = os.path.join(out_dir, "%s%d" % (kind, floor))
        sl.write_png(base + ".png", sl.downsample2(np.concatenate([rgb, a[..., None]], axis=-1)))
        sl.write_png(base + "_n.png", sl.downsample2(np.concatenate([nrm, na[..., None]], axis=-1)))
        e = sl.emissive_layer(p)
        if e is not None:
            sl.write_png(base + "_e.png", sl.downsample2(e))
    print("[sprites] karolar %d. kat (%.1f sn)" % (floor, time.time() - t0))


def render_props(out_dir, tmp):
    """Oda nesneleri (tek yön): <ad>.png (2×), _n (1×), _e (ışıma, varsa) ve props.json (hücre, çapa)."""
    import json
    t0 = time.time()
    meta = {}
    for name, fn in props.PROPS.items():
        sl.reset_scene()
        m = sl.Model("p_" + name)
        spec = fn(m)
        if spec.get("pose"):
            m.pose(spec["pose"])
        cw, ch = spec["cell"]
        ax, ay = spec["anchor"]
        grid = sl.Grid(1, 1, cw * SCALE, ch * SCALE, ax * SCALE, ay * SCALE, SCALE)
        grid.setup_camera()
        grid.add_instance(m.coll, 0, 0, -45.0 * spec.get("dir", 0))
        p = sl.render_passes(tmp, "prop_" + name)
        rgb, a = sl.toon(p, OUTLINE)
        nrm, na = sl.normal_rgb(p, OUTLINE)
        sl.write_png(os.path.join(out_dir, name + ".png"), np.concatenate([rgb, a[..., None]], axis=-1))
        sl.write_png(os.path.join(out_dir, name + "_n.png"), sl.downsample2(np.concatenate([nrm, na[..., None]], axis=-1)))
        e = sl.emissive_layer(p)
        entry = {"file": name + ".png", "normal": name + "_n.png", "size": [cw * SCALE, ch * SCALE],
                 "anchor": [ax * SCALE, ay * SCALE], "scale": SCALE}
        if e is not None:
            sl.write_png(os.path.join(out_dir, name + "_e.png"), e)
            entry["emissive"] = name + "_e.png"
        meta[name] = entry
    sl.write_json(os.path.join(out_dir, "props.json"), meta)

    print("[sprites] nesneler tamam (%.1f sn)" % (time.time() - t0))


ANIM_FILTER = None
ALL_MODELS = {**characters.CHARACTERS, **enemies.ENEMIES}


def main():
    global ANIM_FILTER
    args = _args()
    ANIM_FILTER = args["anims"]
    out = args["out"]
    tmp = os.path.join(ROOT, "build", "sprites_tmp")
    only = args["only"]
    for cid in ALL_MODELS:
        if only is None or cid in only:
            render_character(cid, os.path.join(out, "characters", cid), tmp)
    for fl in range(1, 5):
        if only is None or ("tiles%d" % fl) in only:
            render_tiles(fl, os.path.join(out, "tiles"), tmp)
    wmeta_path = os.path.join(out, "weapons", "weapons.json")
    wmeta = {}
    if os.path.exists(wmeta_path):
        import json
        with open(wmeta_path, encoding="utf-8") as f:
            wmeta = json.load(f)
    for wid in weapons.WEAPONS:
        if only is None or wid in only:
            render_weapon(wid, os.path.join(out, "weapons"), tmp, wmeta)
    sl.write_json(wmeta_path, dict(sorted(wmeta.items())))
    if only is None or "icons" in only:
        icons.render_all(os.path.join(out, "icons"), tmp)
    if only is None or "props" in only:
        render_props(os.path.join(out, "props"), tmp)
    print("[sprites] tamam")


if __name__ == "__main__":
    main()
