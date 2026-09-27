"""Aşama 10: ana menü videosunu oyuna hazırlar (ffmpeg gerekmez; Blender'ın kendi FFmpeg'i ve `aud` ses modülü kullanılır).
Godot 4 yalnızca Ogg Theora oynatır; MP4/MOV/WebM gibi videolar önce buna çevrilmelidir. Üç dosya üretir:

  assets/video/menu_intro.ogv   videonun tamamı, sessiz — menü oyun açılışında bir kez bunu oynatır (kanlı giriş)
  assets/video/menu_loop.ogv    videonun kansız ilk --calm-end saniyesi: --slow ile yavaşlatılır (komşu kareler karıştırılır)
                                ve ileri-geri (boomerang) dizilir; başı ve sonu aynı kareye bağlandığı için sıçramasız döner
  assets/audio/music/menu.ogg   videonun sesi menü müziği olarak: yükselen ses düzeyi yumuşakça dengelenir, sonu başına
                                --xfade saniyelik çapraz geçişle bağlanır (sıçramasız döngü), düzeyi 1. kat ambiyansına eşitlenir

Kullanım (make menu-video VIDEO=...):
  blender -b --factory-startup --python tools/blender/menu_video.py -- --in=VIDEO.mp4
          [--calm-end=1.3] [--slow=0.5] [--kbps=5000] [--height=1080] [--xfade=1.5] [--no-audio]
--calm-end: kanın akmaya başlamadığı son an (sn; kullanıcının videosunda damla ~1,4. sn'de belirir).
"""
import math
import os
import shutil
import sys
import tempfile

import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VIDEO_DIR = os.path.join(ROOT, "assets", "video")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")


def arg(name, default=None):
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for a in args:
        if a == "--" + name:
            return True
        if a.startswith("--" + name + "="):
            return a.split("=", 1)[1]
    return default


def strips_of(scene):
    se = scene.sequence_editor_create()
    return se.strips if hasattr(se, "strips") else se.sequences


def clear_strips(scene):
    strips = strips_of(scene)
    for s in list(strips):
        strips.remove(s)


def setup_render(scene, w, h, fps):
    scene.view_settings.view_transform = "Standard"   # AgX/Filmic videonun renklerini soldurur
    r = scene.render
    r.resolution_x, r.resolution_y, r.resolution_percentage = w, h, 100
    r.fps = int(round(fps))
    r.fps_base = r.fps / fps
    r.use_file_extension = False


def set_image_output(scene):
    im = scene.render.image_settings
    if hasattr(im, "media_type"):
        im.media_type = "IMAGE"
    im.file_format = "PNG"
    im.color_mode = "RGB"


def render_ogv(scene, out, frames, kbps, fps):
    im = scene.render.image_settings
    if hasattr(im, "media_type"):
        im.media_type = "VIDEO"
    im.file_format = "FFMPEG"
    ff = scene.render.ffmpeg
    ff.format = "OGG"
    ff.codec = "THEORA"
    ff.constant_rate_factor = "NONE"
    ff.video_bitrate = kbps
    ff.gopsize = int(round(fps))
    ff.audio_codec = "NONE"
    scene.frame_start, scene.frame_end = 1, frames
    tmp = out + ".tmp"
    scene.render.filepath = tmp
    bpy.ops.render.render(animation=True)
    if os.path.exists(out):
        os.remove(out)
    os.replace(tmp, out)


def read_png(path, w, h):
    img = bpy.data.images.load(path)
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px


def write_png(path, px, w, h):
    img = bpy.data.images.new("kare", w, h, alpha=False)
    img.pixels.foreach_set(np.clip(px, 0.0, 1.0))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def make_video(src, calm_end, slow, kbps, max_h):
    scene = bpy.context.scene
    clear_strips(scene)
    movie = strips_of(scene).new_movie("video", src, 1, 1)
    w0, h0 = movie.elements[0].orig_width, movie.elements[0].orig_height
    fps = movie.fps if movie.fps > 0 else 30.0
    frames = movie.frame_final_duration
    k = min(1.0, max_h / float(h0))
    w, h = int(round(w0 * k / 2.0)) * 2, int(round(h0 * k / 2.0)) * 2
    setup_render(scene, w, h, fps)
    if (w, h) != (w0, h0) and hasattr(movie, "transform"):
        movie.transform.scale_x = movie.transform.scale_y = k
    os.makedirs(VIDEO_DIR, exist_ok=True)
    intro = os.path.join(VIDEO_DIR, "menu_intro.ogv")
    render_ogv(scene, intro, frames, kbps, fps)
    print("[Video] giriş: %dx%d, %.2f fps, %d kare (%.1f sn), %.1f MB" % (w, h, fps, frames, frames / fps, os.path.getsize(intro) / 1e6))

    # Sakin döngü: kansız kareleri PNG olarak al, yavaşlat (komşu kareleri karıştırarak), ileri-geri diz.
    calm = max(2, min(frames, int(math.floor(calm_end * fps)) + 1))
    tmp_dir = tempfile.mkdtemp(prefix="menu_loop_")
    try:
        set_image_output(scene)
        src_px = []
        for f in range(1, calm + 1):
            scene.frame_set(f)
            p = os.path.join(tmp_dir, "kaynak_%04d.png" % f)
            scene.render.filepath = p
            bpy.ops.render.render(write_still=True)
            src_px.append(read_png(p, w, h))
        steps = int(round((calm - 1) / slow))
        forward = []
        for i in range(steps + 1):
            t = min(i * slow, calm - 1.0)
            a = int(math.floor(t))
            b = min(a + 1, calm - 1)
            u = t - a
            forward.append(src_px[a] * (1.0 - u) + src_px[b] * u if u > 1e-4 else src_px[a])
        seq = forward + forward[-2:0:-1]   # uçlar tekrarlanmaz: son kare → ilk kare arasında sıçrama yok
        clear_strips(scene)
        names = []
        for i, px in enumerate(seq):
            names.append("dongu_%04d.png" % i)
            write_png(os.path.join(tmp_dir, names[-1]), px, w, h)
        strip = strips_of(scene).new_image("dongu", os.path.join(tmp_dir, names[0]), 1, 1)
        for n in names[1:]:
            strip.elements.append(n)
        strip.frame_final_duration = len(names)
        loop = os.path.join(VIDEO_DIR, "menu_loop.ogv")
        render_ogv(scene, loop, len(names), kbps, fps)
        print("[Video] döngü: kaynak %d kare (0-%.2f sn), ×%.2f hız, ileri-geri %d kare (%.1f sn), %.1f MB"
              % (calm, (calm - 1) / fps, slow, len(names), len(names) / fps, os.path.getsize(loop) / 1e6))
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)
    old = os.path.join(VIDEO_DIR, "menu.ogv")   # eski tek dosyalı sürüm
    for p in (old, old + ".import", old + ".uid"):
        if os.path.exists(p):
            os.remove(p)


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)))) + 1e-9


def make_music(src, xfade):
    import aud
    snd = aud.Sound(src)
    sr = int(snd.specs[0])
    x = np.array(snd.data(), dtype=np.float32)
    if x.ndim == 1:
        x = x[:, None]
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    x = x[:, :2]
    if rms(x) < 1e-5:
        print("[Video] videoda ses yok: menü müziği üretilmedi")
        return
    # Ses düzeyi videoda yükseliyor (~-38 → -27 dB): 1 sn'lik RMS zarfı yumuşakça dengelenir (damlalar korunur).
    mono = x.mean(axis=1)
    win = sr
    c = np.concatenate([[0.0], np.cumsum(mono.astype(np.float64) ** 2)])
    idx = np.arange(len(mono))
    lo = np.clip(idx - win // 2, 0, len(mono))
    hi = np.clip(idx + win // 2, 0, len(mono))
    env = np.sqrt((c[hi] - c[lo]) / np.maximum(hi - lo, 1)) + 1e-6
    gain = np.clip((np.median(env) / env) ** 0.8, 0.5, 4.0).astype(np.float32)
    x = x * gain[:, None]
    # Sıçramasız döngü: döngü x[D:N]; son D örnek, x'in sonuyla başını eşit güçte karıştırır.
    d = int(xfade * sr)
    n = len(x)
    loop = x[d:].copy()
    th = np.linspace(0.0, math.pi / 2.0, d, dtype=np.float32)[:, None]
    loop[-d:] = x[n - d:] * np.cos(th) + x[:d] * np.sin(th)
    # Düzey: 1. kat ambiyansıyla aynı RMS; tepe 0,9'u geçmesin
    ref_path = os.path.join(MUSIC_DIR, "floor_1.ogg")
    target = rms(np.array(aud.Sound(ref_path).data(), dtype=np.float32)) if os.path.exists(ref_path) else 0.1
    loop *= target / rms(loop)
    peak = float(np.abs(loop).max())
    if peak > 0.9:
        loop *= 0.9 / peak
    out = os.path.join(MUSIC_DIR, "menu.ogg")
    data = np.ascontiguousarray(loop.astype(np.float32))
    aud.Sound.buffer(data, sr).write(out, sr, aud.CHANNELS_STEREO, aud.FORMAT_FLOAT32, aud.CONTAINER_OGG, aud.CODEC_VORBIS, 112000)
    print("[Video] müzik: %.1f sn döngü (çapraz geçiş %.1f sn), RMS %.1f dB, tepe %.1f dB, %.2f MB"
          % (len(loop) / sr, xfade, 20 * math.log10(rms(loop)), 20 * math.log10(float(np.abs(loop).max()) + 1e-9), os.path.getsize(out) / 1e6))


def main():
    src = arg("in")
    if not src or not os.path.exists(src):
        print("[Video] HATA: --in=VIDEO verilmeli (bulunamadı: %s)" % src)
        sys.exit(1)
    src = os.path.abspath(src)
    make_video(src, float(arg("calm-end", "1.3")), float(arg("slow", "0.5")), int(arg("kbps", "5000")), int(arg("height", "1080")))
    if not arg("no-audio"):
        make_music(src, float(arg("xfade", "1.5")))


main()
