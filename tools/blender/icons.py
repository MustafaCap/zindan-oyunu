"""Arayüz ikonları (Aşama 8): 12 silah tipinin ikonu (oyundaki silah modeli, çapraz duruşta), 3 tılsım ve nadirlik
çerçevesi. Önden ortografik kamerayla render edilir; oyunda envanter, tüccar, demirci ve HUD'da kullanılır.
Çerçeve açık gri demirdir: oyun onu eşyanın nadirlik rengiyle boyar.
"""

import math

import bpy
from mathutils import Euler, Matrix, Vector

import sprite_lib as sl
import weapons

# Silahın geniş yüzü kameraya dönsün diye yuvarlanma (X ekseni). Yay, kitap, rün, asa zaten yandan görünür.
ICON_ROLL = {"bow": 0.0, "tome": 0.0, "rune": 0.0, "staff": 0.0}


def blood_stone(m):
    """Kan Taşı: demir pençe yuvada kan kırmızısı yontulmuş taş, zincir halkası."""
    g = m.joint("grip", "root", (0, 0, 0))
    m.part(g, "ico", "#b01020", r=0.16, sub=1, shine=0.9, grime=0.15)
    m.part(g, "ico", "#ff4050", loc=(-0.02, -0.03, 0.03), r=0.06, sub=1, emit=True)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        m.part(g, "hull", "#3e4046", shine=0.6, points=[(math.cos(a) * 0.14, -0.02, math.sin(a) * 0.14),
                                                        (math.cos(a) * 0.14, 0.05, math.sin(a) * 0.14),
                                                        (math.cos(a) * 0.2, 0.0, math.sin(a) * 0.2),
                                                        (math.cos(a) * 0.09, -0.07, math.sin(a) * 0.09)])
    m.part(g, "cyl", "#55575c", loc=(0, 0, 0.23), rot=(90, 0, 0), r1=0.045, r2=0.045, h=0.02, n=8, shine=0.6)


def wind_feather(m):
    """Rüzgâr Tüyü: gri-turkuaz uzun tüy, kemik boncuk ve deri bağ."""
    g = m.joint("grip", "root", (0, 0, 0))
    m.part(g, "cyl", "#d8d0b8", loc=(0, 0, 0), rot=(0, 90, 0), r1=0.008, r2=0.004, h=0.6, n=5)
    pts = []
    for k in range(9):
        t = k / 8.0
        w = 0.08 * math.sin(math.pi * min(1.0, t * 1.1)) + 0.01
        x = -0.2 + 0.48 * t
        pts += [(x, 0.0, w), (x, 0.0, -w * 0.8)]
    m.part(g, "hull", "#8ce6d9", points=[(x, -0.004, z) for x, _, z in pts] + [(x, 0.004, z) for x, _, z in pts], grime=0.35)
    for k in range(4):
        m.part(g, "box", "#4a8a84", loc=(-0.05 + 0.08 * k, 0.006, 0.02), rot=(0, 30, 0), sx=0.005, sy=0.003, sz=0.08)
    m.part(g, "sphere", "#cfc6b0", loc=(-0.25, 0, 0), r=0.03, u=6, v=4, shine=0.3)
    m.part(g, "cyl", "#5a3a22", loc=(-0.29, 0, 0), rot=(0, 90, 0), r1=0.012, r2=0.012, h=0.06, n=5)


def element_heart(m):
    """Element Kalbi: kehribar renkli, içinden parlayan kalp biçimli kristal, kararmış demir kafes."""
    g = m.joint("grip", "root", (0, 0, 0))
    for s in (-1.0, 1.0):
        m.part(g, "sphere", "#f2b233", loc=(s * 0.07, 0, 0.05), r=0.1, u=8, v=6, shine=0.8, grime=0.15)
    m.part(g, "hull", "#f2b233", shine=0.8, grime=0.15, points=[(-0.16, -0.05, 0.03), (0.16, -0.05, 0.03), (-0.16, 0.05, 0.03),
                                                              (0.16, 0.05, 0.03), (0.0, 0.0, -0.2)])
    m.part(g, "ico", "#fff0a0", loc=(0, -0.05, 0.0), r=0.06, sub=1, emit=True)
    for k in range(3):
        a = (k - 1) * 0.7
        m.part(g, "box", "#34363a", loc=(math.sin(a) * 0.12, -0.08, 0.0), rot=(0, math.degrees(a), 0), sx=0.02, sy=0.01, sz=0.34,
               shine=0.5)


TALISMANS = {"blood_stone": blood_stone, "wind_feather": wind_feather, "element_heart": element_heart}


def frame(m):
    """Nadirlik çerçevesi: köşeleri perçinli, dövme demir kare çerçeve (açık gri; oyunda nadirlik rengine boyanır)."""
    g = m.joint("grip", "root", (0, 0, 0))
    c = "#c8c8c8"
    for s in (-1.0, 1.0):
        m.part(g, "box", c, loc=(0, 0, s * 0.46), sx=0.96, sy=0.05, sz=0.06, shine=0.5, grime=0.5)
        m.part(g, "box", c, loc=(s * 0.46, 0, 0), sx=0.06, sy=0.05, sz=0.96, shine=0.5, grime=0.5)
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            m.part(g, "hull", "#e0e0e0", shine=0.6, points=[(sx * 0.5, -0.03, sz * 0.5), (sx * 0.34, -0.03, sz * 0.5),
                                                            (sx * 0.5, -0.03, sz * 0.34), (sx * 0.5, 0.03, sz * 0.5),
                                                            (sx * 0.34, 0.03, sz * 0.5), (sx * 0.5, 0.03, sz * 0.34),
                                                            (sx * 0.44, -0.06, sz * 0.44)])
            m.part(g, "sphere", "#ffffff", loc=(sx * 0.44, -0.07, sz * 0.44), r=0.025, u=6, v=4, shine=0.8)


def render_icon(build, out_path, tmp, roll=90.0, pitch=45.0, size=192, margin=0.86, outline=3, fixed_extent=None):
    """Tek ikon: model çapraz (pitch) ve yüzü kameraya (roll) döndürülüp kareye sığdırılır."""
    sl.reset_scene()
    m = sl.Model("icon")
    build(m)
    bpy.context.view_layer.update()
    rot = Matrix.Rotation(math.radians(-pitch), 3, "Y") @ Matrix.Rotation(math.radians(roll), 3, "X")
    xs, zs = [], []
    for ob in m.coll.objects:
        if ob.type != "MESH":
            continue
        for v in ob.data.vertices:
            p = rot @ ((ob.matrix_world @ v.co) - sl.FAR)
            xs.append(p.x)
            zs.append(p.z)
    cx, cz = (min(xs) + max(xs)) * 0.5, (min(zs) + max(zs)) * 0.5
    extent = fixed_extent or max(max(xs) - min(xs), max(zs) - min(zs)) / margin
    sc = bpy.context.scene
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    cam_data = bpy.data.cameras.new("IconCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = extent
    cam = bpy.data.objects.new("IconCam", cam_data)
    sc.collection.objects.link(cam)
    cam.rotation_euler = Euler((math.radians(90.0), 0.0, 0.0), "XYZ")
    cam.location = Vector((0.0, -40.0, 0.0))
    sc.camera = cam
    inst = bpy.data.objects.new("icon_inst", None)
    inst.instance_type = "COLLECTION"
    inst.instance_collection = m.coll
    inst.rotation_mode = "XYZ"
    inst.rotation_euler = rot.to_euler("XYZ")
    inst.location = Vector((-cx, 0.0, -cz))
    sc.collection.objects.link(inst)
    p = sl.render_passes(tmp, "icon")
    rgb, a = sl.toon(p, outline)
    sl.write_png(out_path, __import__("numpy").concatenate([rgb, a[..., None]], axis=-1))


def render_all(out_dir, tmp, only=None):
    import os
    for wid, fn in weapons.WEAPONS.items():
        if only is None or ("icon_" + wid) in only or "icons" in only:
            render_icon(fn, os.path.join(out_dir, "weapon_%s.png" % wid), tmp, roll=ICON_ROLL.get(wid, 90.0))
    for tid, fn in TALISMANS.items():
        if only is None or "icons" in only:
            render_icon(fn, os.path.join(out_dir, "talisman_%s.png" % tid), tmp, roll=0.0, pitch=0.0 if tid != "wind_feather" else 45.0)
    if only is None or "icons" in only:
        render_icon(frame, os.path.join(out_dir, "frame.png"), tmp, roll=0.0, pitch=0.0, margin=1.0, outline=2, fixed_extent=1.04)
    print("[sprites] ikonlar tamam")
