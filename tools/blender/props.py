"""Oda nesneleri (Aşama 8): sandık (kapalı/açık), tüccar, demirci, aşağı inen merdiven. Tek yönden (izometrik)
render edilir; oyunda RoomProp çizer. Tüccarın feneri ve demircinin ocağı ayrıca oyunda nokta ışık yayar.
Görsel yön: karanlık, kanlı zindan.
"""

import math

import humanoid as hu
from characters import BLOOD, BLOOD_D, EYE_DARK, splat

WOOD = "#4a3020"
WOOD_D = "#2e1e14"
IRON = "#3e4046"


def _chest_body(m, j):
    m.part(j, "box", WOOD, loc=(0, 0, 0.14), sx=0.5, sy=0.34, sz=0.28, grime=0.55)
    for x in (-0.2, 0.2):
        m.part(j, "box", IRON, loc=(x, 0, 0.14), sx=0.04, sy=0.36, sz=0.3, shine=0.6)
    m.part(j, "box", IRON, loc=(0, -0.175, 0.2), sx=0.08, sy=0.02, sz=0.1, shine=0.6)
    m.part(j, "box", "#8a6a2e", loc=(0, -0.19, 0.2), sx=0.04, sy=0.01, sz=0.05, shine=0.8)
    splat(m, j, (0.1, -0.172, 0.08), 0.04, normal="-y")


def chest_closed(m):
    """Kapalı sandık: demir kuşaklı kararmış ahşap, kilit, kan lekesi."""
    j = m.joint("p", "root", (0, 0, 0))
    _chest_body(m, j)
    m.part(j, "cyl", WOOD, loc=(0, 0, 0.28), rot=(0, 90, 0), scale=(1.0, 1.0, 1.0), r1=0.17, r2=0.17, h=0.5, n=10, grime=0.55)
    for x in (-0.2, 0.2):
        m.part(j, "cyl", IRON, loc=(x, 0, 0.28), rot=(0, 90, 0), r1=0.18, r2=0.18, h=0.04, n=10, shine=0.6)
    m.part(j, "box", WOOD_D, loc=(0, 0, 0.2), sx=0.52, sy=0.36, sz=0.02)
    return {"cell": (80, 72), "anchor": (40, 52), "dir": 1}


def chest_open(m):
    """Açık sandık: kapak geriye açık, içi karanlık."""
    j = m.joint("p", "root", (0, 0, 0))
    _chest_body(m, j)
    m.part(j, "box", "#0e0806", loc=(0, 0, 0.27), sx=0.44, sy=0.28, sz=0.02)
    lid = m.joint("lid", "p", (0, 0.17, 0.28))
    m.part(lid, "cyl", WOOD, loc=(0, 0.0, 0.17), rot=(0, 90, 0), r1=0.17, r2=0.17, h=0.5, n=10, grime=0.55)
    m.joints["lid"].rotation_euler = (math.radians(-100), 0, 0)
    return {"cell": (80, 84), "anchor": (40, 62), "dir": 1}


def merchant(m):
    """Tüccar: kambur, kapüşonlu, yüzü gölgede; sırtında şişkin yük çuvalı, elinde fener (sarı ışık)."""
    hu.skeleton(m, {"hip_h": 0.46, "thigh": 0.2, "shin": 0.21, "shoulder_w": 0.17, "neck": 0.32})
    robe = "#3a3024"
    for side in ("r", "l"):
        m.part("shoulder_" + side, "cyl", robe, loc=(0, 0, -0.1), r1=0.045, r2=0.05, h=0.2, n=7)
        m.part("elbow_" + side, "cyl", robe, loc=(0, 0, -0.09), r1=0.05, r2=0.045, h=0.18, n=7)
        m.part("hand_" + side, "box", "#8a7060", loc=(0.005, 0, -0.035), sx=0.05, sy=0.05, sz=0.06)
        m.part("hip_" + side, "cyl", robe, loc=(0, 0, -0.1), r1=0.05, r2=0.06, h=0.2, n=7)
        m.part("knee_" + side, "cyl", robe, loc=(0, 0, -0.1), r1=0.05, r2=0.055, h=0.21, n=7)
        m.part("ankle_" + side, "box", "#2a2018", loc=(0.03, 0, -0.03), sx=0.13, sy=0.07, sz=0.05)
    m.part("hips", "cyl", robe, loc=(0, 0, -0.12), r1=0.16, r2=0.12, h=0.32, n=9, grime=0.55)
    m.part("torso", "box", robe, loc=(0, 0, 0.15), sx=0.18, sy=0.25, sz=0.3, top=(1.0, 1.1), grime=0.55)
    m.part("torso", "ico", "#6a5638", loc=(-0.18, 0, 0.24), scale=(1.0, 1.1, 1.2), r=0.17, sub=2, smooth=True, grime=0.6)
    m.part("torso", "box", "#4a3020", loc=(-0.1, 0, 0.2), rot=(40, 0, 0), sx=0.04, sy=0.03, sz=0.4)
    m.part("head", "hull", robe, points=[(0.0, 0, 0.22), (-0.1, 0, 0.16), (-0.1, 0, 0.0), (0.05, 0.09, 0.12),
                                         (0.05, -0.09, 0.12), (-0.06, 0.1, 0.02), (-0.06, -0.1, 0.02), (0.02, 0.1, -0.02),
                                         (0.02, -0.1, -0.02), (0.08, 0, 0.18)], grime=0.5)
    m.part("head", "sphere", "#1a1412", loc=(0.05, 0, 0.08), scale=(0.5, 1.0, 1.1), r=0.06, u=7, v=5)
    for s in (-1.0, 1.0):
        m.part("head", "box", "#f0d060", loc=(0.078, s * 0.022, 0.09), sx=0.006, sy=0.012, sz=0.006, emit=True)
    m.joint("lantern", "hand_l", (0.04, 0, -0.1))
    m.part("lantern", "cyl", IRON, loc=(0, 0, 0.0), r1=0.04, r2=0.03, h=0.1, n=6, shine=0.6)
    m.part("lantern", "cyl", "#ffd070", loc=(0, 0, 0.0), r1=0.03, r2=0.025, h=0.07, n=6, emit=True)
    pose = hu.pose_ready()
    pose.update({"torso": (0, 22, 0), "head": (0, -14, 0), "shoulder_l": (15, -45, 10), "elbow_l": (0, -30, 0),
                 "hand_l": (0, 70, 0)})
    return {"cell": (96, 110), "anchor": (48, 90), "pose": pose, "dir": 3}


def blacksmith(m):
    """Demirci: iri, çıplak kollu, deri önlüklü demirci; önünde örs, yanında korları parlayan ocak (turuncu ışık)."""
    j = m.joint("p", "root", (0, 0, 0))
    # örs
    m.part(j, "box", "#2a2226", loc=(0.3, 0, 0.12), sx=0.16, sy=0.16, sz=0.24)
    m.part(j, "hull", IRON, shine=0.6, points=[(0.14, -0.08, 0.24), (0.46, -0.08, 0.24), (0.14, 0.08, 0.24), (0.46, 0.08, 0.24),
                                               (0.14, -0.08, 0.32), (0.46, -0.08, 0.32), (0.14, 0.08, 0.32), (0.46, 0.08, 0.32),
                                               (0.6, 0.0, 0.3)])
    # ocak
    m.part(j, "cyl", "#3a3230", loc=(-0.25, 0.3, 0.15), r1=0.22, r2=0.2, h=0.3, n=9, grime=0.6)
    m.part(j, "cyl", "#ff6a1a", loc=(-0.25, 0.3, 0.3), r1=0.17, r2=0.17, h=0.02, n=9, emit=True)
    for k in range(5):
        a = k * 1.25
        m.part(j, "ico", "#2a1a14", loc=(-0.25 + 0.1 * math.cos(a), 0.3 + 0.1 * math.sin(a), 0.32), r=0.04, sub=1)
    # demirci (insansı, çekiç)
    hu.skeleton(m, {"hip_h": 0.5, "shoulder_w": 0.22, "neck": 0.36})
    skin = "#8a6a54"
    for side, s in (("r", -1.0), ("l", 1.0)):
        m.part("shoulder_" + side, "sphere", skin, loc=(0, s * 0.02, 0), r=0.075, u=8, v=6, smooth=True, shine=0.35)
        m.part("shoulder_" + side, "cyl", skin, loc=(0, 0, -0.1), r1=0.05, r2=0.062, h=0.2, n=8, smooth=True, shine=0.35)
        m.part("elbow_" + side, "cyl", skin, loc=(0, 0, -0.09), r1=0.046, r2=0.056, h=0.18, n=8, smooth=True, shine=0.35)
        m.part("hand_" + side, "box", "#4a3020", loc=(0.005, 0, -0.035), sx=0.075, sy=0.07, sz=0.08)
        m.part("hip_" + side, "cyl", "#2a2220", loc=(0, 0, -0.11), r1=0.06, r2=0.07, h=0.23, n=8)
        m.part("knee_" + side, "cyl", "#3a2a1f", loc=(0, 0, -0.1), r1=0.055, r2=0.062, h=0.21, n=8)
        m.part("ankle_" + side, "box", "#3a2a1f", loc=(0.03, 0, -0.035), sx=0.17, sy=0.09, sz=0.075)
    m.part("hips", "box", "#2a2220", loc=(0, 0, 0), sx=0.19, sy=0.24, sz=0.12)
    m.part("torso", "box", skin, loc=(0, 0, 0.18), sx=0.22, sy=0.3, sz=0.3, top=(1.06, 1.14), shine=0.35)
    m.part("torso", "box", "#5a3a22", loc=(0.1, 0, 0.1), sx=0.03, sy=0.24, sz=0.45, top=(1.0, 0.8), grime=0.55)
    splat(m, "torso", (0.118, 0.04, 0.05), 0.03, dark=True)
    m.part("head", "sphere", skin, loc=(0.02, 0, 0.1), r=0.095, u=8, v=6, smooth=True)
    m.part("head", "box", "#2a1a14", loc=(0.07, 0, 0.03), sx=0.08, sy=0.15, sz=0.1, top=(0.8, 0.9))
    for s in (-1.0, 1.0):
        m.part("head", "box", EYE_DARK, loc=(0.108, s * 0.035, 0.11), sx=0.012, sy=0.02, sz=0.012)
    m.part("hand_r", "cyl", "#2a1d14", loc=(0.12, 0, -0.035), rot=(0, 90, 0), r1=0.015, r2=0.015, h=0.25, n=6)
    m.part("hand_r", "box", IRON, loc=(0.25, 0, -0.035), sx=0.06, sy=0.07, sz=0.13, shine=0.6)
    pose = hu.pose_ready()
    pose.update({"shoulder_r": (-10, -70, 30), "elbow_r": (0, -60, 0), "hand_r": (0, 60, 0), "torso": (0, 12, 10)})
    return {"cell": (140, 120), "anchor": (70, 92), "pose": pose, "dir": 1}


def stairs(m):
    """Aşağı inen merdiven: yerde kırık taş çerçeveli kuyu, karanlığa inen basamaklar."""
    j = m.joint("p", "root", (0, 0, 0))
    for k in range(8):
        a = k * math.pi / 4
        m.part(j, "ico", "#3a3440", loc=(0.7 * math.cos(a), 0.7 * math.sin(a), 0.04), scale=(1.4, 1.0, 0.5), r=0.14, sub=1, grime=0.6)
    m.part(j, "cyl", "#050408", loc=(0, 0, 0.005), r1=0.62, r2=0.62, h=0.01, n=16)
    for k in range(5):
        shade = ["#4a4452", "#3a3442", "#2a2632", "#1c1a22", "#121016"][k]
        x = 0.42 - 0.13 * k
        m.part(j, "box", shade, loc=(x, 0, 0.012), sx=0.12, sy=1.8 * math.sqrt(max(0.62 ** 2 - (abs(x) + 0.06) ** 2, 0.01)), sz=0.01)
    return {"cell": (110, 80), "anchor": (55, 40)}


PROPS = {"chest_closed": chest_closed, "chest_open": chest_open, "merchant": merchant, "blacksmith": blacksmith,
         "stairs": stairs}
