"""Sprite üretim kütüphanesi (Aşama 8) — Blender içinde çalışır (bpy + numpy; Pillow gerekmez).

Akış: sahne → düşük poligonlu parçalar (eklemlere bağlı) → poz → ortografik izometrik kamerayla render →
numpy ile toon gölgeleme + dış çizgi → sprite sheet (PNG) + meta (JSON).

Koordinatlar: 1 Blender birimi = 1 karo (oyunda 45,25 dünya pikseli). Oyunun "cart" uzayı: x sağa, y ekranda aşağı.
Blender'da X = cart x, Y = −cart y, Z yukarı. Kamera 30° yükseklikten bakar: zemindeki y ekranda ×0,5, yükseklik ×0,866.
Karakterler yerel +X'e bakar; sol eli +Y tarafındadır.
"""

import json
import math
import os
import struct
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

KARO_PX = 45.254834          # 1 karo, oyunun dünya pikseli cinsinden (Iso.KARO)
MODEL_SCALE = 1.15           # modeller ekranda bu kadar büyük çizilir (okunabilirlik; çarpışma gövdesi değişmez)
ELEV = math.radians(30.0)    # 2:1 izometri → kamera yükseklik açısı 30°
FAR = Vector((0.0, 0.0, -60.0))  # kaynak model kameranın görmediği yerde durur; örnekler (instance) render edilir
CAM_FWD = Vector((0.0, math.cos(ELEV), -math.sin(ELEV)))
CAM_UP = Vector((0.0, math.sin(ELEV), math.cos(ELEV)))
CAM_RIGHT = Vector((1.0, 0.0, 0.0))

# Toon ışığı (kamera uzayı: x sağ, y yukarı, z kameraya doğru): sol üst önden gelir.
TOON_LIGHT = np.array([-0.45, 0.62, 0.64], dtype=np.float32)
TOON_BANDS = ((0.50, 1.00), (0.05, 0.74), (-2.0, 0.52))   # (N·L eşiği, parlaklık)
OUTLINE_RGB = np.array([0.07, 0.05, 0.09], dtype=np.float32)


# ----------------------------------------------------------------------------------------------------------------
# Renk yardımcıları

def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float32)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# ----------------------------------------------------------------------------------------------------------------
# Sahne

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.film_transparent = True
    sc.render.resolution_percentage = 100
    sc.render.filter_size = 1.2
    sc.eevee.taa_render_samples = 8
    sc.render.image_settings.file_format = "OPEN_EXR"
    world = bpy.data.worlds.new("Siyah")
    world.color = (0.0, 0.0, 0.0)
    sc.world = world
    _normal_material()
    return sc


def _normal_material():
    """Kamera uzayı normalini renk olarak yayan malzeme (normal geçişi için material_override)."""
    m = bpy.data.materials.new("__normal")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    vt = nt.nodes.new("ShaderNodeVectorTransform")
    vt.vector_type = "NORMAL"
    vt.convert_from = "WORLD"
    vt.convert_to = "CAMERA"
    ma = nt.nodes.new("ShaderNodeVectorMath")
    ma.operation = "MULTIPLY_ADD"
    ma.inputs[1].default_value = (0.5, 0.5, 0.5)
    ma.inputs[2].default_value = (0.5, 0.5, 0.5)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[1].default_value = 1.0
    nt.links.new(geo.outputs["Normal"], vt.inputs[0])
    nt.links.new(vt.outputs[0], ma.inputs[0])
    nt.links.new(ma.outputs[0], em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


_MATS = {}


def mat(hex_color, glow=False, shine=0.0, emit=False, grime=0.3, grain=22.0):
    """Emisyon malzemesi. Albedo geçişinde rengi nesne uzayındaki gürültüyle kirletilmiş olarak yayar (kareler arasında
    kaymayan yüzey dokusu: deri, pas, kir). Özellik geçişinde (R, G, B) = (ışıma, parlaklık, element parıltısı) yayar.
    glow: silahın element rengine boyanan kısmı · shine: metal/ıslak kan parlaması (0..1) · emit: karanlıkta parlar (gözler)."""
    key = (hex_color, glow, shine, emit, grime, grain)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new("m_%s" % hex_color.lstrip("#"))
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[1].default_value = 1.0
    rgb = nt.nodes.new("ShaderNodeRGB")
    rgb.name = "base"
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = grain
    noise.inputs["Detail"].default_value = 4.0
    fac = nt.nodes.new("ShaderNodeMath")
    fac.name = "grime"
    fac.operation = "MULTIPLY_ADD"
    vm = nt.nodes.new("ShaderNodeVectorMath")
    vm.operation = "SCALE"
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], fac.inputs[0])
    nt.links.new(rgb.outputs[0], vm.inputs[0])
    nt.links.new(fac.outputs[0], vm.inputs["Scale"])
    nt.links.new(vm.outputs["Vector"], em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs[0])
    lin = srgb_to_linear(hex_rgb(hex_color))
    m["albedo"] = [float(v) for v in lin]
    m["props"] = [1.0 if emit else 0.0, float(shine), 1.0 if glow else 0.0]
    m["grime"] = 0.0 if emit else float(grime)
    _MATS[key] = m
    _apply(m, "albedo")
    return m


def _apply(m, name):
    nt = m.node_tree
    base = nt.nodes["base"]
    fac = nt.nodes["grime"]
    if name == "props":
        base.outputs[0].default_value = (*m["props"], 1.0)
        fac.inputs[1].default_value = 0.0
        fac.inputs[2].default_value = 1.0
    else:
        g = float(m["grime"])
        base.outputs[0].default_value = (*m["albedo"], 1.0)
        # gürültü ~0,5 ± 0,2 → renk × (1 − g … 1 + g) aralığında
        fac.inputs[1].default_value = 2.0 * g
        fac.inputs[2].default_value = 1.0 - g


def set_pass(name):
    """albedo | normal | props"""
    vl = bpy.context.view_layer
    vl.material_override = bpy.data.materials["__normal"] if name == "normal" else None
    for m in bpy.data.materials:
        if "albedo" in m:
            _apply(m, name)


# ----------------------------------------------------------------------------------------------------------------
# Düşük poligonlu parçalar (bmesh)

def _bm_box(sx, sy, sz, top=(1.0, 1.0), shift=(0.0, 0.0)):
    """Merkezli kutu; top: üst yüzün x/y ölçeği (sivrilme), shift: üst yüzün kayması."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x = v.co.x * top[0] + shift[0] / sx
            v.co.y = v.co.y * top[1] + shift[1] / sy
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    return bm


def _bm_cyl(r1, r2, h, n=8):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=n, radius1=r1, radius2=r2, depth=h)
    return bm


def _bm_sphere(r, u=8, v=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    return bm


def _bm_ico(r, sub=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    return bm


def _bm_hull(points):
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in points]
    res = bmesh.ops.convex_hull(bm, input=verts)
    extra = list({g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
    if extra:
        bmesh.ops.delete(bm, geom=extra, context="VERTS")
    return bm


def _bm_prism(points, t):
    """Y-Z düzleminde verilen (içbükey olabilen) çokgenin X yönünde t kalınlığında levhası (yırtık etek, pelerin)."""
    bm = bmesh.new()
    front = [bm.verts.new((t * 0.5, y, z)) for y, z in points]
    back = [bm.verts.new((-t * 0.5, y, z)) for y, z in points]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[i], back[i], back[j], front[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


SHAPES = {"box": _bm_box, "cyl": _bm_cyl, "sphere": _bm_sphere, "ico": _bm_ico, "hull": _bm_hull, "prism": _bm_prism}


class Model:
    """Eklemler (boş nesneler) + onlara bağlı katı parçalar. Kök FAR'da durur; örnekler render edilir."""

    def __init__(self, name):
        self.name = name
        self.coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(self.coll)
        self.coll.instance_offset = FAR
        self.joints = {}
        self.rest = {}
        self.rest_scale = {}
        self.root = self.joint("root", None, FAR)

    def joint(self, name, parent, loc, scale=1.0):
        """scale: dinlenme ölçeği (ör. yalnızca bir yetenekte görünen kalkan için ~0)."""
        ob = bpy.data.objects.new(name, None)
        self.coll.objects.link(ob)
        if parent is not None:
            ob.parent = self.joints[parent] if isinstance(parent, str) else parent
        ob.location = Vector(loc)
        ob.rotation_mode = "XYZ"
        ob.scale = (scale, scale, scale)
        self.joints[name] = ob
        self.rest[name] = Vector(loc)
        self.rest_scale[name] = scale
        return name

    def part(self, joint, shape, color, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), glow=False, shine=0.0,
             emit=False, grime=0.3, smooth=False, **kw):
        """Bir eklemin altına katı parça ekler. rot derece; smooth: organik parçalar (kas, deri) yumuşak gölgelenir."""
        bm = SHAPES[shape](**kw)
        me = bpy.data.meshes.new("%s_%s" % (joint, shape))
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = smooth
        me.materials.append(mat(color, glow, shine, emit, grime))
        ob = bpy.data.objects.new(me.name, me)
        self.coll.objects.link(ob)
        ob.parent = self.joints[joint]
        ob.location = Vector(loc)
        ob.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
        ob.scale = Vector(scale)
        return ob

    def pose(self, p):
        """p: {eklem: (rx, ry, rz) derece} ya da {eklem: {"rot", "loc": (dx, dy, dz), "scale", "world_rot"}}.
        world_rot: eklemin kök eksenlerine göre yönü (ebeveyn ne olursa olsun; ör. kalkan hep öne baksın).
        Verilmeyen eklem dinlenir."""
        world = []
        for name, ob in self.joints.items():
            if name == "root":
                continue
            v = p.get(name)
            rot = (0.0, 0.0, 0.0)
            off = (0.0, 0.0, 0.0)
            sc = self.rest_scale[name]
            if isinstance(v, dict):
                rot = v.get("rot", rot)
                off = v.get("loc", off)
                if v.get("scale") is not None:
                    sc = v["scale"]
                if v.get("world_rot") is not None:
                    world.append((ob, v["world_rot"]))
            elif v is not None:
                rot = v
            ob.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
            ob.location = self.rest[name] + Vector(off)
            ob.scale = tuple(sc) if isinstance(sc, (tuple, list)) else (sc, sc, sc)
        bpy.context.view_layer.update()
        if world:
            for ob, wr in world:
                parent_rot = ob.parent.matrix_world.to_3x3().normalized()
                desired = Euler([math.radians(a) for a in wr], "XYZ").to_matrix()
                ob.rotation_euler = (parent_rot.inverted() @ desired).to_euler("XYZ")
            bpy.context.view_layer.update()

    def local_point(self, joint, offset=(0, 0, 0)):
        """Eklemin (kök koordinatlarında) konumu ve yerel +X ekseni."""
        mw = self.joints[joint].matrix_world
        p = mw @ Vector(offset) - FAR
        fwd = (mw.to_3x3() @ Vector((1.0, 0.0, 0.0))).normalized()
        return p, fwd


# ----------------------------------------------------------------------------------------------------------------
# Kamera ve render

class Grid:
    """Tek render'da cols × rows hücre. Her hücrede kök (örnek) (ax, ay) render pikseline oturur."""

    def __init__(self, cols, rows, cell_w, cell_h, ax, ay, scale, model_scale=True):
        self.cols, self.rows = cols, rows
        self.cw, self.ch = cell_w, cell_h
        self.ax, self.ay = ax, ay
        self.pxu = KARO_PX * scale * (MODEL_SCALE if model_scale else 1.0)
        self.w, self.h = cols * cell_w, rows * cell_h
        self.instances = []

    def anchor_world(self, col, row):
        """Hücrenin çapa pikselini zemin (z=0) noktasına çevirir."""
        px = col * self.cw + self.ax
        py = row * self.ch + self.ay
        x = (px - self.w * 0.5) / self.pxu
        # Ekranda aşağı inmek, zeminde kameraya (−Y) yaklaşmaktır: 1 piksel aşağı = 1/(pxu·sin30) birim −Y.
        dy_px = py - self.h * 0.5
        y = -dy_px / (self.pxu * math.sin(ELEV))
        return Vector((x, y, 0.0))

    def setup_camera(self):
        sc = bpy.context.scene
        sc.render.resolution_x = self.w
        sc.render.resolution_y = self.h
        cam_data = bpy.data.cameras.new("IsoCam")
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = max(self.w, self.h) / self.pxu
        cam_data.clip_start = 0.1
        cam_data.clip_end = 200.0
        cam = bpy.data.objects.new("IsoCam", cam_data)
        sc.collection.objects.link(cam)
        cam.rotation_euler = Euler((math.radians(90.0) - ELEV, 0.0, 0.0), "XYZ")
        cam.location = -CAM_FWD * 40.0
        sc.camera = cam
        return cam

    def project(self, p_world):
        """Dünya noktası → render pikseli (x, y aşağı)."""
        x = self.w * 0.5 + p_world.dot(CAM_RIGHT) * self.pxu
        y = self.h * 0.5 - p_world.dot(CAM_UP) * self.pxu
        return x, y

    def add_instance(self, coll, col, row, yaw_deg, pitch_deg=0.0):
        ob = bpy.data.objects.new("inst_%s_%d_%d" % (coll.name, col, row), None)
        ob.instance_type = "COLLECTION"
        ob.instance_collection = coll
        ob.location = self.anchor_world(col, row)
        ob.rotation_mode = "XYZ"
        # Önce eğim (yerel Y ekseni etrafında, burun yukarı pozitif), sonra dönüş (Z).
        ob.rotation_euler = (Matrix.Rotation(math.radians(yaw_deg), 3, "Z") @
                             Matrix.Rotation(math.radians(-pitch_deg), 3, "Y")).to_euler("XYZ")
        bpy.context.scene.collection.objects.link(ob)
        self.instances.append(ob)
        return ob

    def clear_instances(self):
        for ob in self.instances:
            bpy.data.objects.remove(ob, do_unlink=True)
        self.instances = []


def render_exr(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    try:
        os.remove(path)
    except OSError:
        pass
    return arr.reshape(h, w, 4)[::-1].copy()   # üstten aşağı


def unpremultiply(arr):
    a = arr[..., 3:4]
    rgb = np.where(a > 1e-4, arr[..., :3] / np.maximum(a, 1e-4), 0.0)
    return rgb, arr[..., 3]


def render_passes(tmp_dir, tag):
    """albedo (doğrusal), normal (−1..1), ışıma / parlaklık / element parıltısı maskeleri; alfa albedo'dan."""
    os.makedirs(tmp_dir, exist_ok=True)
    set_pass("albedo")
    alb, alpha = unpremultiply(render_exr(os.path.join(tmp_dir, tag + "_a.exr")))
    set_pass("normal")
    nrm, _ = unpremultiply(render_exr(os.path.join(tmp_dir, tag + "_n.exr")))
    nrm = nrm * 2.0 - 1.0
    ln = np.linalg.norm(nrm, axis=-1, keepdims=True)
    nrm = np.where(ln > 1e-3, nrm / np.maximum(ln, 1e-3), np.array([0.0, 0.0, 1.0], dtype=np.float32))
    set_pass("props")
    pr, _ = unpremultiply(render_exr(os.path.join(tmp_dir, tag + "_p.exr")))
    set_pass("albedo")
    return {"albedo": alb, "alpha": alpha, "normal": nrm,
            "emit": np.clip(pr[..., 0], 0, 1), "shine": np.clip(pr[..., 1], 0, 1), "glow": np.clip(pr[..., 2], 0, 1)}


# ----------------------------------------------------------------------------------------------------------------
# Toon gölgeleme ve dış çizgi

def _dilate(a, r):
    """Gri tonlu genişletme (kare komşuluk, r piksel)."""
    out = a.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx == 0 and dy == 0:
                continue
            if dx * dx + dy * dy > r * r + r:
                continue
            sh = np.zeros_like(a)
            ys = slice(max(dy, 0), a.shape[0] + min(dy, 0))
            yd = slice(max(-dy, 0), a.shape[0] + min(-dy, 0))
            xs = slice(max(dx, 0), a.shape[1] + min(dx, 0))
            xd = slice(max(-dx, 0), a.shape[1] + min(-dx, 0))
            sh[yd, xd] = a[ys, xs]
            np.maximum(out, sh, out=out)
    return out


def toon(p, outline_px=2, ambient=0.16, levels=7, rim_k=0.10):
    """Albedo + normal → karanlık, sert ışıklı sRGB renk (premultiply değil) ve alfa; dış çizgili.
    Yarım-Lambert ışık 7 kademeye yuvarlanır (düşük poligonla uyumlu ama çizgi film değil), metal ve ıslak kan
    parlar (shine), ışıyan parçalar (gözler) gölgelenmez."""
    n = p["normal"]
    L = TOON_LIGHT / np.linalg.norm(TOON_LIGHT)
    lam = n @ L
    diff = np.clip(lam * 0.5 + 0.5, 0.0, 1.0) ** 1.5
    shade = np.clip(ambient + (1.0 - ambient) * diff * 1.2, 0.0, 1.1)
    shade = np.round(shade * levels) / levels
    h = L + np.array([0.0, 0.0, 1.0], dtype=np.float32)
    h /= np.linalg.norm(h)
    spec = np.clip(n @ h, 0.0, 1.0) ** 22 * p["shine"] * 0.9
    spec = np.round(spec * 4) / 4
    rim = np.clip(1.0 - n[..., 2], 0.0, 1.0) ** 3 * rim_k
    lin = (p["albedo"] * shade[..., None] + spec[..., None] * np.array([1.0, 0.93, 0.85], dtype=np.float32)
           + rim[..., None] * np.array([0.45, 0.42, 0.5], dtype=np.float32))
    e = p["emit"][..., None]
    lin = lin * (1.0 - e) + p["albedo"] * 1.25 * e
    rgb = linear_to_srgb(lin)
    a = p["alpha"]
    if outline_px > 0:
        dil = _dilate(a, outline_px)
        rgb = rgb * a[..., None] + OUTLINE_RGB * (1.0 - a[..., None])
        a = np.maximum(a, dil)
    return rgb.astype(np.float32), a.astype(np.float32)


def emissive_layer(p):
    """Karanlıkta parlayan parçalar (gözler vb.) için ayrı katman: renk ve alfa = ışıma maskesi. Yoksa None."""
    e = p["emit"] * p["alpha"]
    if e.max() < 0.05:
        return None
    rgb = linear_to_srgb(p["albedo"] * 1.3)
    # Aşama 10: ışımayan (saydam) piksellerin rengi sıfırlanır — yoksa PNG/WebP gereksiz renk verisi taşır (~35 kat büyük)
    rgb = np.where(e[..., None] > 0.5 / 255.0, rgb, 0.0)
    return np.concatenate([rgb, e[..., None]], axis=-1).astype(np.float32)


def normal_rgb(p, outline_px=2):
    """Godot'nun CanvasTexture normal haritası (OpenGL: yeşil yukarı). Dış çizgi kameraya bakar."""
    n = p["normal"].copy()
    a = p["alpha"]
    flat = np.array([0.0, 0.0, 1.0], dtype=np.float32)
    n = n * a[..., None] + flat * (1.0 - a[..., None])
    a2 = _dilate(a, outline_px) if outline_px > 0 else a
    return (n * 0.5 + 0.5).astype(np.float32), a2


# ----------------------------------------------------------------------------------------------------------------
# PNG yazma (Pillow'suz)

def write_png(path, arr):
    """arr: H×W×4 (RGBA) ya da H×W (gri) — 0..1 float ya da uint8."""
    if arr.dtype != np.uint8:
        arr = (np.clip(arr, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    h, w = arr.shape[:2]
    ctype = 6 if arr.ndim == 3 else 0
    rows = arr.reshape(h, -1)
    raw = np.concatenate([np.zeros((h, 1), np.uint8), rows], axis=1).tobytes()

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def downsample2(arr):
    h, w = arr.shape[:2]
    h2, w2 = h // 2, w // 2
    a = arr[:h2 * 2, :w2 * 2]
    return a.reshape(h2, 2, w2, 2, *arr.shape[2:]).mean(axis=(1, 3))


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
