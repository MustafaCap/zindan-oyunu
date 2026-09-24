## CombatMath — saf (yan etkisiz) savaş hesapları: yay içinde mi, zırh, kritik.
## Aşama 2'de DamageCalc tam hasar formülünü buraya ekleyecek; şimdilik prototip için gerekenler var.
class_name CombatMath
extends RefCounted


## Hedef, saldıranın önündeki yayın içinde mi?
## Tüm konumlar ekran uzayında verilir; hesap düz (zemin) uzayda yapılır.
## range_tiles ve target_radius_tiles karo cinsindendir. arc_degrees >= 360 ise tam daire.
static func in_arc(origin: Vector2, facing_cart: Vector2, target: Vector2,
		range_tiles: float, arc_degrees: float, target_radius_tiles: float = 0.0) -> bool:
	var to_target := Iso.to_cart(target - origin)
	var dist := to_target.length() / Iso.KARO
	if dist > range_tiles + target_radius_tiles:
		return false
	if arc_degrees >= 360.0 or dist < 0.001:
		return true
	var angle := absf(rad_to_deg(facing_cart.angle_to(to_target)))
	# Hedefin yarıçapı kadar açısal pay: yakındaki büyük hedefler yayın kenarında da vurulur.
	var slack := rad_to_deg(atan2(target_radius_tiles, maxf(dist, 0.001)))
	return angle <= arc_degrees * 0.5 + slack


## Zırh / hasar azaltma uygulanmış hasar. Azaltma tavanı dışarıdan verilir (progression.stat_caps).
static func apply_reduction(damage: float, reduction: float, cap: float) -> float:
	return damage * (1.0 - clampf(reduction, 0.0, cap))


## Kritik mi? rng verilirse ondan çeker (testlerde tekrarlanabilir olsun diye).
static func roll_crit(chance: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < chance
