"""Sprite üretici (Aşama 8'de yazılacak).

Karakter ve düşmanları Blender'da (bpy) low-poly modelleyip 8 yönden render alır,
renk ve normal map'i ayrı çıkarır, Pillow ile sprite sheet'e paketler.
Şimdilik yalnızca bir yer tutucu: `make sprites` hata vermeden geçer.
"""


def main() -> None:
    try:
        import bpy  # noqa: F401
        print("[sprites] bpy bulundu; sprite üretimi Aşama 8'de eklenecek.")
    except ImportError:
        print("[sprites] bpy kurulu değil; sprite üretimi Aşama 8'de eklenecek.")


if __name__ == "__main__":
    main()
