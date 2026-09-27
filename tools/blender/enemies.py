"""Düşman ve boss modelleri (Aşama 8): 17 temel düşman, 3 boss yardımcısı (Sürünen Göz, Duvar Gözü, Mantar Totemi)
ve 4 boss. Görsel yön: karanlık, kanlı, vahşi. Elit (büyük + aura halkası) ve malzeme varyantları
(taş, alevli, zehirli, hayalet) oyunda ton ve ölçekle aynı sprite'tan üretilir.

İskeletler: insansı (humanoid.py), sürüngen/böcek (crawler: 4 ya da 6 bacak, baş ve çene, kuyruk) ve et kütlesi (blob:
nefes alan gövde, sallanan dokunaçlar). Silahlar modele gömülüdür. Uzak saldıranlar "cast", yakın dövüşenler "attack"
animasyonunu oynatır. Anahtarlar enemies.json / bosses.json kimlikleriyle aynıdır.
"""

import math

import humanoid as hu
from characters import BLOOD, BLOOD_D, EYE_DARK, splat, _flaps, _cape

BONE = "#d1ccb8"
BONE_D = "#a39e88"
RUST = "#6b4a32"
IRON = "#3e4046"
FLESH = "#8e2a3a"
FLESH_D = "#5a1622"
VEIN = "#4a1a4a"


# ----------------------------------------------------------------------------------------------------------------
# Animasyon setleri

def _humanoid_set(ranged=False, frames=1.0):
    atk = ("cast", 5, 14.0, False, hu.cast) if ranged else ("attack", 5, 16.0, False, hu.attack)
    return [("idle", 4, 5.0, True, hu.idle), ("walk", 6, 10.0, True, hu.walk), atk,
            ("hit", 3, 14.0, False, hu.hit), ("death", 6, 10.0, False, hu.death)]


def _hide_legs(p):
    """Süzülen varlıklar (Feryatçı, Nyx'thar): bacaklar görünmez, gövde hafifçe süzülür."""
    out = dict(p)
    for side in ("r", "l"):
        out["hip_" + side] = {"rot": (0, 0, 0), "scale": 0.001}
    hips = hu._norm(out.get("hips"))
    out["hips"] = {"rot": hips["rot"], "loc": (hips["loc"][0], hips["loc"][1], hips["loc"][2] + 0.06)}
    return out


def _floating_set(ranged=True, bob=0.03):
    def idle(t):
        p = _hide_legs(hu.idle(t))
        p["hips"]["loc"] = (0, 0, 0.06 + bob * math.sin(2 * math.pi * t))
        return p

    def walk(t):
        p = _hide_legs(hu.pose_ready())
        p["hips"]["loc"] = (0, 0, 0.06 + bob * math.sin(4 * math.pi * t))
        p["torso"] = (0, 14, 0)
        return p

    def wrap(fn):
        return lambda t: _hide_legs(fn(t))

    atk = ("cast", 5, 14.0, False, wrap(hu.cast)) if ranged else ("attack", 5, 16.0, False, wrap(hu.attack))
    return [("idle", 4, 5.0, True, idle), ("walk", 6, 8.0, True, walk), atk,
            ("hit", 3, 14.0, False, wrap(hu.hit)), ("death", 6, 10.0, False, wrap(hu.death))]


# --- sürüngen / böcek (crawler) ---

def crawler(m, length, height, leg, width, legs=4, splay=12.0):
    m.joint("body", "root", (0, 0, height))
    m.joint("head", "body", (length * 0.5, 0, 0.02))
    m.joint("jaw", "head", (0.04, 0, -0.02))
    m.joint("tail", "body", (-length * 0.5, 0, 0.0))
    n = legs // 2
    for i in range(n):
        x = length * (0.32 - 0.64 * i / max(n - 1, 1))
        for side, s in (("r", -1.0), ("l", 1.0)):
            m.joint("leg%d%s" % (i, side), "body", (x, s * width, -0.01))
            m.joint("knee%d%s" % (i, side), "leg%d%s" % (i, side), (0, 0, -leg * 0.5))
    m._crawler = {"legs": n, "splay": splay}


def _crawl_pose(m, t=0.0, walking=False, amp=30.0):
    n = m._crawler["legs"]
    sp = m._crawler["splay"]
    p = {}
    a = 2.0 * math.pi * t
    for i in range(n):
        for side, s in (("r", -1.0), ("l", 1.0)):
            ph = (0.5 * (i % 2)) + (0.5 if side == "l" else 0.0)
            sw = math.sin(a + ph * 2.0 * math.pi) if walking else 0.0
            lift = max(0.0, math.cos(a + ph * 2.0 * math.pi)) if walking else 0.0
            p["leg%d%s" % (i, side)] = (s * -sp, -amp * sw, 0)
            p["knee%d%s" % (i, side)] = (0, 18 + 30 * lift, 0)
    return p


def crawler_set(m, bite=True):
    def idle(t):
        p = _crawl_pose(m)
        b = math.sin(2 * math.pi * t)
        p["body"] = {"loc": (0, 0, 0.006 * b)}
        p["head"] = (0, 4 * b, 6 * math.sin(math.pi * t * 2 + 1))
        p["tail"] = (0, 0, 15 * b)
        return p

    def walk(t):
        p = _crawl_pose(m, t, True)
        p["body"] = {"loc": (0, 0, 0.012 * abs(math.cos(2 * math.pi * t)))}
        p["tail"] = (0, 0, 20 * math.sin(2 * math.pi * t))
        return p

    def attack(t):
        base = _crawl_pose(m)
        lunge = dict(_crawl_pose(m, 0.25, True))
        lunge.update({"body": {"loc": (0.1, 0, -0.01), "rot": (0, 14, 0)}, "head": (0, 18, 0), "jaw": (0, 35, 0)})
        rear = dict(base)
        rear.update({"body": {"loc": (-0.04, 0, 0.02), "rot": (0, -12, 0)}, "head": (0, -20, 0), "jaw": (0, 25, 0)})
        return hu.keyed([(0.0, rear), (0.35, lunge), (0.6, lunge), (1.0, base)], t)

    def hit(t):
        base = _crawl_pose(m)
        hurt = dict(base)
        hurt.update({"body": {"loc": (-0.05, 0, 0.02), "rot": (8, -10, 0)}, "head": (0, -20, 10)})
        return hu.keyed([(0.0, base), (0.3, hurt), (1.0, base)], t)

    def death(t):
        base = _crawl_pose(m)
        dead = {k: (v[0], v[1], v[2]) for k, v in base.items()}
        for k in list(dead):
            if k.startswith("knee"):
                dead[k] = (0, 80, 0)
        rh = m.rest["body"].z
        dead.update({"body": {"loc": (0, 0, -rh * 0.55), "rot": (88, 0, 0)}, "head": (0, 20, 0), "jaw": (0, 30, 0)})
        return hu.keyed([(0.0, base), (0.5, dead), (1.0, dead)], t)

    atk = ("attack", 5, 16.0, False, attack)
    return [("idle", 4, 5.0, True, idle), ("walk", 6, 14.0, True, walk), atk,
            ("hit", 3, 14.0, False, hit), ("death", 6, 10.0, False, death)]


# --- et kütlesi (blob) ---

def blob(m, tentacles=()):
    m.joint("body", "root", (0, 0, 0))
    for i, (loc, rot) in enumerate(tentacles):
        m.joint("tent%d" % i, "body", loc)
        m.joint("tentb%d" % i, "tent%d" % i, (0, 0, 0))
    m._tents = len(tentacles)


def blob_set(m, static=False, ranged=False, closed_variant=False, lid="lid"):
    nt = getattr(m, "_tents", 0)

    def tents(p, t, amp=18.0, fwd=0.0):
        for i in range(nt):
            ph = i * 1.7
            p["tent%d" % i] = (amp * math.sin(2 * math.pi * t + ph), -fwd + amp * 0.6 * math.cos(2 * math.pi * t + ph), 0)
            p["tentb%d" % i] = (amp * 0.8 * math.sin(2 * math.pi * t + ph + 1.0), -fwd * 0.6, 0)
        return p

    def with_lid(p, closed):
        if lid in m.joints:
            p[lid] = {"scale": 1.0 if closed else 0.001}
        return p

    def mk(closed):
        def idle(t):
            b = math.sin(2 * math.pi * t)
            return with_lid(tents({"body": {"scale": (1 + 0.03 * b, 1 + 0.03 * b, 1 - 0.035 * b)}}, t), closed)

        def walk(t):
            b = abs(math.sin(2 * math.pi * t))
            return with_lid(tents({"body": {"scale": (1 - 0.05 * b, 1 - 0.05 * b, 1 + 0.08 * b), "loc": (0.02 * b, 0, 0)}},
                                  t * 2), closed)

        def attack(t):
            base = with_lid(tents({"body": {"scale": (1, 1, 1)}}, 0), closed)
            wind = with_lid(tents({"body": {"scale": (0.9, 1.05, 1.08), "rot": (0, -8, 0)}}, 0.1, 25, -20), closed)
            hit = with_lid(tents({"body": {"scale": (1.15, 1.0, 0.9), "rot": (0, 12, 0), "loc": (0.05, 0, 0)}}, 0.3, 25, 50),
                           closed)
            return hu.keyed([(0.0, wind), (0.35, hit), (0.6, hit), (1.0, base)], t)

        def hit_(t):
            base = with_lid(tents({"body": {"scale": (1, 1, 1)}}, 0), closed)
            sq = with_lid(tents({"body": {"scale": (1.1, 1.1, 0.86), "rot": (0, -6, 0)}}, 0.2, 30), closed)
            return hu.keyed([(0.0, base), (0.3, sq), (1.0, base)], t)
        return idle, walk, attack, hit_

    def death(t):
        base = {"body": {"scale": (1, 1, 1)}}
        flat = {"body": {"scale": (1.35, 1.35, 0.22)}}
        mid = {"body": {"scale": (1.1, 1.1, 0.7)}}
        for i in range(nt):
            flat["tent%d" % i] = (0, 70, 0)
        return with_lid(hu.keyed([(0.0, base), (0.3, mid), (0.8, flat), (1.0, flat)], t), False)

    idle, walk, attack, hit_ = mk(False)
    name = "cast" if ranged else "attack"
    out = [("idle", 4, 5.0, True, idle)]
    if not static:
        out.append(("walk", 6, 10.0, True, walk))
    out += [(name, 5, 14.0, False, attack), ("hit", 3, 14.0, False, hit_), ("death", 6, 10.0, False, death)]
    if closed_variant:
        ci, _, ca, ch = mk(True)
        out += [("idle_closed", 4, 5.0, True, ci), (name + "_closed", 5, 14.0, False, ca), ("hit_closed", 3, 14.0, False, ch)]
    return out


def _eye(m, joint, loc, r, iris="#c9486a", glow=True, lid=None):
    """Kanlı damarlı göz küresi (+X'e bakar), parlayan iris."""
    m.part(joint, "sphere", "#e6dccb", loc=loc, r=r, u=10, v=8, smooth=True, shine=0.6)
    m.part(joint, "sphere", iris, loc=(loc[0] + r * 0.82, loc[1], loc[2]), scale=(0.35, 1.0, 1.0), r=r * 0.48, u=8, v=6,
           smooth=True, emit=glow, shine=0.5)
    m.part(joint, "sphere", "#0c0708", loc=(loc[0] + r * 0.93, loc[1], loc[2]), scale=(0.3, 0.6, 1.0), r=r * 0.24, u=6, v=4,
           smooth=True)
    for k in range(4):
        a = k * 1.4 + 0.5
        m.part(joint, "box", "#a01830", loc=(loc[0] + r * 0.55 * math.cos(a) * 0.3, loc[1] + r * 0.8 * math.cos(a),
                                             loc[2] + r * 0.8 * math.sin(a)), rot=(math.degrees(a), 0, 0),
               sx=0.01, sy=r * 0.5, sz=0.006)


# ----------------------------------------------------------------------------------------------------------------
# İnsansı düşman yardımcıları

def _skeleton_body(m, bone=BONE, props=None):
    hu.skeleton(m, props or {"hip_h": 0.5, "shoulder_w": 0.17})
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("shoulder_" + side, "cyl", bone, loc=(0, 0, -0.1), r1=0.022, r2=0.026, h=0.2, n=6, shine=0.3)
        m.part("shoulder_" + side, "sphere", bone, loc=(0, 0, 0.0), r=0.04, u=6, v=4, shine=0.3)
        m.part("elbow_" + side, "cyl", bone, loc=(0, 0, -0.09), r1=0.018, r2=0.022, h=0.18, n=6, shine=0.3)
        m.part("hand_" + side, "box", bone, loc=(0.005, 0, -0.035), sx=0.045, sy=0.05, sz=0.06, shine=0.3)
        m.part("hip_" + side, "cyl", bone, loc=(0, 0, -0.11), r1=0.024, r2=0.028, h=0.23, n=6, shine=0.3)
        m.part("knee_" + side, "cyl", bone, loc=(0, 0, -0.1), r1=0.02, r2=0.024, h=0.21, n=6, shine=0.3)
        m.part("knee_" + side, "sphere", bone, loc=(0.01, 0, 0.0), r=0.03, u=6, v=4)
        m.part("ankle_" + side, "box", bone, loc=(0.03, 0, -0.03), sx=0.12, sy=0.05, sz=0.035)
    m.part("hips", "box", bone, loc=(0, 0, 0), sx=0.1, sy=0.18, sz=0.08, top=(0.8, 1.2), shine=0.3)
    m.part("torso", "cyl", bone, loc=(0, 0, 0.1), r1=0.02, r2=0.02, h=0.22, n=6)
    for i, z in enumerate((0.14, 0.19, 0.24, 0.29)):
        w = 0.12 - abs(i - 1.5) * 0.012
        m.part("torso", "cyl", bone, loc=(0.01, 0, z), scale=(0.75, 1.0, 1.0), r1=w, r2=w, h=0.022, n=10, shine=0.3)
    m.part("torso", "box", BONE_D, loc=(0.075, 0, 0.23), sx=0.02, sy=0.03, sz=0.16)
    m.part("torso", "cyl", bone, loc=(0, 0, 0.3), rot=(90, 0, 0), r1=0.02, r2=0.02, h=0.3, n=6)
    # kafatası
    m.part("head", "sphere", bone, loc=(0.0, 0, 0.1), scale=(1.05, 0.9, 1.0), r=0.085, u=9, v=7, smooth=True, shine=0.35)
    m.part("head", "box", bone, loc=(0.05, 0, 0.03), sx=0.07, sy=0.1, sz=0.05, top=(0.9, 0.85))
    for s in (-1.0, 1.0):
        m.part("head", "box", EYE_DARK, loc=(0.078, s * 0.03, 0.1), sx=0.02, sy=0.035, sz=0.035)
        m.part("head", "box", "#ff2a1a", loc=(0.085, s * 0.03, 0.1), sx=0.01, sy=0.012, sz=0.012, emit=True)
    m.part("head", "box", EYE_DARK, loc=(0.088, 0, 0.06), sx=0.01, sy=0.02, sz=0.02)
    for i in range(4):
        m.part("head", "box", "#e8e2cf", loc=(0.078, -0.03 + 0.02 * i, 0.02), sx=0.01, sy=0.012, sz=0.02)


def _sword(m, joint, length=0.5, color="#6b6258"):
    m.part(joint, "cyl", "#3a2416", loc=(0.005, 0, -0.035), rot=(0, 90, 0), r1=0.018, r2=0.018, h=0.12, n=6)
    m.part(joint, "box", RUST, loc=(0.07, 0, -0.035), sx=0.025, sy=0.15, sz=0.03, shine=0.4)
    t = 0.011
    m.part(joint, "hull", color, shine=0.5, grime=0.5,
           points=[(0.08, -0.03, -0.035 - t), (0.08, 0.03, -0.035 - t), (0.08, -0.03, -0.035 + t), (0.08, 0.03, -0.035 + t),
                   (0.08 + length, 0.0, -0.035)])
    m.part(joint, "box", BLOOD, loc=(0.08 + length * 0.7, 0, -0.035), sx=length * 0.4, sy=0.04, sz=0.026, shine=0.7)


# ----------------------------------------------------------------------------------------------------------------
# 1. kat: Damarlı Mağara

def skeleton_warrior(m):
    """İskelet Savaşçı: paslı miğfer, yırtık bez, kanlı paslı kılıç."""
    _skeleton_body(m)
    m.part("head", "sphere", RUST, loc=(-0.01, 0, 0.14), scale=(1.0, 1.0, 0.7), r=0.09, u=8, v=5, shine=0.3, grime=0.6)
    _flaps(m, "#4a3f33", 0.18, fx=0.06, bx=-0.06, width=0.1, grime=0.6)
    m.part("torso", "box", RUST, loc=(0, -0.15, 0.3), sx=0.1, sy=0.07, sz=0.05, shine=0.3, grime=0.6)
    _sword(m, "hand_r")
    splat(m, "torso", (0.06, 0.03, 0.2), 0.02)
    return {"anims": _humanoid_set(), "cell": (104, 100), "anchor": (52, 76)}


def skeleton_archer(m):
    """İskelet Okçu: başında yırtık kukuleta, elinde kemik yay, sırtında sadak."""
    _skeleton_body(m)
    m.part("head", "hull", "#3b3a2c", grime=0.6, points=[(0.0, 0, 0.21), (-0.1, 0, 0.16), (-0.1, 0, 0.0), (0.05, 0.09, 0.12),
                                                         (0.05, -0.09, 0.12), (-0.06, 0.1, 0.02), (-0.06, -0.1, 0.02),
                                                         (0.02, 0.1, -0.02), (0.02, -0.1, -0.02), (0.07, 0, 0.18)])
    for i in range(7):
        z = -0.3 + 0.6 * i / 6.0
        z2 = -0.3 + 0.6 * (i + 1) / 6.0 if i < 6 else z
        if i < 6:
            m.part("hand_r", "cyl", BONE_D, loc=(0.06 - 0.1 * ((z + z2) / 2 / 0.3) ** 2, 0, -0.035 + (z + z2) / 2),
                   r1=0.012, r2=0.012, h=0.1, n=5)
    m.part("hand_r", "cyl", "#8a8270", loc=(-0.045, 0, -0.035), r1=0.003, r2=0.003, h=0.6, n=4)
    m.part("torso", "cyl", "#3a2a1a", loc=(-0.08, 0.05, 0.2), rot=(18, 0, 0), r1=0.04, r2=0.045, h=0.26, n=7)
    for dy in (0.0, 0.02):
        m.part("torso", "box", "#8a1a1a", loc=(-0.08, 0.1 + dy, 0.35), rot=(18, 0, 0), sx=0.008, sy=0.02, sz=0.04)
    _flaps(m, "#3b3a2c", 0.16, fx=0.06, bx=-0.06, width=0.1, grime=0.6)
    return {"anims": _humanoid_set(ranged=True), "cell": (104, 100), "anchor": (52, 76)}


def cave_rat(m):
    """Mağara Faresi: uyuz kara post, çıplak pembe kuyruk, kızıl gözler, kanlı dişler."""
    crawler(m, 0.36, 0.12, 0.12, 0.06, legs=4, splay=8)
    fur = "#3e322a"
    m.part("body", "sphere", fur, scale=(1.4, 0.85, 0.75), r=0.12, u=9, v=7, smooth=True, grime=0.6)
    m.part("body", "sphere", "#2e2520", loc=(-0.02, 0, 0.06), scale=(1.2, 0.6, 0.4), r=0.1, u=7, v=5, smooth=True, grime=0.7)
    m.part("head", "hull", fur, grime=0.6, points=[(-0.04, -0.06, 0.03), (-0.04, 0.06, 0.03), (-0.04, 0, -0.05),
                                                   (0.13, 0, 0.0), (0.02, -0.04, 0.05), (0.02, 0.04, 0.05), (0.1, 0, -0.03)])
    m.part("jaw", "box", "#c08080", loc=(0.06, 0, -0.03), sx=0.06, sy=0.03, sz=0.015)
    for s in (-1.0, 1.0):
        m.part("head", "sphere", "#ff2a20", loc=(0.05, s * 0.035, 0.025), r=0.012, u=5, v=3, emit=True)
        m.part("head", "sphere", "#b07070", loc=(-0.02, s * 0.05, 0.06), scale=(0.4, 1.0, 1.0), r=0.03, u=6, v=4)
    m.part("head", "box", "#e8e0c0", loc=(0.12, 0, -0.025), sx=0.01, sy=0.02, sz=0.025)
    splat(m, "head", (0.11, 0.0, -0.035), 0.014, normal="-z")
    m.part("tail", "cyl", "#a86868", loc=(-0.12, 0, -0.02), rot=(0, 80, 0), r1=0.004, r2=0.018, h=0.26, n=5)
    for leg in ("leg0r", "leg0l", "leg1r", "leg1l"):
        m.part(leg, "cyl", fur, loc=(0, 0, -0.03), r1=0.018, r2=0.025, h=0.06, n=5)
    for kn in ("knee0r", "knee0l", "knee1r", "knee1l"):
        m.part(kn, "cyl", "#b07070", loc=(0, 0, -0.03), r1=0.008, r2=0.014, h=0.06, n=5)
    return {"anims": crawler_set(m), "cell": (80, 60), "anchor": (40, 40), "stride": 0.8}


def eye_spawn(m):
    """Göz Yavrusu: duvardan çıkan etli sapın ucunda damarlı, parlayan kızıl irisli iri göz."""
    blob(m)
    m.part("body", "ico", FLESH_D, loc=(-0.12, 0, 0.32), scale=(0.6, 1.2, 1.4), r=0.2, sub=2, smooth=True, grime=0.5)
    m.part("body", "cyl", FLESH, loc=(-0.02, 0, 0.36), rot=(0, 70, 0), r1=0.06, r2=0.08, h=0.22, n=8, smooth=True)
    _eye(m, "body", (0.08, 0, 0.38), 0.13)
    for k in range(3):
        m.part("body", "cyl", VEIN, loc=(-0.05, -0.08 + 0.08 * k, 0.2 + 0.08 * k), rot=(30 * k - 30, 60, 0),
               r1=0.012, r2=0.016, h=0.3, n=5, shine=0.4)
    splat(m, "body", (-0.02, 0.05, 0.26), 0.03, normal="+z", dark=True)
    return {"anims": blob_set(m, static=True, ranged=True), "cell": (90, 100), "anchor": (45, 80)}


def vein_mass(m):
    """Damar Kütlesi: nabız gibi atan yumrulu et kütlesi, mor damarlar, gözler, dişli ağız, iki dokunaç."""
    blob(m, tentacles=[((0.12, -0.2, 0.3), None), ((0.12, 0.2, 0.3), None)])
    for loc, r in (((0, 0, 0.28), 0.3), ((-0.12, 0.1, 0.4), 0.2), ((0.05, -0.14, 0.45), 0.18), ((-0.05, -0.05, 0.55), 0.16),
                   ((0.1, 0.12, 0.2), 0.17)):
        m.part("body", "ico", FLESH, loc=loc, r=r, sub=2, smooth=True, shine=0.35, grime=0.45)
    for k in range(6):
        a = k * 1.05
        m.part("body", "cyl", VEIN, loc=(0.12 * math.cos(a), 0.2 * math.sin(a), 0.3 + 0.1 * math.sin(a * 2)),
               rot=(40 * math.sin(a), 50 + 20 * math.cos(a), math.degrees(a)), r1=0.014, r2=0.02, h=0.35, n=5, shine=0.5)
    m.part("body", "sphere", "#1a0508", loc=(0.26, 0, 0.26), scale=(0.3, 1.0, 0.55), r=0.13, u=8, v=6)
    for i in range(6):
        y = -0.1 + 0.04 * i
        m.part("body", "hull", "#e0d6c0", points=[(0.27, y - 0.012, 0.32), (0.27, y + 0.012, 0.32), (0.29, y, 0.32),
                                                  (0.29, y, 0.27)])
        m.part("body", "hull", "#e0d6c0", points=[(0.27, y - 0.012, 0.2), (0.27, y + 0.012, 0.2), (0.29, y, 0.2),
                                                  (0.29, y, 0.25)])
    _eye(m, "body", (0.18, 0.12, 0.45), 0.06)
    _eye(m, "body", (0.12, -0.1, 0.55), 0.05)
    for i in (0, 1):
        m.part("tent%d" % i, "cyl", FLESH_D, loc=(0.1, 0, -0.08), rot=(0, 120, 0), r1=0.03, r2=0.06, h=0.25, n=6, smooth=True)
        m.part("tentb%d" % i, "hull", BONE, points=[(0.2, -0.02, -0.12), (0.2, 0.02, -0.12), (0.2, 0, -0.1), (0.3, 0, -0.22)])
    splat(m, "body", (0.28, 0.0, 0.14), 0.05, normal="+x")
    return {"anims": blob_set(m), "cell": (140, 130), "anchor": (70, 100), "stride": 0.9}


# ----------------------------------------------------------------------------------------------------------------
# 2. kat: Mantar Mağaraları

def spore_beetle(m):
    """Sporlu Böcek: altı bacaklı, sert kabuklu, sırtında parlayan zehirli spor keseleri, kıskaç çeneler."""
    crawler(m, 0.34, 0.1, 0.12, 0.08, legs=6, splay=40)
    shell = "#3f5226"
    m.part("body", "sphere", shell, loc=(0, 0, 0.03), scale=(1.3, 1.0, 0.65), r=0.14, u=10, v=7, smooth=True, shine=0.55)
    m.part("body", "box", "#20291a", loc=(0.0, 0, 0.1), sx=0.3, sy=0.01, sz=0.02)
    for k, (x, y) in enumerate(((0.02, 0.06), (-0.06, -0.05), (-0.08, 0.06), (0.05, -0.07))):
        m.part("body", "sphere", "#c8e04a", loc=(x, y, 0.1), r=0.028, u=6, v=4, emit=True)
    m.part("head", "sphere", "#26301a", loc=(0.02, 0, 0), scale=(1.0, 1.1, 0.8), r=0.06, u=7, v=5, shine=0.5)
    for s in (-1.0, 1.0):
        m.part("jaw", "hull", "#1a1612", points=[(0.0, s * 0.03, 0.0), (0.0, s * 0.05, 0.0), (0.0, s * 0.04, 0.015),
                                                 (0.08, s * 0.01, -0.01)], shine=0.6)
        m.part("head", "sphere", "#e0a020", loc=(0.05, s * 0.035, 0.02), r=0.01, u=5, v=3, emit=True)
    for i in range(3):
        for side in ("r", "l"):
            m.part("leg%d%s" % (i, side), "cyl", "#1e2414", loc=(0, 0, -0.03), r1=0.01, r2=0.015, h=0.06, n=5, shine=0.5)
            m.part("knee%d%s" % (i, side), "cyl", "#1e2414", loc=(0, 0, -0.03), r1=0.005, r2=0.01, h=0.06, n=5, shine=0.5)
    return {"anims": crawler_set(m), "cell": (80, 60), "anchor": (40, 40), "stride": 0.8}


def _mushroom_cap(m, joint, r, color, spots, z, glow_spots=False):
    m.part(joint, "sphere", color, loc=(0, 0, z), scale=(1.0, 1.0, 0.45), r=r, u=12, v=8, smooth=True, shine=0.35, grime=0.4)
    m.part(joint, "cyl", "#d8c8a8", loc=(0, 0, z - 0.01), r1=r * 0.92, r2=r * 0.3, h=0.03, n=12)
    for k in range(7):
        a = k * 0.9
        rr = r * (0.3 + 0.5 * ((k * 37) % 10) / 10.0)
        m.part(joint, "sphere", spots, loc=(rr * math.cos(a), rr * math.sin(a), z + r * 0.4 * math.sqrt(max(0.0, 1 - (rr / r) ** 2))),
               scale=(1.0, 1.0, 0.4), r=r * 0.12, u=6, v=4, emit=glow_spots)


def mushroom_man(m):
    """Mantar Adam: iri, kök gibi kollu mantar dev; başında benekli şapka, kaba yumruklar, kanlı ağız yarığı."""
    hu.skeleton(m, {"hip_h": 0.5, "shoulder_w": 0.23, "upper": 0.22, "fore": 0.22, "neck": 0.33})
    stalk = "#b8a488"
    stalk_d = "#8a7458"
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("shoulder_" + side, "cyl", stalk_d, loc=(0, 0, -0.1), r1=0.055, r2=0.07, h=0.22, n=7, smooth=True, grime=0.5)
        m.part("elbow_" + side, "cyl", stalk_d, loc=(0, 0, -0.1), r1=0.06, r2=0.055, h=0.22, n=7, smooth=True, grime=0.5)
        m.part("hand_" + side, "ico", stalk, loc=(0.0, 0, -0.06), r=0.08, sub=1, grime=0.5)
        m.part("hip_" + side, "cyl", stalk_d, loc=(0, 0, -0.11), r1=0.07, r2=0.08, h=0.23, n=7, smooth=True)
        m.part("knee_" + side, "cyl", stalk_d, loc=(0, 0, -0.1), r1=0.07, r2=0.07, h=0.21, n=7, smooth=True)
        m.part("ankle_" + side, "ico", "#5a4a38", loc=(0.02, 0, -0.03), scale=(1.4, 1.0, 0.6), r=0.07, sub=1)
    m.part("hips", "ico", stalk, loc=(0, 0, 0.02), scale=(1.0, 1.3, 0.8), r=0.14, sub=2, smooth=True, grime=0.5)
    m.part("torso", "ico", stalk, loc=(0, 0, 0.18), scale=(0.9, 1.3, 1.1), r=0.17, sub=2, smooth=True, grime=0.5)
    m.part("head", "cyl", stalk, loc=(0, 0, 0.04), r1=0.09, r2=0.08, h=0.12, n=8, smooth=True)
    m.part("head", "box", "#2a0808", loc=(0.085, 0, 0.03), sx=0.02, sy=0.1, sz=0.02)
    splat(m, "head", (0.088, 0.0, 0.01), 0.02, dark=True, stretch=1.4)
    for s in (-1.0, 1.0):
        m.part("head", "sphere", "#d0f040", loc=(0.08, s * 0.035, 0.07), r=0.014, u=5, v=3, emit=True)
    _mushroom_cap(m, "head", 0.24, "#7a2a1e", "#d8c8a8", 0.13)
    return {"anims": _humanoid_set(), "cell": (140, 140), "anchor": (70, 110), "stride": 1.2}


def poison_spitter(m):
    """Zehir Tükürücü: kambur, şiş karınlı mantar hortlağı; boynunda parlayan zehir kesesi."""
    hu.skeleton(m, {"hip_h": 0.44, "thigh": 0.2, "shin": 0.2, "shoulder_w": 0.16, "neck": 0.3})
    skin = "#6f7a4a"
    for side in ("r", "l"):
        m.part("shoulder_" + side, "cyl", skin, loc=(0, 0, -0.1), r1=0.03, r2=0.04, h=0.2, n=7, smooth=True)
        m.part("elbow_" + side, "cyl", skin, loc=(0, 0, -0.09), r1=0.025, r2=0.032, h=0.18, n=7, smooth=True)
        m.part("hand_" + side, "hull", "#4a5230", points=[(0.0, -0.03, 0.0), (0.0, 0.03, 0.0), (0.03, 0, -0.03), (0.06, 0, -0.1),
                                                         (0.02, -0.03, -0.08), (0.02, 0.03, -0.08)])
        m.part("hip_" + side, "cyl", skin, loc=(0, 0, -0.1), r1=0.035, r2=0.045, h=0.2, n=7, smooth=True)
        m.part("knee_" + side, "cyl", skin, loc=(0, 0, -0.1), r1=0.03, r2=0.035, h=0.2, n=7, smooth=True)
        m.part("ankle_" + side, "box", "#4a5230", loc=(0.03, 0, -0.03), sx=0.12, sy=0.07, sz=0.05)
    m.part("hips", "ico", skin, loc=(0.03, 0, 0.05), scale=(1.1, 1.1, 0.9), r=0.14, sub=2, smooth=True, shine=0.35)
    m.part("torso", "ico", skin, loc=(0.0, 0, 0.18), scale=(0.9, 1.1, 1.0), r=0.12, sub=2, smooth=True, shine=0.35)
    m.part("torso", "ico", "#9ad83a", loc=(0.08, 0, 0.3), scale=(1.0, 1.1, 0.8), r=0.07, sub=2, smooth=True, emit=True)
    m.part("head", "ico", skin, loc=(0.03, 0, 0.06), scale=(1.2, 0.9, 0.8), r=0.08, sub=2, smooth=True)
    m.part("head", "sphere", "#3a2a2a", loc=(0.1, 0, 0.03), scale=(0.5, 1.0, 0.6), r=0.04, u=6, v=4)
    for s in (-1.0, 1.0):
        m.part("head", "sphere", "#e0f060", loc=(0.09, s * 0.035, 0.08), r=0.012, u=5, v=3, emit=True)
    _mushroom_cap(m, "torso", 0.1, "#4a3a5a", "#9ad83a", 0.32, glow_spots=True)
    splat(m, "hips", (0.15, 0.04, 0.05), 0.025, normal="+x")
    return {"anims": _humanoid_set(ranged=True), "cell": (110, 100), "anchor": (55, 80)}


def mushroom_healer(m):
    """Mantar Şifacı: yosun cübbeli ince şifacı, başında mor parlayan mantar, elinde ucu ışıyan kök asa."""
    hu.skeleton(m, {"hip_h": 0.5, "shoulder_w": 0.16, "neck": 0.34})
    robe = "#3a4a2a"
    skin = "#c8b8a0"
    for side in ("r", "l"):
        m.part("shoulder_" + side, "cyl", robe, loc=(0, 0, -0.1), r1=0.04, r2=0.045, h=0.2, n=7)
        m.part("elbow_" + side, "cyl", robe, loc=(0, 0, -0.09), r1=0.05, r2=0.04, h=0.18, n=7)
        m.part("hand_" + side, "box", skin, loc=(0.005, 0, -0.035), sx=0.05, sy=0.05, sz=0.06)
        m.part("hip_" + side, "cyl", "#2a3420", loc=(0, 0, -0.11), r1=0.05, r2=0.055, h=0.23, n=7)
        m.part("knee_" + side, "cyl", "#2a3420", loc=(0, 0, -0.1), r1=0.04, r2=0.05, h=0.21, n=7)
        m.part("ankle_" + side, "box", "#2a2018", loc=(0.03, 0, -0.03), sx=0.13, sy=0.07, sz=0.05)
    _flaps(m, robe, 0.38, fx=0.08, bx=-0.08, width=0.12, grime=0.6)
    m.part("hips", "cyl", robe, loc=(0, 0, -0.02), r1=0.12, r2=0.11, h=0.12, n=9)
    m.part("torso", "box", robe, loc=(0, 0, 0.16), sx=0.17, sy=0.23, sz=0.32, top=(1.0, 1.1), grime=0.6)
    m.part("head", "sphere", skin, loc=(0.01, 0, 0.08), scale=(1.0, 0.9, 1.1), r=0.075, u=8, v=6, smooth=True)
    for s in (-1.0, 1.0):
        m.part("head", "sphere", "#e0a0ff", loc=(0.07, s * 0.028, 0.09), r=0.011, u=5, v=3, emit=True)
    _mushroom_cap(m, "head", 0.15, "#5a2a6a", "#e070ff", 0.17, glow_spots=True)
    m.part("hand_r", "cyl", "#3a2a1a", loc=(0.02, 0, 0.05), rot=(0, 10, 0), r1=0.015, r2=0.02, h=0.7, n=6)
    m.part("hand_r", "ico", "#e070ff", loc=(0.06, 0, 0.42), r=0.04, sub=1, emit=True)
    return {"anims": _humanoid_set(ranged=True), "cell": (110, 120), "anchor": (55, 95)}


def spore_totem(m):
    """Mantar Totemi (Mycela'nın yardımcısı): kalın saplı, parlayan mor benekli iri mantar sütunu, köklü taban."""
    blob(m)
    m.part("body", "cyl", "#b8a488", loc=(0, 0, 0.28), r1=0.14, r2=0.1, h=0.56, n=9, smooth=True, grime=0.5)
    for k in range(5):
        a = k * 1.25
        m.part("body", "cyl", "#8a7458", loc=(0.14 * math.cos(a), 0.14 * math.sin(a), 0.04), rot=(70 * math.sin(a), -70 * math.cos(a), 0),
               r1=0.02, r2=0.04, h=0.2, n=5)
    _mushroom_cap(m, "body", 0.3, "#4a2a5a", "#d070ff", 0.6, glow_spots=True)
    for s in (-1.0, 1.0):
        m.part("body", "sphere", "#e0a0ff", loc=(0.1, s * 0.04, 0.4), r=0.02, u=5, v=3, emit=True)
    return {"anims": blob_set(m, static=True), "cell": (130, 130), "anchor": (65, 105)}


# ----------------------------------------------------------------------------------------------------------------
# 3. kat: Kül Dökümhanesi

LAVA = "#ff6a1a"


def stone_golemling(m):
    """Taş Golemcik: yontulmamış kaya bloklarından iri gövde, çatlaklarından lav parlıyor, taş yumruklar."""
    hu.skeleton(m, {"hip_h": 0.44, "thigh": 0.2, "shin": 0.2, "shoulder_w": 0.25, "upper": 0.2, "fore": 0.22, "neck": 0.3})
    rock = "#6a655e"
    rock_d = "#4a4640"
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("shoulder_" + side, "ico", rock, loc=(0, s * 0.02, -0.02), r=0.11, sub=1, grime=0.6, shine=0.15)
        m.part("shoulder_" + side, "ico", rock_d, loc=(0, 0, -0.14), r=0.075, sub=1, grime=0.6)
        m.part("elbow_" + side, "ico", rock, loc=(0, 0, -0.1), scale=(1.0, 1.0, 1.3), r=0.08, sub=1, grime=0.6)
        m.part("hand_" + side, "ico", rock_d, loc=(0.0, 0, -0.06), r=0.1, sub=1, grime=0.6)
        m.part("hip_" + side, "ico", rock_d, loc=(0, 0, -0.1), scale=(1.0, 1.0, 1.3), r=0.08, sub=1, grime=0.6)
        m.part("knee_" + side, "ico", rock, loc=(0, 0, -0.12), scale=(1.1, 1.0, 1.1), r=0.09, sub=1, grime=0.6)
        m.part("elbow_" + side, "box", LAVA, loc=(0.06, 0, -0.1), sx=0.01, sy=0.02, sz=0.1, emit=True)
    m.part("hips", "ico", rock_d, loc=(0, 0, 0.02), scale=(1.0, 1.3, 0.7), r=0.15, sub=1, grime=0.6)
    m.part("torso", "ico", rock, loc=(0, 0, 0.2), scale=(0.95, 1.35, 1.1), r=0.2, sub=1, grime=0.6, shine=0.15)
    m.part("torso", "hull", LAVA, emit=True, points=[(0.17, -0.03, 0.1), (0.17, 0.03, 0.1), (0.19, 0.0, 0.25), (0.16, 0.06, 0.3),
                                                      (0.16, -0.06, 0.15)])
    m.part("head", "ico", rock, loc=(0.03, 0, 0.05), scale=(1.1, 1.0, 0.8), r=0.09, sub=1, grime=0.6)
    for s in (-1.0, 1.0):
        m.part("head", "box", LAVA, loc=(0.1, s * 0.035, 0.06), sx=0.01, sy=0.025, sz=0.012, emit=True)
    return {"anims": _humanoid_set(), "cell": (150, 130), "anchor": (75, 100), "stride": 1.1}


def ember_hound(m):
    """Kor Köpeği: kömürleşmiş kara post, kaburgaları görünen sıska gövde, lav çatlakları, alevden yele, kor gözler."""
    crawler(m, 0.5, 0.22, 0.22, 0.08, legs=4, splay=6)
    char = "#1e1614"
    m.part("body", "sphere", char, scale=(1.5, 0.75, 0.8), r=0.14, u=10, v=7, smooth=True, grime=0.5, shine=0.2)
    for k in range(4):
        m.part("body", "box", "#2e2420", loc=(0.05 - 0.05 * k, 0, 0.0), sx=0.02, sy=0.2, sz=0.18)
    for k in range(5):
        m.part("body", "hull", LAVA, emit=True, points=[(0.12 - 0.06 * k, -0.02, 0.1), (0.12 - 0.06 * k, 0.02, 0.1),
                                                         (0.1 - 0.06 * k, 0.0, 0.2 + 0.03 * (k % 2))])
    m.part("head", "hull", char, grime=0.5, points=[(-0.05, -0.06, 0.05), (-0.05, 0.06, 0.05), (-0.05, 0, -0.05),
                                                    (0.16, 0, -0.01), (0.03, -0.05, 0.06), (0.03, 0.05, 0.06), (0.13, 0, -0.04)])
    m.part("jaw", "hull", char, points=[(0.0, -0.035, -0.02), (0.0, 0.035, -0.02), (0.1, 0, -0.04), (0.0, 0, -0.05)])
    for s in (-1.0, 1.0):
        m.part("head", "sphere", LAVA, loc=(0.06, s * 0.04, 0.04), r=0.013, u=5, v=3, emit=True)
        m.part("head", "hull", char, points=[(-0.02, s * 0.03, 0.06), (0.0, s * 0.05, 0.06), (-0.01, s * 0.04, 0.05),
                                             (-0.04, s * 0.05, 0.13)])
    m.part("head", "box", "#e8e0c0", loc=(0.13, 0, -0.045), sx=0.02, sy=0.05, sz=0.02)
    m.part("tail", "cyl", char, loc=(-0.1, 0, 0.04), rot=(0, 60, 0), r1=0.01, r2=0.03, h=0.2, n=5)
    m.part("tail", "ico", LAVA, loc=(-0.19, 0, 0.1), r=0.03, sub=1, emit=True)
    for i in range(2):
        for side in ("r", "l"):
            m.part("leg%d%s" % (i, side), "cyl", char, loc=(0, 0, -0.055), r1=0.02, r2=0.035, h=0.11, n=6)
            m.part("knee%d%s" % (i, side), "cyl", char, loc=(0, 0, -0.055), r1=0.015, r2=0.02, h=0.11, n=6)
    return {"anims": crawler_set(m), "cell": (110, 90), "anchor": (55, 64), "stride": 1.3}


def slag_mage(m):
    """Cüruf Büyücüsü: yanık kara cübbe, demir maske, erimiş lav elleri ve cüppedeki kor çatlakları."""
    hu.skeleton(m, {"hip_h": 0.5, "shoulder_w": 0.17, "neck": 0.35})
    robe = "#241a16"
    for side in ("r", "l"):
        m.part("shoulder_" + side, "cyl", robe, loc=(0, 0, -0.1), r1=0.04, r2=0.05, h=0.2, n=7)
        m.part("elbow_" + side, "cyl", robe, loc=(0, 0, -0.09), r1=0.055, r2=0.04, h=0.18, n=7)
        m.part("hand_" + side, "ico", LAVA, loc=(0.005, 0, -0.04), r=0.04, sub=1, emit=True)
        m.part("hip_" + side, "cyl", robe, loc=(0, 0, -0.11), r1=0.05, r2=0.055, h=0.23, n=7)
        m.part("knee_" + side, "cyl", robe, loc=(0, 0, -0.1), r1=0.04, r2=0.05, h=0.21, n=7)
        m.part("ankle_" + side, "box", "#1a1210", loc=(0.03, 0, -0.03), sx=0.13, sy=0.07, sz=0.05)
    _flaps(m, robe, 0.42, fx=0.08, bx=-0.08, width=0.13, grime=0.6)
    m.part("hips", "cyl", robe, loc=(0, 0, -0.02), r1=0.12, r2=0.11, h=0.12, n=9)
    m.part("torso", "box", robe, loc=(0, 0, 0.16), sx=0.17, sy=0.24, sz=0.32, top=(1.0, 1.1), grime=0.6)
    for z in (0.08, 0.2):
        m.part("torso", "box", LAVA, loc=(0.087, 0.02, z), rot=(25, 0, 0), sx=0.004, sy=0.012, sz=0.08, emit=True)
    m.part("head", "hull", "#1a1411", points=[(0.0, 0, 0.22), (-0.1, 0, 0.16), (-0.1, 0, 0.0), (0.05, 0.09, 0.12),
                                              (0.05, -0.09, 0.12), (-0.06, 0.1, 0.02), (-0.06, -0.1, 0.02), (0.02, 0.1, -0.02),
                                              (0.02, -0.1, -0.02), (0.07, 0, 0.18)])
    m.part("head", "box", "#4a4a50", loc=(0.06, 0, 0.08), sx=0.03, sy=0.12, sz=0.12, shine=0.6)
    for s in (-1.0, 1.0):
        m.part("head", "box", LAVA, loc=(0.077, s * 0.03, 0.1), sx=0.006, sy=0.025, sz=0.01, emit=True)
    return {"anims": _humanoid_set(ranged=True), "cell": (110, 120), "anchor": (55, 95)}


def iron_guard(m):
    """Demir Muhafız: kara demir zırhlı iri muhafız, önde kulesi kalkan, paslı çivili gürz, miğfer yarığında kızıl gözler."""
    hu.skeleton(m, {"hip_h": 0.5, "shoulder_w": 0.21, "neck": 0.36})
    plate = "#3a3c42"
    plate_d = "#26272b"
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("shoulder_" + side, "sphere", plate, loc=(0, s * 0.02, 0), scale=(1.0, 1.0, 0.8), r=0.09, u=8, v=6, shine=0.6)
        m.part("shoulder_" + side, "cyl", plate_d, loc=(0, 0, -0.1), r1=0.045, r2=0.05, h=0.2, n=7, shine=0.4)
        m.part("elbow_" + side, "cyl", plate, loc=(0, 0, -0.09), r1=0.045, r2=0.055, h=0.18, n=7, shine=0.5)
        m.part("hand_" + side, "box", plate_d, loc=(0.005, 0, -0.035), sx=0.07, sy=0.07, sz=0.07, shine=0.4)
        m.part("hip_" + side, "cyl", plate_d, loc=(0, 0, -0.11), r1=0.06, r2=0.07, h=0.23, n=7, shine=0.4)
        m.part("knee_" + side, "cyl", plate, loc=(0, 0, -0.1), r1=0.055, r2=0.06, h=0.21, n=7, shine=0.5)
        m.part("ankle_" + side, "box", plate_d, loc=(0.03, 0, -0.035), sx=0.17, sy=0.09, sz=0.07, shine=0.4)
    m.part("hips", "cyl", "#4a4c52", loc=(0, 0, -0.03), r1=0.15, r2=0.13, h=0.14, n=10, shine=0.4, grime=0.5)
    m.part("torso", "box", plate, loc=(0, 0, 0.17), sx=0.23, sy=0.3, sz=0.32, top=(1.06, 1.12), shine=0.6, grime=0.5)
    m.part("head", "cyl", plate, loc=(0.0, 0, 0.1), r1=0.1, r2=0.085, h=0.2, n=8, shine=0.6)
    m.part("head", "box", EYE_DARK, loc=(0.09, 0, 0.12), sx=0.03, sy=0.12, sz=0.02)
    for s in (-1.0, 1.0):
        m.part("head", "box", "#ff2a1a", loc=(0.1, s * 0.03, 0.12), sx=0.01, sy=0.015, sz=0.01, emit=True)
    # Kule kalkan (sol kol, önde)
    m.joint("gshield", "elbow_l", (0.05, 0.02, -0.1))
    m.part("gshield", "box", "#2e2f33", loc=(0.06, 0, 0.05), sx=0.03, sy=0.3, sz=0.46, shine=0.5, grime=0.55)
    m.part("gshield", "box", RUST, loc=(0.078, 0, 0.05), sx=0.01, sy=0.06, sz=0.4, grime=0.6)
    m.part("gshield", "cyl", "#8a8c92", loc=(0.1, 0, 0.1), rot=(0, 90, 0), r1=0.03, r2=0.0, h=0.06, n=6, shine=0.8)
    splat(m, "gshield", (0.078, 0.08, -0.05), 0.04)
    # Gürz (sağ el)
    m.part("hand_r", "cyl", "#3a2a1c", loc=(0.15, 0, -0.035), rot=(0, 90, 0), r1=0.02, r2=0.02, h=0.3, n=6)
    m.part("hand_r", "ico", RUST, loc=(0.33, 0, -0.035), r=0.065, sub=1, shine=0.4, grime=0.6)
    m.part("hand_r", "ico", BLOOD, loc=(0.36, 0.02, 0.0), scale=(1, 1, 0.4), r=0.035, sub=1, shine=0.7)
    return {"anims": _humanoid_set(), "cell": (130, 120), "anchor": (65, 95), "shield_pose": True}


# ----------------------------------------------------------------------------------------------------------------
# 4. kat: Boşluk

VOID = "#8a5aff"


def shade(m):
    """Gölge: sıska, kararmış mor-kara gövde, uzun pençeler, beyaz boş gözler, sırtında duman gibi dağılan pelerin."""
    hu.skeleton(m, {"hip_h": 0.52, "shoulder_w": 0.16, "upper": 0.22, "fore": 0.21, "neck": 0.34})
    body = "#1a1428"
    for side in ("r", "l"):
        m.part("shoulder_" + side, "cyl", body, loc=(0, 0, -0.1), r1=0.028, r2=0.04, h=0.22, n=7, smooth=True, shine=0.3)
        m.part("elbow_" + side, "cyl", body, loc=(0, 0, -0.1), r1=0.022, r2=0.03, h=0.21, n=7, smooth=True, shine=0.3)
        for y in (-0.02, 0.0, 0.02):
            m.part("hand_" + side, "hull", "#0e0a16", points=[(0.0, y - 0.01, 0.0), (0.0, y + 0.01, 0.0), (0.01, y, 0.01),
                                                             (0.07, y * 1.5, -0.14)], shine=0.5)
        m.part("hip_" + side, "cyl", body, loc=(0, 0, -0.11), r1=0.035, r2=0.05, h=0.23, n=7, smooth=True)
        m.part("knee_" + side, "cyl", body, loc=(0, 0, -0.1), r1=0.025, r2=0.035, h=0.21, n=7, smooth=True)
        m.part("ankle_" + side, "hull", "#0e0a16", points=[(-0.02, -0.03, 0.0), (-0.02, 0.03, 0.0), (0.12, 0, -0.03),
                                                           (0.0, 0, -0.04)])
    m.part("hips", "ico", body, loc=(0, 0, 0), scale=(0.8, 1.1, 0.8), r=0.1, sub=1, smooth=True)
    m.part("torso", "ico", body, loc=(0, 0, 0.17), scale=(0.7, 1.1, 1.4), r=0.13, sub=2, smooth=True, shine=0.3)
    m.part("head", "ico", body, loc=(0.02, 0, 0.08), scale=(1.1, 0.85, 1.2), r=0.08, sub=2, smooth=True)
    for s in (-1.0, 1.0):
        m.part("head", "sphere", "#f0f0ff", loc=(0.08, s * 0.03, 0.09), scale=(0.4, 1.0, 0.6), r=0.016, u=6, v=4, emit=True)
    _cape(m, "torso", "#120e1c", 0.3, 0.55, 0.12, -0.08, grime=0.3)
    return {"anims": _humanoid_set(), "cell": (110, 120), "anchor": (55, 95), "stride": 1.4}


def wailer(m):
    """Feryatçı: yere değmeyen, uzun saçlı, yırtık kefenli soluk hayalet kadın; açık çığlık ağzı, parlayan gözler."""
    hu.skeleton(m, {"hip_h": 0.5, "shoulder_w": 0.15, "neck": 0.34})
    pale = "#a89ec8"
    shroud = "#6a6088"
    for side in ("r", "l"):
        m.part("shoulder_" + side, "cyl", pale, loc=(0, 0, -0.1), r1=0.025, r2=0.035, h=0.2, n=7, smooth=True)
        m.part("elbow_" + side, "cyl", shroud, loc=(0, 0, -0.09), r1=0.05, r2=0.03, h=0.18, n=7)
        m.part("hand_" + side, "hull", pale, points=[(0.0, -0.025, 0.0), (0.0, 0.025, 0.0), (0.05, 0, -0.1), (0.02, 0, -0.08)])
    m.part("hips", "cyl", shroud, loc=(0, 0, -0.15), r1=0.05, r2=0.13, h=0.35, n=10, grime=0.4)
    for k in range(8):
        a = k * math.pi / 4
        m.part("hips", "hull", shroud, points=[(0.1 * math.cos(a), 0.1 * math.sin(a), -0.3),
                                               (0.12 * math.cos(a + 0.3), 0.12 * math.sin(a + 0.3), -0.3),
                                               (0.1 * math.cos(a + 0.15), 0.1 * math.sin(a + 0.15), -0.45 - 0.05 * (k % 2))])
    m.part("torso", "box", shroud, loc=(0, 0, 0.16), sx=0.15, sy=0.2, sz=0.32, top=(1.0, 1.1), grime=0.4)
    m.part("head", "sphere", pale, loc=(0.01, 0, 0.08), scale=(1.0, 0.85, 1.2), r=0.075, u=8, v=6, smooth=True, shine=0.3)
    m.part("head", "sphere", "#0a0610", loc=(0.07, 0, 0.03), scale=(0.4, 0.8, 1.2), r=0.03, u=6, v=4)
    for s in (-1.0, 1.0):
        m.part("head", "sphere", "#e0d8ff", loc=(0.07, s * 0.03, 0.1), r=0.013, u=5, v=3, emit=True)
    for y in (-0.06, -0.03, 0.0, 0.03, 0.06):
        m.part("head", "box", "#d8d0e8", loc=(-0.05, y, -0.05), rot=(0, -15, 0), sx=0.02, sy=0.025, sz=0.35 - abs(y) * 1.5)
    return {"anims": _floating_set(ranged=True), "cell": (110, 120), "anchor": (55, 95)}


def void_slave(m):
    """Boşluk Kulu: zincirli, iri, mor-kara tenli köle dev; tenindeki çatlaklarda boşluk ışığı, boynunda demir halka."""
    hu.skeleton(m, {"hip_h": 0.55, "thigh": 0.25, "shin": 0.24, "shoulder_w": 0.27, "upper": 0.24, "fore": 0.24, "neck": 0.4})
    skin = "#2a1f4a"
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("shoulder_" + side, "sphere", skin, loc=(0, s * 0.02, 0), r=0.1, u=9, v=7, smooth=True, shine=0.35)
        m.part("shoulder_" + side, "cyl", skin, loc=(0, 0, -0.12), r1=0.06, r2=0.08, h=0.24, n=8, smooth=True, shine=0.35)
        m.part("elbow_" + side, "cyl", skin, loc=(0, 0, -0.11), r1=0.06, r2=0.07, h=0.23, n=8, smooth=True, shine=0.35)
        m.part("elbow_" + side, "cyl", IRON, loc=(0, 0, -0.18), r1=0.08, r2=0.08, h=0.06, n=8, shine=0.6)
        m.part("hand_" + side, "ico", skin, loc=(0.0, 0, -0.06), r=0.09, sub=1, shine=0.3)
        m.part("hip_" + side, "cyl", "#1a1428", loc=(0, 0, -0.12), r1=0.08, r2=0.09, h=0.25, n=8, smooth=True)
        m.part("knee_" + side, "cyl", skin, loc=(0, 0, -0.11), r1=0.065, r2=0.08, h=0.24, n=8, smooth=True)
        m.part("ankle_" + side, "box", skin, loc=(0.04, 0, -0.035), sx=0.2, sy=0.11, sz=0.07)
        m.part("elbow_" + side, "box", VOID, loc=(0.065, 0, -0.08), rot=(20, 0, 0), sx=0.005, sy=0.015, sz=0.1, emit=True)
    m.part("hips", "cyl", "#1a1428", loc=(0, 0, -0.02), r1=0.17, r2=0.16, h=0.14, n=10)
    m.part("torso", "ico", skin, loc=(0, 0, 0.2), scale=(0.9, 1.35, 1.2), r=0.2, sub=2, smooth=True, shine=0.35)
    for z, y in ((0.12, 0.05), (0.24, -0.06), (0.3, 0.1)):
        m.part("torso", "box", VOID, loc=(0.17, y, z), rot=(30, 0, 0), sx=0.005, sy=0.015, sz=0.09, emit=True)
    m.part("torso", "cyl", IRON, loc=(0, 0, 0.4), r1=0.13, r2=0.13, h=0.05, n=10, shine=0.6)
    for i in range(6):
        m.part("torso", "box", "#55575c", loc=(0.12, -0.15 + 0.05 * i, 0.3 - 0.04 * i), rot=(50, 0, 0),
               sx=0.015, sy=0.03, sz=0.04, shine=0.6)
    m.part("head", "ico", skin, loc=(0.03, 0, 0.07), scale=(1.1, 0.9, 1.0), r=0.08, sub=2, smooth=True)
    for s in (-1.0, 1.0):
        m.part("head", "sphere", VOID, loc=(0.1, s * 0.03, 0.08), r=0.014, u=5, v=3, emit=True)
    return {"anims": _humanoid_set(), "cell": (160, 150), "anchor": (80, 120), "stride": 1.2}


def void_summoner(m):
    """Boşluk Çağırıcı: mor-kara cüppeli, yüzü yüzsüz maskeli tarikatçı; elinin üstünde dönen boşluk küresi."""
    hu.skeleton(m, {"hip_h": 0.5, "shoulder_w": 0.16, "neck": 0.35})
    robe = "#2a1a3e"
    for side in ("r", "l"):
        m.part("shoulder_" + side, "cyl", robe, loc=(0, 0, -0.1), r1=0.04, r2=0.05, h=0.2, n=7)
        m.part("elbow_" + side, "cyl", robe, loc=(0, 0, -0.09), r1=0.055, r2=0.04, h=0.18, n=7)
        m.part("hand_" + side, "box", "#9a8ab0", loc=(0.005, 0, -0.035), sx=0.05, sy=0.05, sz=0.06)
        m.part("hip_" + side, "cyl", robe, loc=(0, 0, -0.11), r1=0.05, r2=0.055, h=0.23, n=7)
        m.part("knee_" + side, "cyl", robe, loc=(0, 0, -0.1), r1=0.04, r2=0.05, h=0.21, n=7)
        m.part("ankle_" + side, "box", "#140e1c", loc=(0.03, 0, -0.03), sx=0.13, sy=0.07, sz=0.05)
    _flaps(m, robe, 0.44, fx=0.08, bx=-0.08, width=0.13, grime=0.5)
    m.part("hips", "cyl", robe, loc=(0, 0, -0.02), r1=0.12, r2=0.11, h=0.12, n=9)
    m.part("torso", "box", robe, loc=(0, 0, 0.16), sx=0.17, sy=0.24, sz=0.32, top=(1.0, 1.1), grime=0.5)
    m.part("head", "hull", robe, points=[(0.0, 0, 0.24), (-0.1, 0, 0.16), (-0.1, 0, 0.0), (0.05, 0.09, 0.12),
                                         (0.05, -0.09, 0.12), (-0.06, 0.1, 0.02), (-0.06, -0.1, 0.02), (0.02, 0.1, -0.02),
                                         (0.02, -0.1, -0.02), (0.07, 0, 0.2)])
    m.part("head", "sphere", "#cfc6b0", loc=(0.05, 0, 0.08), scale=(0.5, 1.0, 1.25), r=0.07, u=8, v=6, smooth=True, shine=0.4)
    for s in (-1.0, 1.0):
        m.part("head", "box", "#0a0610", loc=(0.085, s * 0.025, 0.1), sx=0.01, sy=0.02, sz=0.008)
    m.part("hand_l", "ico", VOID, loc=(0.03, 0, 0.1), r=0.05, sub=2, emit=True)
    return {"anims": _humanoid_set(ranged=True), "cell": (110, 120), "anchor": (55, 95)}


# --- boss yardımcıları ---

def crawling_eye(m):
    """Sürünen Göz (Morvath'ın doğurduğu): örümcek gibi dört sıska bacaklı, kanlı damarlı göz küresi."""
    crawler(m, 0.2, 0.12, 0.14, 0.07, legs=4, splay=35)
    _eye(m, "body", (0.0, 0, 0.03), 0.1)
    m.part("body", "ico", FLESH_D, loc=(-0.06, 0, 0.0), r=0.08, sub=1, smooth=True)
    for leg in ("leg0r", "leg0l", "leg1r", "leg1l"):
        m.part(leg, "cyl", FLESH, loc=(0, 0, -0.035), r1=0.012, r2=0.02, h=0.07, n=5)
    for kn in ("knee0r", "knee0l", "knee1r", "knee1l"):
        m.part(kn, "cyl", FLESH_D, loc=(0, 0, -0.035), r1=0.005, r2=0.012, h=0.07, n=5)
    splat(m, "body", (-0.05, 0.02, 0.07), 0.025, normal="+z")
    return {"anims": crawler_set(m), "cell": (70, 60), "anchor": (35, 40), "stride": 0.7}


def wall_eye(m):
    """Duvar Gözü (Morvath'ın kapağını tutar): duvar etine gömülü iri göz, çevresi damarlı et."""
    blob(m)
    m.part("body", "ico", FLESH_D, loc=(-0.08, 0, 0.35), scale=(0.5, 1.3, 1.3), r=0.2, sub=2, smooth=True, grime=0.5)
    _eye(m, "body", (0.02, 0, 0.36), 0.14)
    for k in range(5):
        a = k * 1.25
        m.part("body", "cyl", VEIN, loc=(-0.02, 0.14 * math.cos(a), 0.36 + 0.14 * math.sin(a)), rot=(math.degrees(a), 90, 0),
               r1=0.012, r2=0.02, h=0.18, n=5, shine=0.4)
    return {"anims": blob_set(m, static=True), "cell": (80, 100), "anchor": (40, 80)}


# ----------------------------------------------------------------------------------------------------------------
# Boss'lar

def morvath(m):
    """Morvath, Ana Göz: duvara gömülü 3-4 oyuncu boyunda ıslak, etli göz kütlesi; nabız gibi atan kızıl-mor damarlar,
    dişli yarıklar. _closed varyantı: göz kapağı kapalı (hasar almaz)."""
    blob(m, tentacles=[((0.3, -0.7, 0.4), None), ((0.3, 0.7, 0.4), None), ((0.35, -0.5, 1.6), None), ((0.35, 0.5, 1.6), None)])
    for loc, r in (((-0.3, 0, 1.3), 1.0), ((-0.2, -0.6, 0.8), 0.7), ((-0.2, 0.6, 0.8), 0.7), ((-0.1, 0, 0.5), 0.75),
                   ((-0.35, -0.4, 2.0), 0.6), ((-0.35, 0.45, 2.0), 0.55), ((-0.2, 0, 2.3), 0.5)):
        m.part("body", "ico", FLESH, loc=loc, r=r, sub=2, smooth=True, shine=0.4, grime=0.45)
    for k in range(10):
        a = k * 0.63
        m.part("body", "cyl", VEIN, loc=(0.35 * math.cos(a) + 0.1, 0.9 * math.sin(a), 1.3 + 0.8 * math.cos(a * 1.7)),
               rot=(60 * math.sin(a), 40, math.degrees(a)), r1=0.03, r2=0.05, h=0.9, n=6, shine=0.5)
    _eye(m, "body", (0.45, 0, 1.35), 0.5)
    m.joint("lid", "body", (0.45, 0, 1.35), scale=0.001)
    m.part("lid", "sphere", FLESH_D, r=0.55, u=12, v=10, smooth=True, shine=0.4, grime=0.5)
    m.part("lid", "box", "#1a0508", loc=(0.53, 0, 0), sx=0.06, sy=0.6, sz=0.04)
    for i in range(7):
        y = -0.45 + 0.15 * i
        m.part("body", "hull", "#e0d6c0", points=[(0.45, y - 0.03, 0.55), (0.45, y + 0.03, 0.55), (0.5, y, 0.55), (0.52, y, 0.4)])
    for i in range(4):
        m.part("tent%d" % i, "cyl", FLESH_D, loc=(0.25, 0, -0.1), rot=(0, 110, 0), r1=0.06, r2=0.13, h=0.55, n=7, smooth=True)
        m.part("tentb%d" % i, "hull", BONE, points=[(0.5, -0.05, -0.2), (0.5, 0.05, -0.2), (0.5, 0, -0.15), (0.75, 0, -0.35)])
    splat(m, "body", (0.6, 0.3, 0.9), 0.12, normal="+x")
    splat(m, "body", (0.5, -0.4, 1.9), 0.1, normal="+x", dark=True)
    return {"anims": blob_set(m, static=True, ranged=True, closed_variant=True), "cell": (300, 320), "anchor": (150, 250)}


def _boss_humanoid_set(scale_frames=1.0, ranged=False, floating=False):
    s = _floating_set(ranged=ranged) if floating else _humanoid_set(ranged=ranged)
    out = []
    for name, n, fps, loop, fn in s:
        n2 = {"idle": 6, "walk": 8, "attack": 6, "cast": 6, "hit": 3, "death": 8}[name]
        out.append((name, n2, fps * 0.8, loop, fn))
    return out


def mycela(m):
    """Mycela, Spor Kraliçesi: mantardan uzun ince insansı gövde, altı parlayan geniş mantar şapka, yere uzanan kök kollar,
    çevresinde spor tozu."""
    hu.skeleton(m, {"hip_h": 1.0, "thigh": 0.46, "shin": 0.46, "hip_w": 0.13, "waist": 0.08, "shoulder_h": 0.62,
                    "shoulder_w": 0.3, "upper": 0.45, "fore": 0.5, "neck": 0.72})
    stalk = "#b8a488"
    stalk_d = "#7a6448"
    for side in ("r", "l"):
        m.part("shoulder_" + side, "cyl", stalk_d, loc=(0, 0, -0.22), r1=0.06, r2=0.09, h=0.45, n=8, smooth=True, grime=0.5)
        m.part("elbow_" + side, "cyl", stalk_d, loc=(0, 0, -0.25), r1=0.03, r2=0.06, h=0.5, n=8, smooth=True, grime=0.5)
        for k in range(3):
            a = (k - 1) * 0.5
            m.part("hand_" + side, "cyl", "#5a4a38", loc=(0.04 * math.sin(a), 0.04 * math.cos(a), -0.12),
                   rot=(math.degrees(a) * 0.6, 20, 0), r1=0.01, r2=0.025, h=0.25, n=5)
        m.part("hip_" + side, "cyl", stalk_d, loc=(0, 0, -0.23), r1=0.07, r2=0.1, h=0.46, n=8, smooth=True)
        m.part("knee_" + side, "cyl", stalk_d, loc=(0, 0, -0.23), r1=0.08, r2=0.08, h=0.46, n=8, smooth=True)
        m.part("ankle_" + side, "ico", "#4a3a28", loc=(0.02, 0, -0.04), scale=(1.4, 1.0, 0.5), r=0.12, sub=1)
    _flaps(m, "#4a3a5a", 0.7, fx=0.13, bx=-0.13, width=0.2, grime=0.5)
    m.part("hips", "ico", stalk, loc=(0, 0, 0.0), scale=(1.0, 1.3, 0.8), r=0.2, sub=2, smooth=True)
    m.part("torso", "ico", stalk, loc=(0, 0, 0.35), scale=(0.7, 1.0, 1.9), r=0.2, sub=2, smooth=True, grime=0.5)
    m.part("head", "cyl", stalk, loc=(0, 0, 0.08), r1=0.1, r2=0.08, h=0.18, n=8, smooth=True)
    for s in (-1.0, 1.0):
        m.part("head", "sphere", "#d0ff60", loc=(0.08, s * 0.035, 0.1), r=0.02, u=5, v=3, emit=True)
    m.part("head", "box", "#1a0808", loc=(0.09, 0, 0.04), sx=0.02, sy=0.08, sz=0.03)
    _mushroom_cap(m, "head", 0.55, "#4a2a5a", "#90ff60", 0.22, glow_spots=True)
    m.part("head", "cyl", "#90ff60", loc=(0, 0, 0.2), r1=0.45, r2=0.2, h=0.02, n=14, emit=True)
    return {"anims": _boss_humanoid_set(ranged=True), "cell": (260, 330), "anchor": (130, 270), "stride": 2.2}


def kordrak(m):
    """Kordrak, Erimiş Demirci: kara taştan iri omuzlu golem, göğsünde turuncu erimiş çekirdek, demir zırh plakaları,
    örs başlı dev çekiç. _p2 varyantı: plakalar düşmüş, çekirdek açıkta ve daha parlak."""
    hu.skeleton(m, {"hip_h": 0.9, "thigh": 0.42, "shin": 0.4, "hip_w": 0.17, "waist": 0.08, "shoulder_h": 0.62,
                    "shoulder_w": 0.5, "upper": 0.42, "fore": 0.45, "neck": 0.7})
    rock = "#3a3632"
    rock_l = "#56504a"
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("shoulder_" + side, "ico", rock, loc=(0, s * 0.05, 0), r=0.22, sub=1, grime=0.6, shine=0.15)
        m.part("shoulder_" + side, "ico", rock_l, loc=(0, 0, -0.26), scale=(1.0, 1.0, 1.4), r=0.15, sub=1, grime=0.6)
        m.part("elbow_" + side, "ico", rock, loc=(0, 0, -0.22), scale=(1.0, 1.0, 1.5), r=0.16, sub=1, grime=0.6)
        m.part("hand_" + side, "ico", rock_l, loc=(0.0, 0, -0.1), r=0.17, sub=1, grime=0.6)
        m.part("hip_" + side, "ico", rock, loc=(0, 0, -0.2), scale=(1.0, 1.0, 1.4), r=0.16, sub=1, grime=0.6)
        m.part("knee_" + side, "ico", rock_l, loc=(0, 0, -0.22), scale=(1.1, 1.0, 1.3), r=0.16, sub=1, grime=0.6)
        m.part("ankle_" + side, "box", rock, loc=(0.06, 0, -0.06), sx=0.35, sy=0.22, sz=0.14, grime=0.6)
        m.part("elbow_" + side, "box", LAVA, loc=(0.14, 0, -0.2), rot=(20, 0, 0), sx=0.01, sy=0.03, sz=0.25, emit=True)
    m.part("hips", "ico", rock, loc=(0, 0, 0), scale=(1.0, 1.4, 0.7), r=0.3, sub=1, grime=0.6)
    m.part("torso", "ico", rock, loc=(0, 0, 0.35), scale=(0.9, 1.4, 1.1), r=0.42, sub=2, grime=0.6, shine=0.15)
    m.part("torso", "ico", LAVA, loc=(0.3, 0, 0.4), r=0.14, sub=2, emit=True)
    m.part("head", "ico", rock, loc=(0.06, 0, 0.1), scale=(1.1, 1.0, 0.8), r=0.17, sub=1, grime=0.6)
    for s in (-1.0, 1.0):
        m.part("head", "box", LAVA, loc=(0.2, s * 0.06, 0.12), sx=0.02, sy=0.05, sz=0.02, emit=True)
    # Zırh plakaları (_p2'de yok)
    m.joint("plates", "torso", (0, 0, 0))
    m.part("plates", "box", "#2e3036", loc=(0.3, 0, 0.35), sx=0.12, sy=0.62, sz=0.6, top=(1.0, 1.1), shine=0.6, grime=0.5)
    m.part("plates", "box", RUST, loc=(0.37, 0, 0.35), sx=0.02, sy=0.1, sz=0.55, grime=0.6)
    for s in (-1.0, 1.0):
        m.part("plates", "box", "#2e3036", loc=(0.0, s * 0.62, 0.62), sx=0.4, sy=0.12, sz=0.2, shine=0.6, grime=0.5)
    # Örs başlı çekiç
    m.part("hand_r", "cyl", "#2a1d14", loc=(0.35, 0, -0.1), rot=(0, 90, 0), r1=0.04, r2=0.04, h=0.9, n=6)
    m.part("hand_r", "box", "#2e3036", loc=(0.85, 0, -0.1), sx=0.3, sy=0.42, sz=0.26, top=(1.0, 0.7), shine=0.6, grime=0.5)
    m.part("hand_r", "box", LAVA, loc=(0.85, 0, 0.035), sx=0.2, sy=0.25, sz=0.01, emit=True)
    splat(m, "hand_r", (0.85, 0.12, -0.24), 0.08, normal="-z")

    anims = _boss_humanoid_set()

    def no_plates(fn):
        return lambda t: dict(fn(t), plates={"scale": 0.001})
    p2 = [(name + "_p2", n, fps, loop, no_plates(fn)) for name, n, fps, loop, fn in anims if name != "death"]
    return {"anims": anims + p2, "cell": (340, 330), "anchor": (170, 260), "stride": 2.0}


def nyxthar(m):
    """Nyx'thar, Yankısız: havada süzülen, yırtık pelerine benzeyen uzun hayalet; yüzünde boş karanlık ve sönmeyen tek
    soluk ışık, alt kısmı duman gibi dağılır."""
    hu.skeleton(m, {"hip_h": 1.0, "thigh": 0.4, "shin": 0.4, "waist": 0.1, "shoulder_h": 0.62, "shoulder_w": 0.28,
                    "upper": 0.45, "fore": 0.48, "neck": 0.72})
    cloak = "#1a1626"
    cloak_d = "#0e0c16"
    for side in ("r", "l"):
        m.part("shoulder_" + side, "cyl", cloak, loc=(0, 0, -0.2), r1=0.08, r2=0.06, h=0.42, n=8, grime=0.3)
        m.part("elbow_" + side, "cyl", cloak, loc=(0, 0, -0.22), r1=0.12, r2=0.06, h=0.45, n=8, grime=0.3)
        for y in (-0.04, 0.0, 0.04):
            m.part("hand_" + side, "hull", "#b8b0d8", points=[(0.0, y - 0.015, 0.0), (0.0, y + 0.015, 0.0), (0.02, y, 0.02),
                                                             (0.12, y * 1.5, -0.3)], shine=0.4)
    m.part("hips", "cyl", cloak, loc=(0, 0, -0.35), r1=0.12, r2=0.3, h=0.7, n=12, grime=0.3)
    for k in range(12):
        a = k * math.pi / 6
        m.part("hips", "hull", cloak_d, points=[(0.26 * math.cos(a), 0.26 * math.sin(a), -0.6),
                                                (0.3 * math.cos(a + 0.25), 0.3 * math.sin(a + 0.25), -0.6),
                                                (0.25 * math.cos(a + 0.12), 0.25 * math.sin(a + 0.12), -0.95 - 0.1 * (k % 3))])
    m.part("torso", "box", cloak, loc=(0, 0, 0.32), sx=0.3, sy=0.46, sz=0.64, top=(1.0, 1.2), grime=0.3)
    _cape(m, "torso", cloak_d, 0.62, 1.4, 0.3, -0.18, grime=0.3, teeth=6)
    m.part("head", "hull", cloak, points=[(0.0, 0, 0.5), (-0.2, 0, 0.36), (-0.22, 0, 0.0), (0.1, 0.2, 0.25), (0.1, -0.2, 0.25),
                                          (-0.12, 0.22, 0.05), (-0.12, -0.22, 0.05), (0.06, 0.2, -0.04), (0.06, -0.2, -0.04),
                                          (0.16, 0, 0.42)], grime=0.3)
    m.part("head", "sphere", "#020104", loc=(0.1, 0, 0.18), scale=(0.4, 1.0, 1.3), r=0.14, u=8, v=6)
    m.part("head", "sphere", "#e8e4ff", loc=(0.15, 0.02, 0.2), r=0.035, u=6, v=4, emit=True)
    return {"anims": _boss_humanoid_set(ranged=True, floating=True), "cell": (260, 360), "anchor": (130, 300), "stride": 2.0}


ENEMIES = {
    "skeleton_warrior": skeleton_warrior, "skeleton_archer": skeleton_archer, "cave_rat": cave_rat,
    "eye_spawn": eye_spawn, "vein_mass": vein_mass,
    "spore_beetle": spore_beetle, "mushroom_man": mushroom_man, "poison_spitter": poison_spitter,
    "mushroom_healer": mushroom_healer,
    "stone_golemling": stone_golemling, "ember_hound": ember_hound, "slag_mage": slag_mage, "iron_guard": iron_guard,
    "shade": shade, "wailer": wailer, "void_slave": void_slave, "void_summoner": void_summoner,
    "crawling_eye": crawling_eye, "wall_eye": wall_eye, "spore_totem": spore_totem,
    "morvath": morvath, "mycela": mycela, "kordrak": kordrak, "nyxthar": nyxthar,
}
