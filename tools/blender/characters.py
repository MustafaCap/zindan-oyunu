"""Karakter modelleri (Aşama 8): koddan düşük poligonlu gövdeler. Her kurucu Model'i doldurur ve sözlük döndürür.

Görsel yön (Aşama 8): karanlık, kanlı, vahşi — şövalye parlaklığı yok. Soluk renkler, kirli yüzeyler
(malzemelerdeki gürültü), kan lekeleri ve ıslak kan parlaması, karanlıkta yanan gözler.
Dönen sözlük: {"hand": silah eli, "grip": elin içindeki tutma noktası (yerel), "anims": animasyon seti}.
"""

import math

import humanoid as hu

BLOOD = "#920f0f"
BLOOD_D = "#5a0707"
EYE_DARK = "#140f0e"

_NORMAL_ROT = {"+x": (0, 90, 0), "-x": (0, -90, 0), "+y": (-90, 0, 0), "-y": (90, 0, 0), "+z": (0, 0, 0), "-z": (180, 0, 0)}


def splat(m, joint, loc, r, normal="+x", dark=False, stretch=1.0):
    """Yüzeye yapışık kan lekesi (yassı, ıslak parlayan)."""
    m.part(joint, "ico", BLOOD_D if dark else BLOOD, loc=loc, rot=_NORMAL_ROT[normal], scale=(1.0, stretch, 0.16),
           shine=0.6, grime=0.25, r=r, sub=1)


def _flap(y0, y1, depth, teeth=4):
    """Y-Z düzleminde yırtık alt kenarlı kumaş parçası: üst kenar z=0.03, alt kenar ~depth (dişli)."""
    pts = [(y0, 0.03), (y1, 0.03)]
    n = teeth * 2
    for i in range(n + 1):
        y = y1 + (y0 - y1) * i / n
        z = -depth * (1.0 if i % 2 == 0 else 0.78) - (0.03 if i % 3 == 1 else 0.0)
        pts.append((y, z))
    return pts


def warrior(m):
    """Warrior: kapüşonlu, gözleri yanan, kül tenli iri savaşçı. Kolsuz deri yelek, kanlı yırtık etek, deri bileklikler
    (solda demir bileklik: Kalkan Hücumu'nda kalkan buradan açılır), diz boyu çizmeler ve çelik dizlikler."""
    hu.skeleton(m, {"hip_h": 0.52, "thigh": 0.23, "shin": 0.22, "shoulder_h": 0.31, "shoulder_w": 0.2,
                    "upper": 0.2, "fore": 0.18, "neck": 0.37})
    skin = "#7f7870"
    skin_d = "#3d3935"
    hood = "#1b1715"
    vest = "#3b302a"
    bracer = "#6a4428"
    iron = "#4c4f55"
    belt = "#5a3a22"
    buckle = "#8c8c92"
    cloth = "#74675a"
    trouser = "#211c19"
    boot = "#4a3322"
    knee = "#6a6c72"
    chain = "#5f6165"
    hand_c = "#5d5a57"

    # Bacaklar: pantolon, diz boyu çizme, çelik dizlik
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("hip_" + side, "cyl", trouser, loc=(0, 0, -0.115), r1=0.062, r2=0.075, h=0.24, n=8, smooth=True, grime=0.35)
        m.part("knee_" + side, "cyl", boot, loc=(0, 0, -0.1), r1=0.058, r2=0.068, h=0.2, n=8, shine=0.15, smooth=True)
        m.part("knee_" + side, "cyl", "#2e2119", loc=(0, 0, -0.005), r1=0.075, r2=0.075, h=0.035, n=8)
        m.part("knee_" + side, "sphere", knee, loc=(0.045, 0, 0.01), scale=(0.8, 1.0, 1.15), r=0.055, u=7, v=5, shine=0.7)
        m.part("ankle_" + side, "box", boot, loc=(0.035, 0, -0.035), sx=0.19, sy=0.095, sz=0.08, top=(0.8, 1.0), shine=0.15)
        m.part("ankle_" + side, "box", "#1c1512", loc=(0.035, 0, -0.068), sx=0.2, sy=0.1, sz=0.015)
        # Etek: önde ve arkada yırtık kumaş parçaları (uyluğa bağlı, bacakla sallanır)
        hy = s * 0.085
        m.part("hip_" + side, "prism", cloth, loc=(0.095, 0, 0), grime=0.45,
               points=_flap(-hy + s * 0.14, -hy - s * 0.005, 0.3), t=0.02)
        m.part("hip_" + side, "prism", cloth, loc=(-0.095, 0, 0), grime=0.45,
               points=_flap(-hy + s * 0.14, -hy - s * 0.005, 0.28), t=0.02)
    splat(m, "hip_r", (0.107, 0.03, -0.12), 0.03)
    splat(m, "hip_r", (0.107, -0.02, -0.21), 0.022, dark=True, stretch=1.6)
    splat(m, "hip_l", (0.107, -0.02, -0.08), 0.026)
    splat(m, "hip_l", (0.107, 0.04, -0.2), 0.02, dark=True)
    splat(m, "knee_r", (0.066, 0.0, -0.08), 0.022)
    splat(m, "ankle_l", (0.12, 0.0, -0.02), 0.02, dark=True)

    # Kalça: zincir zırh, iki kemer, toka
    m.part("hips", "cyl", chain, loc=(0, 0, -0.05), r1=0.15, r2=0.13, h=0.14, n=10, shine=0.35, grime=0.4)
    m.part("hips", "cyl", belt, loc=(0, 0, 0.035), r1=0.142, r2=0.138, h=0.055, n=10, shine=0.1)
    m.part("hips", "cyl", "#46301e", loc=(0, 0, -0.01), rot=(8, 0, 0), r1=0.152, r2=0.15, h=0.035, n=10)
    m.part("hips", "box", buckle, loc=(0.142, 0, 0.035), sx=0.025, sy=0.07, sz=0.055, shine=0.8)
    m.part("hips", "box", "#1c1512", loc=(0.152, 0, 0.035), sx=0.01, sy=0.035, sz=0.025)

    # Gövde: geniş göğüslü kolsuz deri yelek, göğüs kasları, bağcık, kan
    # Gövde: çıplak kaslı göğüs ve karın (kül rengi, parlak), önü açık kolsuz deri yelek, çapraz kılıç kayışı, kan
    m.part("torso", "box", skin, loc=(0, 0, 0.07), sx=0.19, sy=0.24, sz=0.14, top=(1.05, 1.12), shine=0.4, smooth=True)
    m.part("torso", "box", skin, loc=(0, 0, 0.22), sx=0.22, sy=0.3, sz=0.2, top=(1.06, 1.14), shine=0.4)
    for s in (-1.0, 1.0):
        m.part("torso", "sphere", skin, loc=(0.085, s * 0.072, 0.25), scale=(0.6, 1.0, 0.72), r=0.09, u=9, v=7,
               smooth=True, shine=0.5)
        for z in (0.06, 0.11, 0.16):
            m.part("torso", "sphere", skin, loc=(0.09, s * 0.035, z), scale=(0.5, 0.9, 0.7), r=0.04, u=7, v=5,
                   smooth=True, shine=0.5)
        # yelek: yan ve arka paneller, önde açık
        m.part("torso", "box", vest, loc=(-0.005, s * 0.125, 0.16), sx=0.25, sy=0.08, sz=0.32, top=(1.0, 1.1), shine=0.35)
    m.part("torso", "box", vest, loc=(-0.085, 0, 0.16), sx=0.08, sy=0.3, sz=0.32, top=(1.0, 1.1), shine=0.35)
    m.part("torso", "box", belt, loc=(0.02, 0, 0.19), rot=(38, 0, 0), sx=0.27, sy=0.045, sz=0.43, shine=0.15)
    m.part("torso", "box", buckle, loc=(0.135, 0.02, 0.2), rot=(38, 0, 0), sx=0.015, sy=0.05, sz=0.04, shine=0.8)
    m.part("torso", "cyl", skin, loc=(0, 0, 0.35), r1=0.075, r2=0.052, h=0.08, n=8, smooth=True, shine=0.3)
    m.part("torso", "cyl", hood, loc=(-0.01, 0, 0.345), r1=0.185, r2=0.1, h=0.07, n=9, grime=0.4)
    splat(m, "torso", (0.12, -0.08, 0.27), 0.03)
    splat(m, "torso", (0.125, 0.05, 0.1), 0.026, dark=True, stretch=1.6)
    splat(m, "torso", (0.115, 0.1, 0.21), 0.018)
    splat(m, "torso", (0.12, -0.03, 0.16), 0.014)

    # Kollar: çıplak kül rengi kaslı kollar, deri bileklik (solda demir), metal eldivenli eller
    for side, s in (("r", -1.0), ("l", 1.0)):
        sh = "shoulder_" + side
        m.part(sh, "sphere", skin, loc=(0, s * 0.012, -0.01), scale=(1.0, 1.0, 0.9), r=0.078, u=9, v=7, smooth=True, shine=0.45)
        m.part(sh, "cyl", skin, loc=(0, 0, -0.1), r1=0.05, r2=0.062, h=0.2, n=8, smooth=True, shine=0.45)
        m.part(sh, "sphere", skin, loc=(0.02, 0, -0.1), scale=(1.0, 0.9, 1.75), r=0.058, u=8, v=6, smooth=True, shine=0.45)
        el = "elbow_" + side
        m.part(el, "cyl", skin, loc=(0, 0, -0.09), r1=0.046, r2=0.056, h=0.18, n=8, smooth=True, shine=0.45)
        if side == "r":
            m.part(el, "cyl", bracer, loc=(0, 0, -0.1), r1=0.058, r2=0.064, h=0.12, n=8, shine=0.1)
            for z in (-0.07, -0.13):
                m.part(el, "sphere", iron, loc=(0.058, 0, z), r=0.012, u=5, v=3, shine=0.7)
        else:
            m.part(el, "cyl", iron, loc=(0, 0, -0.1), r1=0.063, r2=0.07, h=0.13, n=8, shine=0.6, grime=0.4)
            m.part(el, "box", "#35373c", loc=(0, 0.066, -0.1), sx=0.02, sy=0.02, sz=0.12, shine=0.5)
        hd = "hand_" + side
        m.part(hd, "box", hand_c, loc=(0.005, 0, -0.04), sx=0.078, sy=0.072, sz=0.082, shine=0.4)
        m.part(hd, "box", hand_c, loc=(0.035, -s * 0.032, -0.02), sx=0.03, sy=0.025, sz=0.05, shine=0.4)
    splat(m, "elbow_r", (0.055, 0.0, -0.03), 0.022)
    splat(m, "shoulder_r", (0.05, -0.02, -0.12), 0.02, dark=True, stretch=1.7)
    splat(m, "hand_r", (0.045, 0.0, -0.04), 0.022)

    # Baş: gölgedeki yüz, yanan göz yarıkları, kapüşon
    m.part("head", "sphere", skin_d, loc=(0.02, 0, 0.1), scale=(1.0, 0.9, 1.05), r=0.092, u=9, v=7, smooth=True)
    m.part("head", "box", skin_d, loc=(0.05, 0, 0.03), sx=0.1, sy=0.12, sz=0.06, top=(0.8, 0.85))
    m.part("head", "box", EYE_DARK, loc=(0.1, 0, 0.1), sx=0.03, sy=0.12, sz=0.035)
    for s in (-1.0, 1.0):
        m.part("head", "box", "#ff9a2a", loc=(0.117, s * 0.036, 0.103), sx=0.012, sy=0.03, sz=0.014, emit=True)
    # Kapüşon: başın çevresinde yuvarlak, önü açık (yüz derinde gölgede), altta omuzlara yayılan etek
    hood_pts = []
    for lv, (z, r) in enumerate([(0.205, 0.06), (0.175, 0.1), (0.115, 0.122), (0.035, 0.118), (-0.04, 0.15)]):
        for i in range(13):
            az = math.radians(50.0 + i * (260.0 / 12.0))
            back = 1.12 if math.cos(az) < 0 else 1.0
            hood_pts.append((-0.015 + math.cos(az) * r * back, math.sin(az) * r, z))
    hood_pts.append((-0.03, 0.0, 0.222))
    m.part("head", "hull", hood, points=hood_pts, grime=0.4, smooth=True, shine=0.1)

    # Kalkan (yalnızca Kalkan Hücumu'nda): sol demir bileklikten açılan çivili demir kalkan
    m.joint("shield", "elbow_l", (0.0, 0.08, -0.1), scale=0.001)
    m.part("shield", "cyl", "#26272b", loc=(0.012, 0, 0), rot=(0, 90, 0), r1=0.23, r2=0.23, h=0.02, n=12, shine=0.4)
    m.part("shield", "cyl", "#3d3f44", loc=(0.03, 0, 0), rot=(0, 90, 0), r1=0.205, r2=0.2, h=0.03, n=12, shine=0.55, grime=0.45)
    m.part("shield", "cyl", "#8a8c92", loc=(0.09, 0, 0), rot=(0, 90, 0), r1=0.05, r2=0.0, h=0.1, n=8, shine=0.8)
    for i in range(6):
        a = i / 6.0 * 2.0 * math.pi
        m.part("shield", "sphere", "#6d6f75", loc=(0.05, math.cos(a) * 0.16, math.sin(a) * 0.16), r=0.016, u=5, v=3, shine=0.8)
    splat(m, "shield", (0.048, 0.07, 0.05), 0.04)
    splat(m, "shield", (0.048, -0.09, -0.06), 0.03, dark=True, stretch=1.5)
    return {"hand": "hand_r", "hand_l": "hand_l", "grip": (0.005, 0, -0.04), "anims": hu.PLAYER_ANIMS + [hu.RUSH_ANIM]}


def _flaps(m, color, depth, fx=0.095, bx=-0.095, width=0.14, grime=0.45, back_depth=None):
    """Uyluklara bağlı önde ve arkada yırtık kumaş (etek/cübbe); bacakla birlikte sallanır."""
    for side, s in (("r", -1.0), ("l", 1.0)):
        hy = s * 0.085
        pts = _flap(-hy + s * width, -hy - s * 0.005, depth)
        m.part("hip_" + side, "prism", color, loc=(fx, 0, 0), grime=grime, points=pts, t=0.02)
        m.part("hip_" + side, "prism", color, loc=(bx, 0, 0), grime=grime,
               points=_flap(-hy + s * width, -hy - s * 0.005, back_depth or depth), t=0.02)


def _cape(m, joint, color, top_z, depth, half_w, x, grime=0.45, teeth=5):
    """Sırttan sarkan yırtık pelerin (Y-Z düzleminde levha)."""
    pts = [(-half_w, top_z), (half_w, top_z)]
    n = teeth * 2
    for i in range(n + 1):
        y = half_w - 2.0 * half_w * i / n
        z = top_z - depth * (1.0 if i % 2 == 0 else 0.8) - (0.04 if i % 3 == 1 else 0.0)
        pts.append((y, z))
    m.part(joint, "prism", color, loc=(x, 0, 0), grime=grime, points=pts, t=0.018)


def _limbs(m, c, arm_r=(0.04, 0.05), fore_r=(0.036, 0.044), thigh_r=(0.055, 0.066), shin_r=(0.045, 0.055)):
    """Kol ve bacakların temel parçaları (renkler c sözlüğünden)."""
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("shoulder_" + side, "cyl", c["upper"], loc=(0, 0, -0.1), r1=arm_r[0], r2=arm_r[1], h=0.21, n=8,
               smooth=True, shine=c.get("skin_shine", 0.2))
        m.part("elbow_" + side, "cyl", c["fore"], loc=(0, 0, -0.09), r1=fore_r[0], r2=fore_r[1], h=0.19, n=8,
               smooth=True, shine=c.get("skin_shine", 0.2))
        m.part("hip_" + side, "cyl", c["thigh"], loc=(0, 0, -0.115), r1=thigh_r[0], r2=thigh_r[1], h=0.24, n=8, smooth=True)
        m.part("knee_" + side, "cyl", c["shin"], loc=(0, 0, -0.1), r1=shin_r[0], r2=shin_r[1], h=0.21, n=8, smooth=True)
        m.part("ankle_" + side, "box", c["foot"], loc=(0.03, 0, -0.035), sx=0.17, sy=0.085, sz=0.075, top=(0.8, 1.0))


def ghost(m):
    """Ghost: uzun ve sıska hayalet-suikastçı. Kemik maske, mor yanan gözler, yırtık uzun cübbe ve pelerin, sargılı
    soluk kollar, pençe eller, omuzlarda kemik diken."""
    hu.skeleton(m, {"hip_h": 0.55, "thigh": 0.245, "shin": 0.235, "shoulder_h": 0.3, "shoulder_w": 0.165,
                    "upper": 0.215, "fore": 0.2, "neck": 0.35, "hip_w": 0.075})
    robe = "#2a2533"
    robe_d = "#1b1822"
    skin = "#8f989d"
    wrap = "#6b6458"
    bone = "#cfc6b0"
    sash = "#5a1414"
    eye = "#c07bff"
    _limbs(m, {"upper": skin, "fore": wrap, "thigh": wrap, "shin": wrap, "foot": "#3a332b", "skin_shine": 0.3},
           arm_r=(0.035, 0.042), fore_r=(0.03, 0.038), thigh_r=(0.045, 0.055), shin_r=(0.038, 0.046))
    _flaps(m, robe, 0.44, fx=0.08, bx=-0.085, width=0.13, back_depth=0.47)
    for side, s in (("r", -1.0), ("l", 1.0)):
        # sargı bantları ve pençeler
        for z in (-0.05, -0.12):
            m.part("elbow_" + side, "cyl", "#8a8272", loc=(0, 0, z), r1=0.041, r2=0.041, h=0.025, n=7)
        hd = "hand_" + side
        m.part(hd, "box", skin, loc=(0.005, 0, -0.035), sx=0.06, sy=0.06, sz=0.065, shine=0.3)
        for i, y in enumerate((-0.022, 0.0, 0.022)):
            m.part(hd, "hull", "#2a2622", points=[(0.02, y - 0.008, -0.06), (0.02, y + 0.008, -0.06), (0.0, y, -0.06),
                                                   (0.05, y, -0.13)], shine=0.4)
        # omuzda kemik dikenler
        sh = "shoulder_" + side
        m.part(sh, "sphere", robe_d, loc=(0, s * 0.01, 0.0), scale=(1.0, 1.0, 0.8), r=0.062, u=8, v=6)
        for k, (dx, dz) in enumerate(((0.02, 0.0), (-0.03, 0.01))):
            m.part(sh, "hull", bone, points=[(dx - 0.02, s * 0.03, dz), (dx + 0.02, s * 0.03, dz), (dx, s * 0.05, dz - 0.02),
                                             (dx - 0.01, s * 0.1, dz + 0.1 - k * 0.02)], shine=0.3)
    # Kalça ve gövde: dar cübbe, kan kırmızısı kuşak, göğüste çapraz zincir
    m.part("hips", "cyl", robe, loc=(0, 0, -0.03), r1=0.13, r2=0.115, h=0.14, n=9)
    m.part("hips", "cyl", sash, loc=(0, 0, 0.035), r1=0.122, r2=0.118, h=0.045, n=9, grime=0.35)
    m.part("hips", "prism", sash, loc=(0.1, 0.035, 0), points=_flap(-0.02, 0.02, 0.2, teeth=1), t=0.012)
    m.part("torso", "box", robe, loc=(0, 0, 0.17), sx=0.17, sy=0.22, sz=0.32, top=(1.05, 1.15))
    m.part("torso", "box", robe_d, loc=(0.087, 0, 0.19), sx=0.01, sy=0.07, sz=0.3, top=(1.0, 1.6))
    for i in range(7):
        t = i / 6.0
        m.part("torso", "box", "#55575c", loc=(0.092, -0.1 + 0.2 * t, 0.07 + 0.22 * t), rot=(40, 0, 0),
               sx=0.012, sy=0.02, sz=0.03, shine=0.7)
    m.part("torso", "cyl", robe_d, loc=(0, 0, 0.32), r1=0.14, r2=0.07, h=0.07, n=9)
    _cape(m, "torso", robe_d, 0.33, 0.62, 0.13, -0.095)
    splat(m, "torso", (0.09, 0.05, 0.22), 0.022)
    splat(m, "hip_r", (0.093, 0.02, -0.18), 0.022, dark=True, stretch=1.7)
    # Baş: kemik maske (uzun çene), göz çukurları ve yanan gözler, arkaya sarkan siyah saç
    m.part("head", "sphere", "#2c2a2e", loc=(-0.01, 0, 0.1), scale=(1.0, 0.95, 1.1), r=0.095, u=9, v=7, smooth=True)
    m.part("head", "hull", bone, points=[(0.06, -0.07, 0.17), (0.06, 0.07, 0.17), (0.1, -0.06, 0.1), (0.1, 0.06, 0.1),
                                         (0.105, 0.0, 0.14), (0.09, -0.04, -0.02), (0.09, 0.04, -0.02), (0.075, 0.0, -0.07),
                                         (0.03, -0.08, 0.12), (0.03, 0.08, 0.12), (0.04, -0.06, 0.0), (0.04, 0.06, 0.0)],
           shine=0.3, grime=0.4)
    for s in (-1.0, 1.0):
        m.part("head", "box", EYE_DARK, loc=(0.1, s * 0.035, 0.105), sx=0.02, sy=0.04, sz=0.035)
        m.part("head", "box", eye, loc=(0.107, s * 0.035, 0.105), sx=0.01, sy=0.022, sz=0.016, emit=True)
    for i in range(4):
        m.part("head", "box", "#e5dcc6", loc=(0.093, -0.03 + 0.02 * i, 0.0), sx=0.012, sy=0.012, sz=0.03)
    for i, y in enumerate((-0.07, -0.035, 0.0, 0.035, 0.07)):
        m.part("head", "box", "#141214", loc=(-0.07, y, 0.02), rot=(0, -12, 0), sx=0.03, sy=0.03, sz=0.26 - abs(y))
    return {"hand": "hand_r", "hand_l": "hand_l", "grip": (0.005, 0, -0.035), "anims": hu.PLAYER_ANIMS}


def archer(m):
    """Archer: savaş boyalı, mohikan saçlı yırtıcı avcı. Kürk omuz yeleği, deri zırh, sırtta ok dolu sadak, yeşil yırtık
    pelerin, kemerde kemik ganimetler, ağzında kanlı bez."""
    hu.skeleton(m, {"hip_h": 0.52, "thigh": 0.23, "shin": 0.22, "shoulder_h": 0.3, "shoulder_w": 0.18,
                    "upper": 0.2, "fore": 0.18, "neck": 0.36})
    leather = "#6a4a30"
    leather_d = "#2e2118"
    green = "#3b5230"
    fur = "#8a7458"
    skin = "#a27b5c"
    bone = "#cfc6b0"
    _limbs(m, {"upper": leather, "fore": skin, "thigh": "#2f3d26", "shin": leather_d, "foot": "#3a2a1f", "skin_shine": 0.3})
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("elbow_" + side, "cyl", leather, loc=(0, 0, -0.1), r1=0.05, r2=0.055, h=0.12, n=8, shine=0.15)
        m.part("hand_" + side, "box", skin, loc=(0.005, 0, -0.035), sx=0.07, sy=0.065, sz=0.075, shine=0.25)
        m.part("knee_" + side, "cyl", "#6b5a44", loc=(0, 0, -0.06), r1=0.058, r2=0.058, h=0.03, n=8)
        m.part("knee_" + side, "cyl", "#6b5a44", loc=(0, 0, -0.14), r1=0.054, r2=0.054, h=0.03, n=8)
        m.part("shoulder_" + side, "sphere", fur, loc=(0, s * 0.01, 0.0), scale=(1.1, 1.1, 0.85), r=0.075, u=7, v=5, grime=0.6)
    _flaps(m, leather_d, 0.2, fx=0.09, bx=-0.09, width=0.12)
    # Kalça ve gövde: kemer ve kemik ganimetler, deri zırh, çapraz kayış, kürk yaka, sadak
    m.part("hips", "cyl", leather_d, loc=(0, 0, -0.02), r1=0.13, r2=0.12, h=0.13, n=9)
    m.part("hips", "cyl", "#5a3a22", loc=(0, 0, 0.035), r1=0.128, r2=0.125, h=0.045, n=9)
    for i, y in enumerate((-0.09, 0.05)):
        m.part("hips", "sphere", bone, loc=(0.1, y, -0.02), scale=(0.9, 0.9, 1.0), r=0.028, u=6, v=4, shine=0.3)
        m.part("hips", "box", EYE_DARK, loc=(0.125, y, -0.018), sx=0.01, sy=0.03, sz=0.01)
    m.part("torso", "box", leather, loc=(0, 0, 0.16), sx=0.19, sy=0.27, sz=0.32, top=(1.05, 1.12), shine=0.15)
    m.part("torso", "box", leather_d, loc=(0.097, 0, 0.13), sx=0.01, sy=0.18, sz=0.2)
    m.part("torso", "box", "#5a3a22", loc=(0.03, 0, 0.18), rot=(-38, 0, 0), sx=0.22, sy=0.04, sz=0.42)
    m.part("torso", "cyl", fur, loc=(0, 0, 0.32), r1=0.17, r2=0.11, h=0.09, n=10, grime=0.6)
    m.part("torso", "cyl", "#3a2a1a", loc=(-0.11, 0.05, 0.2), rot=(18, 0, 0), r1=0.05, r2=0.055, h=0.32, n=8)
    for i, (dy, dz) in enumerate(((0.0, 0.0), (0.022, 0.01), (-0.02, 0.015), (0.01, -0.02))):
        m.part("torso", "cyl", "#6b5033", loc=(-0.11, 0.1 + dy, 0.4 + dz), rot=(18, 0, 0), r1=0.006, r2=0.006, h=0.14, n=4)
        m.part("torso", "box", "#8a1a1a", loc=(-0.11, 0.12 + dy, 0.47 + dz), rot=(18, 0, 0), sx=0.008, sy=0.025, sz=0.04)
    _cape(m, "torso", green, 0.33, 0.45, 0.14, -0.1)
    splat(m, "torso", (0.1, -0.06, 0.24), 0.022)
    splat(m, "hip_l", (0.093, -0.02, -0.1), 0.02, dark=True)
    # Baş: kazıtılmış kafa, mohikan, gözlerde siyah savaş boyası, ağız bezi (kanlı), kemik küpe
    m.part("head", "sphere", skin, loc=(0.015, 0, 0.1), scale=(1.0, 0.9, 1.08), r=0.1, u=9, v=7, smooth=True, shine=0.25)
    m.part("head", "box", "#151312", loc=(0.09, 0, 0.115), sx=0.035, sy=0.15, sz=0.03)
    for s in (-1.0, 1.0):
        m.part("head", "box", "#d8c8a0", loc=(0.108, s * 0.035, 0.117), sx=0.01, sy=0.022, sz=0.012)
    m.part("head", "hull", "#6e1a0e", points=[(0.08, -0.012, 0.18), (0.08, 0.012, 0.18), (-0.1, -0.012, 0.16),
                                              (-0.1, 0.012, 0.16), (0.05, 0.0, 0.26), (-0.08, 0.0, 0.25), (-0.12, 0.0, 0.08)])
    m.part("head", "box", green, loc=(0.06, 0, 0.025), sx=0.09, sy=0.16, sz=0.05, top=(0.9, 0.9))
    splat(m, "head", (0.108, 0.02, 0.04), 0.016)
    m.part("head", "sphere", bone, loc=(0.0, -0.095, 0.06), r=0.014, u=5, v=3)
    return {"hand": "hand_r", "hand_l": "hand_l", "grip": (0.005, 0, -0.035), "anims": hu.PLAYER_ANIMS}


def magical(m):
    """Magical: kan büyücüsü. Koyu kızıl uzun cübbe, yüksek yaka, boynuzlu kemik taç, soluk ten; tende, kollarda ve
    cübbede eflatun yanan rünler (ırk rengi), kemerde kafatası tokası."""
    hu.skeleton(m, {"hip_h": 0.52, "thigh": 0.23, "shin": 0.22, "shoulder_h": 0.3, "shoulder_w": 0.17,
                    "upper": 0.2, "fore": 0.18, "neck": 0.36})
    robe = "#5a1520"
    robe_d = "#2e0a10"
    trim = "#6b5a3a"
    skin = "#b3a296"
    horn = "#2a2420"
    bone = "#cfc6b0"
    rune = "#ff3ac8"
    _limbs(m, {"upper": robe, "fore": robe, "thigh": robe_d, "shin": robe_d, "foot": "#1a1210", "skin_shine": 0.15},
           arm_r=(0.045, 0.05), fore_r=(0.06, 0.042))
    _flaps(m, robe, 0.46, fx=0.085, bx=-0.09, width=0.15, grime=0.4)
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("elbow_" + side, "cyl", trim, loc=(0, 0, -0.175), r1=0.065, r2=0.065, h=0.02, n=8, shine=0.5)
        m.part("hand_" + side, "box", skin, loc=(0.005, 0, -0.035), sx=0.062, sy=0.06, sz=0.075, shine=0.2)
        m.part("hand_" + side, "box", rune, loc=(0.036, 0, -0.03), sx=0.004, sy=0.03, sz=0.008, emit=True)
        m.part("shoulder_" + side, "sphere", robe_d, loc=(0, s * 0.01, 0.0), scale=(1.0, 1.0, 0.8), r=0.068, u=8, v=6)
        m.part("shoulder_" + side, "hull", bone, points=[(-0.03, s * 0.04, 0.02), (0.03, s * 0.04, 0.02), (0.0, s * 0.06, 0.0),
                                                        (0.0, s * 0.07, 0.11)], shine=0.3)
    # Kalça ve gövde: kuşak ve kafatası toka, cübbe, önde yanan rün şeritleri, yüksek yaka
    m.part("hips", "cyl", robe, loc=(0, 0, -0.03), r1=0.14, r2=0.12, h=0.14, n=9)
    m.part("hips", "cyl", "#2a1a14", loc=(0, 0, 0.035), r1=0.125, r2=0.12, h=0.045, n=9)
    m.part("hips", "sphere", bone, loc=(0.12, 0, 0.035), scale=(0.8, 1.0, 1.0), r=0.035, u=7, v=5, shine=0.3)
    for s in (-1.0, 1.0):
        m.part("hips", "box", EYE_DARK, loc=(0.145, s * 0.013, 0.04), sx=0.01, sy=0.012, sz=0.012)
    m.part("torso", "box", robe, loc=(0, 0, 0.16), sx=0.19, sy=0.26, sz=0.32, top=(1.05, 1.12), shine=0.1)
    m.part("torso", "box", trim, loc=(0.097, 0, 0.16), sx=0.01, sy=0.05, sz=0.32, shine=0.5)
    for i, z in enumerate((0.07, 0.15, 0.23)):
        m.part("torso", "box", rune, loc=(0.103, 0, z), sx=0.004, sy=0.03 + 0.01 * (i % 2), sz=0.012, emit=True)
    m.part("torso", "cyl", robe_d, loc=(-0.02, 0, 0.37), r1=0.1, r2=0.15, h=0.12, n=9)
    _cape(m, "torso", robe_d, 0.34, 0.72, 0.14, -0.1, grime=0.4)
    splat(m, "torso", (0.1, 0.07, 0.2), 0.02, dark=True)
    splat(m, "hand_r", (0.037, 0.0, -0.05), 0.018)
    # Baş: soluk kel kafa, eflatun gözler, yüzde rün, boynuzlu kemik taç
    m.part("head", "sphere", skin, loc=(0.015, 0, 0.1), scale=(1.0, 0.9, 1.1), r=0.095, u=9, v=7, smooth=True, shine=0.2)
    for s in (-1.0, 1.0):
        m.part("head", "box", EYE_DARK, loc=(0.098, s * 0.034, 0.108), sx=0.02, sy=0.034, sz=0.022)
        m.part("head", "box", rune, loc=(0.106, s * 0.034, 0.108), sx=0.01, sy=0.02, sz=0.012, emit=True)
    m.part("head", "box", rune, loc=(0.1, 0.0, 0.16), sx=0.004, sy=0.012, sz=0.05, emit=True)
    m.part("head", "cyl", bone, loc=(0.0, 0, 0.17), r1=0.1, r2=0.095, h=0.035, n=9, shine=0.3)
    for s in (-1.0, 1.0):
        m.part("head", "hull", horn, shine=0.3, points=[(0.02, s * 0.06, 0.17), (-0.03, s * 0.06, 0.17), (0.0, s * 0.09, 0.17),
                                                        (-0.03, s * 0.12, 0.28), (-0.1, s * 0.14, 0.35), (-0.08, s * 0.13, 0.34)])
        m.part("head", "hull", bone, points=[(0.04, s * 0.03, 0.18), (0.06, s * 0.03, 0.18), (0.05, s * 0.04, 0.18),
                                             (0.055, s * 0.035, 0.25)], shine=0.3)
    return {"hand": "hand_r", "hand_l": "hand_l", "grip": (0.005, 0, -0.035), "anims": hu.PLAYER_ANIMS}


CHARACTERS = {
    "warrior": warrior,
    "ghost": ghost,
    "archer": archer,
    "magical": magical,
}
