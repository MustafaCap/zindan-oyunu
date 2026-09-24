## Iso — izometrik koordinat yardımcıları.
## Ekran (screen) uzayı: Godot'nun çizdiği 2:1 izometrik düzlem (karo 64×32 piksel).
## Düz (cart) uzay: ekranın Y ekseni 2 ile çarpılmış hali; burada mesafe ve açılar "gerçek" zemin ölçüsüdür.
## 1 karo = izometrik karonun kenar uzunluğu (düz uzayda TILE_W / √2 ≈ 45,25 birim).
class_name Iso
extends RefCounted

const TILE_W := 64
const TILE_H := 32
const KARO := 45.254834  # TILE_W / sqrt(2)


## Ekran vektörünü düz (zemin) vektörüne çevirir.
static func to_cart(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * 2.0)


## Düz (zemin) vektörü ekran vektörüne çevirir.
static func to_screen(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * 0.5)


## İki ekran noktası arasındaki zemin mesafesi, karo cinsinden.
static func tile_distance(a: Vector2, b: Vector2) -> float:
	return to_cart(b - a).length() / KARO


## Karo cinsinden bir uzunluğu düz uzay birimine çevirir.
static func tiles(n: float) -> float:
	return n * KARO
