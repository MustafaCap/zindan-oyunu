"""İnsansı iskelet ve animasyonları (Aşama 8).

İskelet eklemleri (boş nesneler): root → hips → torso → head / shoulder_r → elbow_r → hand_r / shoulder_l → …
hips → hip_r → knee_r → ankle_r / hip_l → … Karakter +X'e bakar, sol tarafı +Y.
Açı kuralları (derece, eklemin ebeveyn eksenleri): uzuvlar aşağı sarkar; Y ekseni etrafında negatif = uzuv öne,
pozitif = arkaya; diz ve dirsek bükümü: diz +, dirsek −. Kol yana açılması X ekseni: sağ kol −, sol kol +.
Z ekseni etrafında pozitif = sola dönme. hand_r / hand_l'nin yerel +X ekseni silahın (demir yumrukta iki elin) ucunu
gösterir; silah katmanı bunu kullanır. Poz değeri (rx, ry, rz) ya da {"rot", "loc", "scale", "world_rot"}.
"""

import math

DEFAULT_PROPS = {
    "hip_h": 0.50, "thigh": 0.22, "shin": 0.21, "hip_w": 0.085, "waist": 0.04,
    "shoulder_h": 0.30, "shoulder_w": 0.19, "upper": 0.19, "fore": 0.17, "neck": 0.36,
}


def skeleton(m, props=None):
    p = dict(DEFAULT_PROPS)
    if props:
        p.update(props)
    m.joint("hips", "root", (0, 0, p["hip_h"]))
    m.joint("torso", "hips", (0, 0, p["waist"]))
    m.joint("head", "torso", (0, 0, p["neck"]))
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.joint("shoulder_" + side, "torso", (0, s * p["shoulder_w"], p["shoulder_h"]))
        m.joint("elbow_" + side, "shoulder_" + side, (0, 0, -p["upper"]))
        m.joint("hand_" + side, "elbow_" + side, (0, 0, -p["fore"]))
        m.joint("hip_" + side, "hips", (0, s * p["hip_w"], 0))
        m.joint("knee_" + side, "hip_" + side, (0, 0, -p["thigh"]))
        m.joint("ankle_" + side, "knee_" + side, (0, 0, -p["shin"]))
    return p


# ----------------------------------------------------------------------------------------------------------------
# Poz yardımcıları

def grip(shoulder_ry, elbow_ry, pitch):
    """Elin Y açısı: silah (el +X) yataydan `pitch` derece yukarı baksın diye omuz + dirsek dönüşünü telafi eder."""
    return -pitch - shoulder_ry - elbow_ry


def _norm(v):
    out = {"rot": (0.0, 0.0, 0.0), "loc": (0.0, 0.0, 0.0), "scale": None, "world_rot": None}
    if v is None:
        return out
    if isinstance(v, dict):
        out["rot"] = tuple(v.get("rot", out["rot"]))
        out["loc"] = tuple(v.get("loc", out["loc"]))
        out["scale"] = v.get("scale")
        out["world_rot"] = v.get("world_rot")
        return out
    out["rot"] = tuple(v)
    return out


def _lerp_opt(a, b, t):
    if a is None:
        return b
    if b is None:
        return a
    if isinstance(a, (int, float)):
        return a + (b - a) * t
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def _ease(t):
    return t * t * (3.0 - 2.0 * t)


def blend(a, b, t):
    """İki pozu t (0..1) oranında karıştırır."""
    out = {}
    for k in set(a) | set(b):
        pa, pb = _norm(a.get(k)), _norm(b.get(k))
        out[k] = {"rot": _lerp_opt(pa["rot"], pb["rot"], t), "loc": _lerp_opt(pa["loc"], pb["loc"], t),
                  "scale": _lerp_opt(pa["scale"], pb["scale"], t),
                  "world_rot": _lerp_opt(pa["world_rot"], pb["world_rot"], t)}
    return out


def keyed(keys, t, ease=True):
    """keys: [(zaman, poz), …] artan zamanla; t'deki pozu yumuşak geçişle verir."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
        if t <= t1:
            k = (t - t0) / max(t1 - t0, 1e-6)
            return blend(p0, p1, _ease(k) if ease else k)
    return keys[-1][1]


def add(p, extra):
    """Poza ek açı/konum ekler (ör. yürürken silah kolu)."""
    out = dict(p)
    for k, v in extra.items():
        a, b = _norm(out.get(k)), _norm(v)
        out[k] = {"rot": tuple(x + y for x, y in zip(a["rot"], b["rot"])),
                  "loc": tuple(x + y for x, y in zip(a["loc"], b["loc"])),
                  "scale": b["scale"] if b["scale"] is not None else a["scale"],
                  "world_rot": b["world_rot"] if b["world_rot"] is not None else a["world_rot"]}
    return out


def with_(base, **joints):
    out = dict(base)
    out.update(joints)
    return out


def _arm(side, rx, ry, rz, er, pitch):
    return {"shoulder_" + side: (rx, ry, rz), "elbow_" + side: (0, er, 0), "hand_" + side: (0, grip(ry, er, pitch), 0)}


# ----------------------------------------------------------------------------------------------------------------
# Animasyonlar — her biri t (0..1) → poz. Döngülerde t = i/n, tek seferliklerde t = i/(n−1).

def pose_ready(b=0.0):
    """Silah hazır, hafif öne eğik tehditkâr duruş (bekleme ve yürümenin temeli). b: nefes (−1..1)."""
    p = {
        "hips": {"loc": (0, 0, -0.018 + 0.004 * b)},
        "torso": (0, 7.0 + 1.5 * b, 0),
        "head": (0, -6.0 - 1.0 * b, 0),
        "hip_r": (-5.0, -4.0, 0), "knee_r": (0, 10.0, 0), "ankle_r": (0, -6.0, 0),
        "hip_l": (5.0, -4.0, 0), "knee_l": (0, 10.0, 0), "ankle_l": (0, -6.0, 0),
        "shield": {"scale": 0.001},
    }
    p.update(_arm("r", -10.0, -16.0, 0, -50.0, -30.0))
    p.update(_arm("l", 12.0, -6.0 + 2.0 * b, 0, -30.0, -60.0))
    return p


def idle(t):
    return pose_ready(math.sin(2.0 * math.pi * t))


def walk(t, swing=32.0):
    a = 2.0 * math.pi * t
    s, c = math.sin(a), math.cos(a)
    hip_r = -swing * s
    hip_l = swing * s
    knee_r = 8.0 + 42.0 * max(0.0, c)
    knee_l = 8.0 + 42.0 * max(0.0, -c)
    p = pose_ready()
    p.update({
        "hips": {"loc": (0, 0, -0.022 + 0.022 * abs(c) - 0.011), "rot": (0, 0, 5.0 * s)},
        "torso": (0, 10.0, -8.0 * s),
        "hip_r": (-3.0, hip_r, 0), "knee_r": (0, knee_r, 0), "ankle_r": (0, -(hip_r + knee_r) * 0.7, 0),
        "hip_l": (3.0, hip_l, 0), "knee_l": (0, knee_l, 0), "ankle_l": (0, -(hip_l + knee_l) * 0.7, 0),
    })
    p.update(_arm("l", 12.0, -26.0 * s, 0, -30.0 - 12.0 * max(0.0, s), -60.0))
    p = add(p, {"shoulder_r": (0, 12.0 * s, 0), "hand_r": (0, -12.0 * s, 0)})
    return p


def attack(t):
    """Yakın dövüş: sağdan sola ağır, geniş savuruş (silah kolu omuzdan dönerek süpürür)."""
    base = pose_ready()
    wind = with_(base, torso=(0, 2, -38), hips={"loc": (0, 0, -0.03)})
    wind.update(_arm("r", -10, -80, -80, -35, 18))
    wind.update(_arm("l", 30, 15, 0, -40, -40))
    mid = with_(base, torso=(0, 12, -6), hip_l=(3, -26, 0), knee_l=(0, 24, 0), hip_r=(-3, 14, 0), knee_r=(0, 14, 0),
                hips={"loc": (0.03, 0, -0.045)})
    mid.update(_arm("r", -8, -84, -20, -12, 2))
    mid.update(_arm("l", 35, 25, 0, -40, -40))
    hit = with_(mid, torso=(0, 14, 22))
    hit.update(_arm("r", -6, -82, 32, -6, -6))
    follow = with_(hit, torso=(0, 12, 32))
    follow.update(_arm("r", -4, -68, 62, -20, -26))
    return keyed([(0.0, wind), (0.2, mid), (0.4, hit), (0.65, follow), (1.0, base)], t)


def cast(t):
    """Uzak saldırı / büyü: iki kol öne, silah hedefe; kısa geri tepme."""
    base = pose_ready()
    aim = with_(base, torso=(0, 4, -12), hip_l=(3, -14, 0), knee_l=(0, 12, 0), hip_r=(-3, 8, 0))
    aim.update(_arm("r", -6, -80, -4, -8, 0))
    aim.update(_arm("l", 12, -62, 22, -45, 0))
    rel = with_(aim, torso=(0, -5, -10), head=(0, 3, 0), hips={"loc": (-0.015, 0, -0.012)})
    rel.update(_arm("r", -6, -90, -2, -4, 6))
    rel.update(_arm("l", 12, -40, 20, -45, 0))
    return keyed([(0.0, aim), (0.3, rel), (0.55, aim), (1.0, base)], t)


def _guard():
    g = with_(pose_ready(), torso=(0, 10, 0), hips={"loc": (0, 0, -0.03)},
              hip_l=(4, -14, 0), knee_l=(0, 16, 0), hip_r=(-4, 10, 0), knee_r=(0, 16, 0))
    g.update(_arm("r", -12, -45, 8, -100, 5))
    g.update(_arm("l", 12, -50, -8, -100, 5))
    return g


def punch(side):
    """Demir yumruk: siperden tek elle düz yumruk (sağ ve sol sırayla oynatılır)."""
    other = "l" if side == "r" else "r"
    twist = 26.0 if side == "r" else -26.0

    def fn(t):
        guard = _guard()
        out = with_(guard, torso=(0, 16, twist), hips={"loc": (0.04, 0, -0.04)})
        out.update(_arm(side, -4 if side == "r" else 4, -88, -twist * 0.3, -4, 0))
        out.update(_arm(other, 12 if other == "l" else -12, -40, 0, -105, 10))
        return keyed([(0.0, guard), (0.3, out), (0.55, out), (1.0, pose_ready())], t)
    return fn


def rush(t):
    """Warrior Kalkan Hücumu: sol koldaki demir bileklikten kalkan açılır, öne eğilip hücum; yetenek bitince kalkan
    bilekliğe geri çekilip kaybolur."""
    base = pose_ready()
    charge = with_(base, torso=(0, 24, 14), head=(0, -18, 0), hips={"loc": (0.04, 0, -0.05)},
                   hip_l=(4, -42, 0), knee_l=(0, 32, 0), ankle_l=(0, 10, 0),
                   hip_r=(-4, 32, 0), knee_r=(0, 58, 0), ankle_r=(0, -20, 0),
                   shield={"scale": 1.0, "world_rot": (0, 0, -12)})
    charge.update(_arm("l", 20, -70, -35, -75, 0))
    charge.update(_arm("r", -14, 35, 0, -60, -40))
    open_ = with_(base, shield={"scale": 0.35, "world_rot": (0, 0, -12)})
    open_.update(_arm("l", 18, -45, -20, -60, 0))
    stride = with_(charge, hip_l=(4, -30, 0), knee_l=(0, 45, 0), hip_r=(-4, 20, 0), knee_r=(0, 30, 0))
    closing = with_(charge, shield={"scale": 0.45, "world_rot": (0, 0, -12)})
    gone = with_(base, shield={"scale": 0.001})
    return keyed([(0.0, open_), (0.2, charge), (0.5, stride), (0.72, charge), (0.86, closing), (1.0, gone)], t)


def hit(t):
    base = pose_ready()
    hurt = with_(base, torso=(6, -16, 8), head=(0, -14, 0), hips={"loc": (-0.03, 0, -0.01)})
    hurt.update(_arm("l", 35, 20, 0, -50, -40))
    hurt = add(hurt, {"shoulder_r": (-10, 18, 0), "hand_r": (0, -18, 0)})
    return keyed([(0.0, base), (0.25, hurt), (1.0, base)], t)


def death(t):
    base = pose_ready()
    buckle = with_(base, hips={"loc": (-0.03, 0, -0.12), "rot": (0, -12, 0)}, torso=(0, -20, 10), head=(0, -20, 0),
                   hip_r=(-5, -35, 0), knee_r=(0, 60, 0), ankle_r=(0, -25, 0),
                   hip_l=(5, -25, 0), knee_l=(0, 55, 0), ankle_l=(0, -30, 0),
                   shoulder_r=(-40, -70, 0), elbow_r=(0, -30, 0), hand_r=(0, 60, 0),
                   shoulder_l=(40, -60, 0), elbow_l=(0, -30, 0), hand_l=(0, 60, 0))
    fall = with_(buckle, hips={"loc": (-0.1, 0, -0.26), "rot": (0, -62, 0)}, torso=(0, -12, 0), head=(0, -18, 0),
                 hip_r=(-6, 5, 0), knee_r=(0, 30, 0), hip_l=(6, 10, 0), knee_l=(0, 25, 0),
                 shoulder_r=(-70, -40, 0), shoulder_l=(70, -40, 0))
    down = with_(fall, hips={"loc": (-0.14, 0, -0.34), "rot": (0, -88, 0)}, torso=(0, -3, 0), head=(0, 6, 0),
                 hip_r=(-8, 18, 0), knee_r=(0, 8, 0), ankle_r=(0, 40, 0),
                 hip_l=(8, 22, 0), knee_l=(0, 12, 0), ankle_l=(0, 40, 0),
                 shoulder_r=(-80, -10, 0), elbow_r=(0, -15, 0), hand_r=(0, 20, 0),
                 shoulder_l=(80, -20, 0), elbow_l=(0, -20, 0), hand_l=(0, 20, 0))
    return keyed([(0.0, base), (0.25, buckle), (0.6, fall), (0.85, down), (1.0, down)], t)


# Oyuncu ırkları için animasyon seti: (ad, kare sayısı, fps, döngü, fonksiyon).
# punch_r / punch_l: demir yumruk (her ırkta iki elde, sırayla). rush: yalnızca Warrior (Kalkan Hücumu; fps oyunda
# yeteneğin süresine göre ayarlanır).
PLAYER_ANIMS = [
    ("idle", 6, 6.0, True, idle),
    ("walk", 8, 12.0, True, walk),
    ("attack", 6, 20.0, False, attack),
    ("cast", 6, 18.0, False, cast),
    ("punch_r", 5, 24.0, False, punch("r")),
    ("punch_l", 5, 24.0, False, punch("l")),
    ("hit", 4, 16.0, False, hit),
    ("death", 8, 10.0, False, death),
]
RUSH_ANIM = ("rush", 6, 16.0, False, rush)
