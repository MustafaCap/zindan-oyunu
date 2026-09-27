## PerfProbe — Aşama 10 performans ölçümü (--perf=SN): her saniye FPS, işlem/fizik süresi, çizim çağrısı, düğüm ve
## düşman sayısını yazar; SN saniye sonra özet (ortalama, en düşük 1 sn FPS, %1'lik en yavaş kare) yazıp oyunu kapatır.
## Gerçek pencerede (headless değil, --fixed-fps olmadan) botla birlikte çalıştırılır: 60 FPS hedefini denetlemek için.
class_name PerfProbe
extends Node

var duration: float = 60.0
var _t: float = 0.0
var _sec_t: float = 0.0
var _frames: Array[float] = []
var _fps_samples: Array[float] = []
var _worst: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	_sec_t += delta
	if _t > 3.0:   # açılış yüklemesi sayılmaz
		_frames.append(delta)
	if _sec_t >= 1.0:
		_sec_t = 0.0
		var fps := Performance.get_monitor(Performance.TIME_FPS)
		var line := {"t": roundi(_t), "fps": fps,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"enemies": get_tree().get_nodes_in_group("enemies").size()}
		if _t > 3.0:
			_fps_samples.append(fps)
			if _worst.is_empty() or fps < float(_worst["fps"]):
				_worst = line
		print("[Perf] %ds: %d FPS · işlem %.1f ms · fizik %.1f ms · çizim %d · düğüm %d · düşman %d" % [line["t"], line["fps"],
			line["process_ms"], line["physics_ms"], line["draw_calls"], line["nodes"], line["enemies"]])
	if _t >= duration:
		_report()
		get_tree().quit(0)


func _report() -> void:
	if _frames.is_empty():
		return
	var sorted := _frames.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size() * 0.99)]
	var avg := 0.0
	for f: float in _frames:
		avg += f
	avg /= _frames.size()
	var min_fps: float = _fps_samples.min() if not _fps_samples.is_empty() else 0.0
	print("[Perf] ÖZET: ortalama %.1f FPS (%.2f ms), en düşük 1 sn %d FPS, %%1 en yavaş kare %.1f ms, 60 altı saniye %d/%d · en kötü an %s" % [
		1.0 / avg, avg * 1000.0, min_fps, p99 * 1000.0, _fps_samples.filter(func(x: float) -> bool: return x < 59.0).size(),
		_fps_samples.size(), _worst])
