"""Zindan karo setleri (Aşama 8): 4 katın zemini, duvarı, engel sütunu, kilitli kapısı ve çatlak (gizli oda) duvarı.

Karo = 1×1 karo kare, 45° döndürülmüş (ekranda 64×32 elmas). Duvar ve blokların yüksekliği oyundaki 40 dünya pikseli
(1,02 karo). Her kat kendi taş renkleri ve süsleriyle gelir:
  1 Damarlı Mağara: kızıl-mor kaya, duvarlarda damarlar ve gözler, yerde kemikler
  2 Mantar Mağaraları: yosunlu yeşil taş, parlayan mantarlar
  3 Kül Dökümhanesi: is kara taş levhalar, aralarından lav parlar, demir plakalar
  4 Boşluk: mor-kara taş platform, parlayan boşluk kristalleri
Varyantlar oyunda hücreye göre (seed'li hash) seçilir. Parlayan parçalar ayrı ışıma katmanına da yazılır.
"""

import math
import random

from mathutils import Vector

WALL_H = 40.0 / (45.254834 * math.cos(math.radians(30.0)))   # 40 dünya pikseli yükseklik

PALETTES = {
    1: {"stones": ["#4a3238", "#553a40", "#3e2a30", "#5a4046"], "mortar": "#1c1216", "wall": ["#3a2630", "#452e36", "#31202a"],
        "top": "#553a44", "accent": "#7a1a2a", "glow": "#ff3a4a"},
    2: {"stones": ["#34402e", "#3c4834", "#2c3628", "#444f38"], "mortar": "#141a12", "wall": ["#2e3828", "#36422e", "#263020"],
        "top": "#3d5a3a", "accent": "#3f6a2a", "glow": "#b070ff"},
    3: {"stones": ["#3a3230", "#2e2826", "#453c38", "#342c2a"], "mortar": "#120e0c", "wall": ["#302a28", "#3a3230", "#26201e"],
        "top": "#4a3a2e", "accent": "#5a4a3a", "glow": "#ff6a1a"},
    4: {"stones": ["#262236", "#2e2a40", "#1e1a2c", "#34304a"], "mortar": "#0a0812", "wall": ["#201c30", "#28243a", "#181426"],
        "top": "#2a2440", "accent": "#3a2a5a", "glow": "#9a6aff"},
}

FLOOR_VARIANTS = 4
WALL_VARIANTS = 3
PILLAR_VARIANTS = 2
BLOCKS = ["wall0", "wall1", "wall2", "pillar0", "pillar1", "door", "cracked"]


def _diamond_uv(u, v):
    """Karonun yerel kare koordinatı (u, v ∈ 0..1) → Blender XY (45° dönük kare, merkez orijin)."""
    x = (u - 0.5)
    y = (v - 0.5)
    c = math.cos(math.radians(45.0))
    return (x * c - y * c, x * c + y * c)


def _stone(m, j, u0, v0, u1, v1, z0, z1, color, rng, inset=0.035, **kw):
    pts = []
    for (u, v) in ((u0 + inset, v0 + inset), (u1 - inset, v0 + inset), (u1 - inset, v1 - inset), (u0 + inset, v1 - inset)):
        u += rng.uniform(-0.015, 0.015)
        v += rng.uniform(-0.015, 0.015)
        x, y = _diamond_uv(u, v)
        pts.append((x, y, z0))
        x2, y2 = _diamond_uv(u + (0.5 - u) * 0.06, v + (0.5 - v) * 0.06)
        pts.append((x2, y2, z1 + rng.uniform(-0.004, 0.004)))
    m.part(j, "hull", color, points=pts, grime=0.55, **kw)


def floor_tile(m, floor, variant, seed):
    """Zemin: harç üstünde düzensiz taş levhalar; varyanta göre çatlak, kemik, kan ve kata özgü süs."""
    pal = PALETTES[floor]
    rng = random.Random(seed)
    j = m.joint("tile", "root", (0, 0, 0))
    m.part(j, "hull", pal["mortar"], points=[(*_diamond_uv(u, v), z) for u in (0.0, 1.0) for v in (0.0, 1.0) for z in (-0.05, -0.012)],
           grime=0.5)
    # Levhaları rastgele böl: 2 ya da 3 sıra
    rows = rng.choice([2, 2, 3])
    v_cuts = sorted([0.0, 1.0] + [rng.uniform(0.3, 0.7)] if rows == 2 else [0.0, 1.0, rng.uniform(0.25, 0.4), rng.uniform(0.6, 0.75)])
    for a, b in zip(v_cuts, v_cuts[1:]):
        n = rng.choice([1, 2, 2])
        u_cuts = sorted([0.0, 1.0] + [rng.uniform(0.3, 0.7) for _ in range(n - 1)])
        for c, d in zip(u_cuts, u_cuts[1:]):
            _stone(m, j, c, a, d, b, -0.012, 0.004 + rng.uniform(0.0, 0.012), rng.choice(pal["stones"]), rng, shine=0.1)
    if variant >= 1:
        # çatlak
        u, v = rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8)
        for k in range(3):
            du, dv = rng.uniform(-0.18, 0.18), rng.uniform(-0.18, 0.18)
            x0, y0 = _diamond_uv(u, v)
            x1, y1 = _diamond_uv(u + du, v + dv)
            _seg(m, j, pal["mortar"], (x0, y0, 0.012), (x1, y1, 0.012), 0.008)
            u, v = u + du, v + dv
    if variant == 2:
        if floor in (1, 3):
            # kemikler / kafatası
            x, y = _diamond_uv(rng.uniform(0.3, 0.7), rng.uniform(0.3, 0.7))
            m.part(j, "sphere", "#cfc6b0", loc=(x, y, 0.04), scale=(1.0, 0.9, 0.9), r=0.05, u=7, v=5, shine=0.3)
            m.part(j, "box", "#1a1414", loc=(x + 0.03, y - 0.02, 0.05), sx=0.015, sy=0.03, sz=0.015)
            for k in range(2):
                a = rng.uniform(0, math.pi)
                bx, by = _diamond_uv(rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8))
                _seg(m, j, "#bfb59c", (bx - 0.08 * math.cos(a), by - 0.08 * math.sin(a), 0.02),
                     (bx + 0.08 * math.cos(a), by + 0.08 * math.sin(a), 0.02), 0.012, shine=0.3)
        elif floor == 2:
            for k in range(3):
                x, y = _diamond_uv(rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8))
                h = rng.uniform(0.04, 0.08)
                m.part(j, "cyl", "#c8b8a0", loc=(x, y, h / 2), r1=0.012, r2=0.01, h=h, n=5)
                m.part(j, "sphere", pal["glow"] if k == 0 else "#6a3a2a", loc=(x, y, h), scale=(1, 1, 0.5), r=0.035,
                       u=7, v=4, emit=k == 0)
        else:
            for k in range(2):
                x, y = _diamond_uv(rng.uniform(0.25, 0.75), rng.uniform(0.25, 0.75))
                m.part(j, "hull", pal["glow"], emit=True, points=[(x - 0.02, y, 0.0), (x + 0.02, y, 0.0), (x, y + 0.02, 0.0),
                                                                  (x + rng.uniform(-0.02, 0.02), y, rng.uniform(0.06, 0.12))])
    if variant == 3:
        if floor == 1:
            # yerde sürünen damarlar
            for k in range(2):
                pts = [_diamond_uv(rng.uniform(0.0, 1.0), rng.uniform(0.0, 1.0)) for _ in range(3)]
                for a, b in zip(pts, pts[1:]):
                    _seg(m, j, pal["accent"], (a[0], a[1], 0.015), (b[0], b[1], 0.015), 0.018, shine=0.5)
        elif floor == 3:
            # taş aralarında lav
            for k in range(2):
                a = _diamond_uv(rng.uniform(0.1, 0.9), rng.uniform(0.1, 0.9))
                b = _diamond_uv(rng.uniform(0.1, 0.9), rng.uniform(0.1, 0.9))
                _seg(m, j, pal["glow"], (a[0], a[1], 0.008), (b[0], b[1], 0.008), 0.012, emit=True)
        # kan
        x, y = _diamond_uv(rng.uniform(0.3, 0.7), rng.uniform(0.3, 0.7))
        m.part(j, "ico", "#5a0707", loc=(x, y, 0.012), scale=(1.4, 1.0, 0.05), r=0.12, sub=1, shine=0.6, grime=0.3)


def _seg(m, j, color, a, b, r, **kw):
    ax, ay, az = a
    bx, by, bz = b
    dx, dy, dz = bx - ax, by - ay, bz - az
    ln = max(math.sqrt(dx * dx + dy * dy + dz * dz), 1e-4)
    pitch = math.degrees(math.acos(max(-1.0, min(1.0, dz / ln))))
    yaw = math.degrees(math.atan2(dy, dx))
    m.part(j, "cyl", color, loc=((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2), rot=(0, pitch, yaw), r1=r, r2=r, h=ln, n=5, **kw)


def _bricks(m, j, pal, rng, colors, courses=4, h=WALL_H):
    """Bloğun görünen iki yüzüne (−X ve −Y'ye bakan) tuğla sıraları, üstte kaba kapak."""
    c45 = math.cos(math.radians(45.0))
    m.part(j, "hull", pal["mortar"], points=[(*_diamond_uv(u, v), z) for u in (0.02, 0.98) for v in (0.02, 0.98)
                                            for z in (0.0, h - 0.02)])
    ch = h / courses
    for face in (0, 1):
        for k in range(courses):
            n = 2 if (k + face) % 2 == 0 else 3
            cuts = sorted([0.0, 1.0] + [rng.uniform(0.3, 0.7) for _ in range(n - 1)])
            for a, b in zip(cuts, cuts[1:]):
                # yüz 0: v = 0 kenarı (−Y'ye bakan), yüz 1: u = 0 kenarı
                pts = []
                for t in (a + 0.02, b - 0.02):
                    for z in (k * ch + 0.012, (k + 1) * ch - 0.012):
                        for depth in (0.0, 0.06):
                            u, v = (t, -0.005 + depth) if face == 0 else (-0.005 + depth, t)
                            x, y = _diamond_uv(u, v)
                            pts.append((x, y, z + rng.uniform(-0.006, 0.006)))
                m.part(j, "hull", rng.choice(colors), points=pts, grime=0.6, shine=0.08)
    # kapak taşları
    for (u0, v0, u1, v1) in ((0.0, 0.0, 0.5, 0.55), (0.5, 0.0, 1.0, 0.5), (0.0, 0.55, 0.5, 1.0), (0.5, 0.5, 1.0, 1.0)):
        _stone(m, j, u0, v0, u1, v1, h - 0.03, h + rng.uniform(0.0, 0.012), pal["top"], rng, inset=0.02)
    del c45


def block(m, floor, name, seed):
    pal = PALETTES[floor]
    rng = random.Random(seed)
    j = m.joint("tile", "root", (0, 0, 0))
    if name.startswith("wall"):
        variant = int(name[-1])
        _bricks(m, j, pal, rng, pal["wall"])
        if variant == 1:
            _wall_decor(m, j, floor, pal, rng, big=False)
        elif variant == 2:
            _wall_decor(m, j, floor, pal, rng, big=True)
    elif name == "cracked":
        _bricks(m, j, pal, rng, [_lighter(c, 0.18) for c in pal["wall"]])
        for face in (0, 1):
            pts = [(0.5 + rng.uniform(-0.1, 0.1), 0.1)]
            for k in range(4):
                pts.append((pts[-1][0] + rng.uniform(-0.15, 0.15), pts[-1][1] + WALL_H * 0.22))
            for a, b in zip(pts, pts[1:]):
                pa = _face_point(face, a[0], a[1], 0.07)
                pb = _face_point(face, b[0], b[1], 0.07)
                _seg(m, j, "#0a0606", pa, pb, 0.012)
                _seg(m, j, "#d8c8b0", (pa[0], pa[1], pa[2] + 0.01), (pb[0], pb[1], pb[2] + 0.01), 0.005)
    elif name == "door":
        # demir parmaklıklı kapı: yalnızca parmaklıklar ve üst kiriş (arkası görünür)
        for k in range(5):
            t = 0.1 + 0.2 * k
            for face in (0, 1):
                a = _face_point(face, t, 0.0, 0.2)
                b = _face_point(face, t, WALL_H, 0.2)
                _seg(m, j, "#2a2a2e", a, b, 0.022, shine=0.6)
                _seg(m, j, "#8a3a1a", (b[0], b[1], b[2] - 0.05), (b[0], b[1], b[2] + 0.02), 0.03, shine=0.4)
        for face in (0, 1):
            for z in (0.15, WALL_H - 0.08):
                _seg(m, j, "#3a3a40", _face_point(face, 0.02, z, 0.2), _face_point(face, 0.98, z, 0.2), 0.02, shine=0.6)
    elif name.startswith("pillar"):
        variant = int(name[-1])
        _pillar(m, j, floor, pal, rng, variant)


def _lighter(hex_color, k):
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02x%02x%02x" % (min(255, int(r + (255 - r) * k)), min(255, int(g + (255 - g) * k)), min(255, int(b + (255 - b) * k)))


def _face_point(face, t, z, depth):
    u, v = (t, depth) if face == 0 else (depth, t)
    x, y = _diamond_uv(u, v)
    return (x, y, z)


def _wall_decor(m, j, floor, pal, rng, big):
    face = rng.choice([0, 1])
    if floor == 1:
        # damarlar ve duvara gömülü göz
        for k in range(3 if big else 2):
            a = _face_point(face, rng.uniform(0.1, 0.9), rng.uniform(0.0, 0.3), -0.02)
            b = _face_point(face, rng.uniform(0.1, 0.9), rng.uniform(0.6, WALL_H), -0.02)
            _seg(m, j, pal["accent"], a, b, 0.022, shine=0.5)
        if big:
            p = _face_point(face, 0.5, WALL_H * 0.55, -0.04)
            m.part(j, "sphere", "#6a1a2a", loc=p, r=0.11, u=9, v=7, smooth=True, shine=0.5)
            q = _face_point(face, 0.5, WALL_H * 0.55, -0.1)
            m.part(j, "sphere", "#e6dccb", loc=q, r=0.07, u=8, v=6, smooth=True, shine=0.6)
            r = _face_point(face, 0.5, WALL_H * 0.55, -0.16)
            m.part(j, "sphere", pal["glow"], loc=r, r=0.03, u=6, v=4, emit=True)
    elif floor == 2:
        for k in range(4 if big else 2):
            p = _face_point(face, rng.uniform(0.1, 0.9), rng.uniform(0.0, WALL_H), -0.02)
            m.part(j, "ico", pal["accent"], loc=p, scale=(1.0, 1.0, 0.6), r=rng.uniform(0.06, 0.1), sub=1, grime=0.6)
        if big:
            for k in range(3):
                p = _face_point(face, 0.3 + 0.2 * k, WALL_H * (0.3 + 0.15 * k), -0.06)
                m.part(j, "sphere", pal["glow"], loc=p, scale=(1.0, 1.0, 0.4), r=0.05, u=7, v=4, emit=True)
    elif floor == 3:
        for k in range(2 if big else 1):
            pts = [(rng.uniform(0.2, 0.8), 0.05)]
            for i in range(3):
                pts.append((pts[-1][0] + rng.uniform(-0.2, 0.2), pts[-1][1] + WALL_H * 0.28))
            for a, b in zip(pts, pts[1:]):
                _seg(m, j, pal["glow"], _face_point(face, a[0], a[1], -0.005), _face_point(face, b[0], b[1], -0.005), 0.014,
                     emit=True)
        if big:
            p = _face_point(face, 0.5, WALL_H * 0.5, -0.02)
            m.part(j, "box", "#2e3036", loc=p, rot=(0, 0, 45 if face == 0 else -45), sx=0.4, sy=0.03, sz=0.35, shine=0.6)
    else:
        for k in range(3 if big else 1):
            p = _face_point(face, rng.uniform(0.2, 0.8), rng.uniform(0.1, WALL_H * 0.7), -0.03)
            m.part(j, "hull", pal["glow"], emit=True, points=[(p[0] - 0.03, p[1], p[2]), (p[0] + 0.03, p[1], p[2]),
                                                              (p[0], p[1] - 0.03, p[2]), (p[0], p[1] - 0.06, p[2] + 0.2)])


def _pillar(m, j, floor, pal, rng, variant):
    """Engel sütunu: 1: kırık taş sütun / kaya · 2: iri mantar · 3: örs ya da kor dolu mangal · 4: boşluk kristali."""
    base = pal["wall"][0]
    m.part(j, "hull", pal["mortar"], points=[(*_diamond_uv(u, v), 0.02) for u in (0.08, 0.92) for v in (0.08, 0.92)] +
           [(0, 0, 0.0)])
    if floor == 2 and variant == 1:
        m.part(j, "cyl", "#b8a488", loc=(0, 0, 0.35), r1=0.16, r2=0.12, h=0.7, n=9, smooth=True, grime=0.5)
        m.part(j, "sphere", "#5a2a6a", loc=(0, 0, 0.75), scale=(1.0, 1.0, 0.45), r=0.42, u=12, v=8, smooth=True, shine=0.3)
        for k in range(6):
            a = k * 1.05
            m.part(j, "sphere", pal["glow"], loc=(0.25 * math.cos(a), 0.25 * math.sin(a), 0.86), scale=(1, 1, 0.4), r=0.05,
                   u=6, v=4, emit=True)
        return
    if floor == 4 and variant == 1:
        for k in range(4):
            a = k * 1.6
            h = rng.uniform(0.6, 1.1)
            x, y = 0.12 * math.cos(a), 0.12 * math.sin(a)
            m.part(j, "hull", "#2a1a4a" if k else pal["glow"], emit=k == 0, shine=0.7,
                   points=[(x - 0.08, y, 0.0), (x + 0.08, y, 0.0), (x, y - 0.08, 0.0), (x, y + 0.08, 0.0),
                           (x * 1.5 + rng.uniform(-0.05, 0.05), y * 1.5, h)])
        return
    if floor == 3 and variant == 1:
        m.part(j, "cyl", "#2e3036", loc=(0, 0, 0.18), r1=0.3, r2=0.34, h=0.36, n=10, shine=0.6, grime=0.5)
        m.part(j, "cyl", pal["glow"], loc=(0, 0, 0.37), r1=0.28, r2=0.28, h=0.02, n=10, emit=True)
        for k in range(5):
            a = k * 1.25
            m.part(j, "ico", "#2a2220", loc=(0.15 * math.cos(a), 0.15 * math.sin(a), 0.4), r=0.06, sub=1)
        return
    # kırık taş sütun (her kat, kendi renginde)
    h = WALL_H * (1.1 if variant == 0 else 0.7)
    for k in range(4):
        z0 = h * k / 4
        r0 = 0.3 - 0.02 * k
        m.part(j, "cyl", rng.choice(pal["wall"]), loc=(rng.uniform(-0.01, 0.01), rng.uniform(-0.01, 0.01), z0 + h / 8),
               rot=(rng.uniform(-3, 3), rng.uniform(-3, 3), rng.uniform(0, 30)), r1=r0, r2=r0 - 0.01, h=h / 4 - 0.01, n=8,
               grime=0.6, shine=0.08)
    m.part(j, "cyl", pal["top"], loc=(0, 0, h + 0.03), r1=0.3, r2=0.26, h=0.06, n=8, grime=0.5)
    if variant == 1:
        for k in range(3):
            a = rng.uniform(0, 2 * math.pi)
            m.part(j, "ico", base, loc=(0.35 * math.cos(a), 0.35 * math.sin(a), 0.05), r=rng.uniform(0.06, 0.1), sub=1, grime=0.6)
    if floor == 1:
        _seg(m, j, pal["accent"], (0.25, -0.1, 0.1), (0.2, -0.15, h * 0.8), 0.02, shine=0.5)
