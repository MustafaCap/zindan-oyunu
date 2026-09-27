## BloodDrips — Aşama 10: üst kenarından yavaşça kan damlayan süs (Kazandın/Öldün başlıkları, duraklatma paneli).
## Her damla yavaşça uzar, ucunda şişen bir damla taşır; boyuna ulaşınca damla kopup düşer ve iz biraz daha uzar.
## Oyun dururken de akar (PROCESS_MODE_ALWAYS). Sayılar görsel süstür, oyun dengesiyle ilgisi yok.
class_name BloodDrips
extends Control

var count: int = 9
var color: Color = UiTheme.BLOOD
var max_len: float = 70.0
## Üstte kan şeridi (başlığın altındaki çizgi) çizilsin mi
var band: bool = true
var seed_value: int = 7

var _drips: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = seed_value
	resized.connect(_reset)
	_reset()


func _reset() -> void:
	_drips.clear()
	if size.x <= 0.0:
		return
	for i: int in count:
		var x := (float(i) + _rng.randf_range(0.15, 0.85)) / float(count) * size.x
		_drips.append({"x": x, "len": _rng.randf_range(2.0, max_len * 0.3), "target": _rng.randf_range(0.25, 1.0) * max_len,
			"w": _rng.randf_range(2.0, 5.5), "speed": _rng.randf_range(2.5, 11.0), "drop": -1.0, "vel": 0.0})


func _process(delta: float) -> void:
	for d: Dictionary in _drips:
		if float(d["len"]) < float(d["target"]):
			d["len"] = minf(float(d["len"]) + float(d["speed"]) * delta, float(d["target"]))
		elif float(d["drop"]) < 0.0:
			# Uçtaki damla kopar; iz biraz uzar (en fazla max_len)
			d["drop"] = float(d["len"])
			d["vel"] = 0.0
			d["target"] = minf(float(d["len"]) + _rng.randf_range(4.0, 16.0), max_len)
			d["len"] = float(d["len"]) * 0.82
		if float(d["drop"]) >= 0.0:
			d["vel"] = float(d["vel"]) + 900.0 * delta
			d["drop"] = float(d["drop"]) + float(d["vel"]) * delta
			if float(d["drop"]) > size.y + 40.0:
				d["drop"] = -1.0
	queue_redraw()


func _draw() -> void:
	if band:
		draw_rect(Rect2(0, 0, size.x, 4), color)
	var glint := color.lightened(0.35)
	glint.a = 0.45
	for d: Dictionary in _drips:
		var x := float(d["x"])
		var w := float(d["w"])
		var l := float(d["len"])
		draw_rect(Rect2(x - w * 0.5, 0, w, l), color)
		draw_circle(Vector2(x, l), w * 0.8, color)
		draw_line(Vector2(x - w * 0.25, 2), Vector2(x - w * 0.25, maxf(l - 2.0, 2.0)), glint, 1.0)
		if float(d["drop"]) >= 0.0:
			draw_circle(Vector2(x, float(d["drop"])), w * 0.6, color)
