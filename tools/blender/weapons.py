"""Silah modelleri (Aşama 8). Tutma noktası orijinde, silahın ucu +X yönünde, yukarı +Z.

Silahlar karakterden ayrı bir katmandır: oyunda karakterin eline (sprite meta'sındaki el konumu ve açısı) yerleştirilir;
demir yumruk iki ele birden giydirilir. glow=True parçalar element maskesine girer; oyun bu maskeyi silahın element
rengiyle boyar. Görsel yön: karanlık ve kanlı (kullanıcı kararı, Aşama 8) — koyu çelik, kan izleri.
Anahtarlar weapon_types.json > visual ile aynıdır.
"""

import math

STEEL = "#9aa1a8"
STEEL_D = "#5d636b"
IRON = "#45484e"
LEATHER = "#3a2416"
WOOD = "#5e3f25"
BRASS = "#8a6a2e"
BLOOD = "#7a0a0a"
BLOOD_D = "#4a0505"


def _joint(m):
    m.joint("grip", "root", (0, 0, 0))
    return "grip"


def _blood(m, g, x, y, z, sx, sy, sz, dark=False):
    m.part(g, "box", BLOOD_D if dark else BLOOD, loc=(x, y, z), sx=sx, sy=sy, sz=sz, shine=0.7, grime=0.25)


def blade(m):
    """Kılıç: koyu çelik, işlemeli pirinç balçak, ucu kanlı."""
    g = _joint(m)
    m.part(g, "cyl", LEATHER, rot=(0, 90, 0), r1=0.022, r2=0.022, h=0.15, n=6)
    m.part(g, "sphere", BRASS, loc=(-0.09, 0, 0), r=0.03, u=6, v=4, shine=0.6)
    m.part(g, "box", BRASS, loc=(0.09, 0, 0), sx=0.035, sy=0.21, sz=0.04, top=(1.0, 0.8), shine=0.6)
    for s in (-1.0, 1.0):
        m.part(g, "sphere", BRASS, loc=(0.09, s * 0.105, 0), r=0.022, u=5, v=3, shine=0.6)
    t = 0.012
    m.part(g, "hull", STEEL, glow=True, shine=0.7, grime=0.35,
           points=[(0.1, -0.036, -t), (0.1, 0.036, -t), (0.1, -0.036, t), (0.1, 0.036, t),
                   (0.52, -0.03, -t), (0.52, 0.03, -t), (0.52, -0.03, t), (0.52, 0.03, t), (0.64, 0, 0)])
    m.part(g, "box", STEEL_D, loc=(0.31, 0, 0), sx=0.38, sy=0.016, sz=0.028, shine=0.4)
    # Kan: uca doğru koyulaşan izler (iki yüzde)
    for zs in (-1.0, 1.0):
        _blood(m, g, 0.5, 0.004, zs * 0.0125, 0.18, 0.05, 0.004)
        _blood(m, g, 0.38, -0.012, zs * 0.0125, 0.09, 0.022, 0.004, dark=True)
        _blood(m, g, 0.27, 0.014, zs * 0.0125, 0.05, 0.016, 0.004)


def axe(m):
    """Balta: kalın sap ve sola (savuruş yönüne) bakan geniş, kanlı ağız."""
    g = _joint(m)
    m.part(g, "cyl", WOOD, loc=(0.2, 0, 0), rot=(0, 90, 0), r1=0.026, r2=0.021, h=0.64, n=6, grime=0.45)
    m.part(g, "cyl", LEATHER, loc=(0.0, 0, 0), rot=(0, 90, 0), r1=0.029, r2=0.029, h=0.13, n=6)
    t = 0.014
    m.part(g, "hull", STEEL, glow=True, shine=0.6, grime=0.4,
           points=[(0.39, 0.0, -t), (0.52, 0.0, -t), (0.39, 0.0, t), (0.52, 0.0, t),
                   (0.34, 0.2, -t * 0.6), (0.57, 0.2, -t * 0.6), (0.34, 0.2, t * 0.6), (0.57, 0.2, t * 0.6),
                   (0.455, 0.245, 0)])
    m.part(g, "hull", IRON, shine=0.4, points=[(0.42, 0.0, -t), (0.49, 0.0, -t), (0.42, 0.0, t), (0.49, 0.0, t),
                                               (0.455, -0.1, 0)])
    for zs in (-1.0, 1.0):
        _blood(m, g, 0.455, 0.19, zs * 0.011, 0.19, 0.07, 0.004)
        _blood(m, g, 0.43, 0.1, zs * 0.013, 0.05, 0.08, 0.004, dark=True)


def fist(m):
    """Demir yumruk: çivili, kanlı demir eldiven (her iki ele giydirilir)."""
    g = _joint(m)
    m.part(g, "box", IRON, loc=(0.025, 0, 0), sx=0.14, sy=0.125, sz=0.125, top=(0.9, 0.9), shine=0.6, grime=0.4)
    m.part(g, "box", "#34363a", loc=(-0.06, 0, 0), sx=0.07, sy=0.135, sz=0.135, shine=0.4)
    for y in (-0.04, 0.0, 0.04):
        m.part(g, "cyl", STEEL, glow=True, loc=(0.125, y, 0.012), rot=(0, 90, 0), r1=0.02, r2=0.0, h=0.08, n=5, shine=0.8)
    _blood(m, g, 0.097, 0.01, 0.0, 0.01, 0.1, 0.07)


def _rod(m, g, color, x0, x1, r0, r1, n=6, grime=0.45):
    """+X boyunca sap/değnek."""
    m.part(g, "cyl", color, loc=((x0 + x1) * 0.5, 0, 0), rot=(0, 90, 0), r1=r0, r2=r1, h=x1 - x0, n=n, grime=grime)


def _segment(m, g, color, a, b, r, **kw):
    """İki nokta arasında ince silindir (yay kolları, zincir)."""
    ax, ay, az = a
    bx, by, bz = b
    dx, dy, dz = bx - ax, by - ay, bz - az
    ln = math.sqrt(dx * dx + dy * dy + dz * dz)
    pitch = math.degrees(math.acos(max(-1.0, min(1.0, dz / ln))))
    yaw = math.degrees(math.atan2(dy, dx))
    m.part(g, "cyl", color, loc=((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2), rot=(0, pitch, yaw), r1=r, r2=r, h=ln, n=5, **kw)


def scythe(m):
    """Tırpan: uzun kara sap, sola kıvrılan geniş ve kanlı ağız, sapa sarılı bez."""
    g = _joint(m)
    _rod(m, g, "#2e2219", -0.18, 0.74, 0.022, 0.02)
    m.part(g, "cyl", "#4a1414", loc=(0.05, 0, 0), rot=(0, 90, 0), r1=0.027, r2=0.027, h=0.1, n=6)
    t = 0.012
    m.part(g, "hull", STEEL, glow=True, shine=0.6, grime=0.4,
           points=[(0.7, 0.0, -t), (0.76, 0.0, -t), (0.7, 0.0, t), (0.76, 0.0, t), (0.73, 0.12, -t), (0.73, 0.12, t),
                   (0.66, 0.26, 0.0), (0.6, 0.34, 0.0), (0.68, 0.2, t * 0.5), (0.7, 0.18, -t * 0.5)])
    m.part(g, "hull", IRON, shine=0.4, points=[(0.68, -0.02, -0.02), (0.78, -0.02, -0.02), (0.68, -0.02, 0.02),
                                               (0.78, -0.02, 0.02), (0.73, -0.07, 0.0)])
    for zs in (-1.0, 1.0):
        _blood(m, g, 0.69, 0.2, zs * 0.009, 0.06, 0.12, 0.004)


def dagger(m):
    """Hançer: kemik saplı, kısa kavisli ve kanlı bıçak."""
    g = _joint(m)
    m.part(g, "cyl", "#cfc6b0", rot=(0, 90, 0), r1=0.02, r2=0.018, h=0.12, n=6, shine=0.3)
    m.part(g, "box", IRON, loc=(0.07, 0, 0), sx=0.025, sy=0.1, sz=0.03, shine=0.5)
    t = 0.01
    m.part(g, "hull", STEEL, glow=True, shine=0.7, grime=0.35,
           points=[(0.08, -0.025, -t), (0.08, 0.025, -t), (0.08, -0.025, t), (0.08, 0.025, t),
                   (0.22, 0.01, -t), (0.22, 0.03, t), (0.3, 0.035, 0.0)])
    for zs in (-1.0, 1.0):
        _blood(m, g, 0.22, 0.02, zs * 0.011, 0.1, 0.03, 0.004)


def mace(m):
    """Gürz: kısa sap, çivili demir topuz, kan ve et parçaları."""
    g = _joint(m)
    _rod(m, g, "#3a2a1c", -0.1, 0.4, 0.024, 0.024)
    m.part(g, "cyl", LEATHER, loc=(0.0, 0, 0), rot=(0, 90, 0), r1=0.028, r2=0.028, h=0.12, n=6)
    m.part(g, "ico", IRON, glow=True, loc=(0.45, 0, 0), r=0.085, sub=1, shine=0.5, grime=0.45)
    for d in ((1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1), (0.6, 0.6, 0.5), (0.6, -0.6, -0.5), (0.6, -0.5, 0.6)):
        n = math.sqrt(sum(v * v for v in d))
        d = tuple(v / n for v in d)
        _segment(m, g, STEEL, (0.45 + d[0] * 0.07, d[1] * 0.07, d[2] * 0.07),
                 (0.45 + d[0] * 0.14, d[1] * 0.14, d[2] * 0.14), 0.012, shine=0.8)
    m.part(g, "ico", BLOOD, loc=(0.47, 0.03, 0.05), scale=(1.0, 1.0, 0.5), r=0.05, sub=1, shine=0.7)
    m.part(g, "ico", BLOOD_D, loc=(0.42, -0.04, -0.04), scale=(1.0, 1.0, 0.5), r=0.04, sub=1, shine=0.7)


def bow(m):
    """Yay: kara ağaç, kemik uçlu kollar (dikey), kiriş; tutma yeri deri sargılı. Ok yönü +X."""
    g = _joint(m)
    pts = []
    for i in range(9):
        z = -0.38 + 0.76 * i / 8.0
        pts.append((0.08 - 0.13 * (z / 0.38) ** 2, 0.0, z))
    for a, b in zip(pts, pts[1:]):
        _segment(m, g, "#3a2618", a, b, 0.017 if abs(a[2]) < 0.2 else 0.013, glow=abs(a[2]) > 0.15, grime=0.4)
    m.part(g, "cyl", LEATHER, loc=(0.08, 0, 0), r1=0.024, r2=0.024, h=0.12, n=6)
    for s in (-1.0, 1.0):
        m.part(g, "hull", "#cfc6b0", points=[(-0.05, -0.01, s * 0.37), (-0.05, 0.01, s * 0.37), (-0.03, 0.0, s * 0.35),
                                             (-0.08, 0.0, s * 0.46)], shine=0.3)
    _segment(m, g, "#c9c0a8", (-0.05, 0, -0.37), (-0.05, 0, 0.37), 0.004)
    _blood(m, g, 0.085, 0.0, 0.08, 0.01, 0.03, 0.06)


def crossbow(m):
    """Arbalet: kalın ahşap kundak, demir yay kolları, gergin kiriş ve yerleştirilmiş kanlı cıvata."""
    g = _joint(m)
    m.part(g, "box", "#3e2a1a", loc=(0.06, 0, 0.0), sx=0.42, sy=0.06, sz=0.06, top=(1.0, 0.8), grime=0.45)
    m.part(g, "box", "#3e2a1a", loc=(-0.1, 0, -0.04), sx=0.1, sy=0.05, sz=0.1)
    for s in (-1.0, 1.0):
        _segment(m, g, IRON, (0.25, 0.0, 0.02), (0.2, s * 0.24, 0.02), 0.016, shine=0.6, glow=True)
        _segment(m, g, "#c9c0a8", (0.2, s * 0.24, 0.02), (0.06, 0.0, 0.035), 0.004)
    _segment(m, g, "#6b5033", (0.05, 0, 0.04), (0.34, 0, 0.04), 0.008)
    m.part(g, "hull", STEEL, shine=0.7, points=[(0.34, -0.012, 0.04), (0.34, 0.012, 0.04), (0.34, 0.0, 0.052),
                                                (0.34, 0.0, 0.028), (0.39, 0.0, 0.04)])
    _blood(m, g, 0.35, 0.0, 0.052, 0.04, 0.02, 0.006)


def spear(m):
    """Mızrak: uzun sap, geniş yaprak uç, uca bağlı kanlı bez."""
    g = _joint(m)
    _rod(m, g, "#3a2a1c", -0.35, 0.86, 0.02, 0.018)
    m.part(g, "cyl", LEATHER, loc=(0.0, 0, 0), rot=(0, 90, 0), r1=0.024, r2=0.024, h=0.14, n=6)
    t = 0.011
    m.part(g, "hull", STEEL, glow=True, shine=0.7, grime=0.35,
           points=[(0.86, -0.02, -t), (0.86, 0.02, -t), (0.86, -0.02, t), (0.86, 0.02, t), (0.95, -0.055, 0.0),
                   (0.95, 0.055, 0.0), (1.1, 0.0, 0.0)])
    m.part(g, "box", IRON, loc=(0.86, 0, 0), sx=0.02, sy=0.08, sz=0.02, shine=0.5)
    m.part(g, "prism", "#6e1414", loc=(0.8, 0, -0.01), rot=(90, 0, 0), points=[(0.0, 0.0), (0.03, 0.0), (0.04, -0.14),
                                                                               (0.015, -0.1), (-0.005, -0.15)], t=0.01)
    for zs in (-1.0, 1.0):
        _blood(m, g, 0.98, 0.0, zs * 0.012, 0.1, 0.05, 0.004)


def tome(m):
    """Kitap: deri kaplı, demir köşeli, kapağında kafatası; sayfa kenarları element rengiyle parlar."""
    g = _joint(m)
    m.part(g, "box", "#3a1a14", loc=(0.1, 0, 0.0), sx=0.2, sy=0.03, sz=0.25, grime=0.45)
    m.part(g, "box", "#d8ccb0", glow=True, loc=(0.1, 0.0, 0.0), sx=0.18, sy=0.036, sz=0.23)
    for s in (-1.0, 1.0):
        m.part(g, "box", "#3a1a14", loc=(0.1, s * 0.022, 0.0), sx=0.21, sy=0.012, sz=0.26, grime=0.45)
        for cx, cz in ((0.2, 0.12), (0.2, -0.12), (0.0, 0.12), (0.0, -0.12)):
            m.part(g, "box", IRON, loc=(cx, s * 0.03, cz), sx=0.03, sy=0.006, sz=0.03, shine=0.6)
        m.part(g, "sphere", "#cfc6b0", loc=(0.1, s * 0.03, 0.02), scale=(1.0, 0.4, 1.0), r=0.035, u=6, v=4, shine=0.3)
    _blood(m, g, 0.13, 0.03, -0.06, 0.05, 0.004, 0.06)


def staff(m):
    """Asa: burulmuş kara değnek, ucunda pençelerin tuttuğu parlayan küre ve asılı kemikler."""
    g = _joint(m)
    _rod(m, g, "#2a1d14", -0.25, 0.6, 0.02, 0.026)
    m.part(g, "cyl", "#4a1414", loc=(0.02, 0, 0), rot=(0, 90, 0), r1=0.026, r2=0.026, h=0.1, n=6)
    for k in range(3):
        a = k * 2.0 * math.pi / 3.0
        _segment(m, g, "#2a1d14", (0.6, 0, 0), (0.7, math.cos(a) * 0.06, math.sin(a) * 0.06), 0.012)
        _segment(m, g, "#2a1d14", (0.7, math.cos(a) * 0.06, math.sin(a) * 0.06), (0.76, math.cos(a) * 0.03, math.sin(a) * 0.03), 0.009)
    m.part(g, "ico", "#e8e0ff", glow=True, emit=True, loc=(0.7, 0, 0), r=0.05, sub=1)
    m.part(g, "sphere", "#cfc6b0", loc=(0.56, 0.0, -0.07), r=0.022, u=6, v=4, shine=0.3)
    _segment(m, g, "#55575c", (0.58, 0, -0.02), (0.56, 0, -0.05), 0.004)


def rune(m):
    """Rün taşı: elde tutulan yassı kara taş, oyulmuş rünler element rengiyle parlar."""
    g = _joint(m)
    m.part(g, "hull", "#3a3a40", grime=0.5, shine=0.2,
           points=[(0.02, -0.05, 0.1), (0.02, 0.05, 0.1), (0.16, -0.05, 0.05), (0.16, 0.05, 0.05), (0.02, -0.05, -0.08),
                   (0.02, 0.05, -0.08), (0.14, -0.05, -0.1), (0.14, 0.05, -0.1), (0.09, -0.06, 0.13), (0.09, 0.06, 0.13)])
    for s in (-1.0, 1.0):
        m.part(g, "box", "#f0e8ff", glow=True, loc=(0.09, s * 0.057, 0.0), sx=0.015, sy=0.006, sz=0.14)
        m.part(g, "box", "#f0e8ff", glow=True, loc=(0.09, s * 0.057, 0.02), rot=(0, 45 * s, 0), sx=0.012, sy=0.006, sz=0.08)
    _blood(m, g, 0.1, 0.05, -0.06, 0.04, 0.006, 0.04, dark=True)


WEAPONS = {
    "blade": blade,
    "axe": axe,
    "fist": fist,
    "scythe": scythe,
    "dagger": dagger,
    "mace": mace,
    "bow": bow,
    "crossbow": crossbow,
    "spear": spear,
    "tome": tome,
    "staff": staff,
    "rune": rune,
}

# Silah sayfası: 16 dönüş (cart açısı j × 22,5°) × bu eğimler (derece, burun yukarı pozitif)
YAWS = 16
PITCHES = [-60.0, -20.0, 20.0, 60.0]


def reach(m):
    """Tutma noktasından en uzak köşe (hücre boyu için)."""
    r = 0.0
    root_z = m.joints["root"].matrix_world.translation.z
    for ob in m.coll.objects:
        if ob.type != "MESH":
            continue
        mw = ob.matrix_world
        for v in ob.data.vertices:
            p = mw @ v.co
            r = max(r, math.sqrt(p.x ** 2 + p.y ** 2 + (p.z - root_z) ** 2))
    return r
