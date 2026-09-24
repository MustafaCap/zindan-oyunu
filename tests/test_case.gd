## Test sınıflarının temeli. Her test dosyası bunu extend eder ve "test_" ile başlayan
## fonksiyonlar yazar. run_tests.gd bu fonksiyonları bulup sırayla çalıştırır.
extends RefCounted

var failures: PackedStringArray = []
var assertions: int = 0
var current_test: String = ""


func assert_true(cond: bool, msg: String = "") -> void:
	assertions += 1
	if not cond:
		failures.append("%s: %s" % [current_test, msg if msg != "" else "beklenen true"])


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	assertions += 1
	if typeof(actual) in [TYPE_INT, TYPE_FLOAT] and typeof(expected) in [TYPE_INT, TYPE_FLOAT]:
		if absf(float(actual) - float(expected)) > 0.000001:
			failures.append("%s: %s beklenen=%s bulunan=%s" % [current_test, msg, expected, actual])
		return
	if actual != expected:
		failures.append("%s: %s beklenen=%s bulunan=%s" % [current_test, msg, expected, actual])


func assert_almost(actual: float, expected: float, tolerance: float, msg: String = "") -> void:
	assertions += 1
	if absf(actual - expected) > tolerance:
		failures.append("%s: %s beklenen≈%s (±%s) bulunan=%s" % [current_test, msg, expected, tolerance, actual])


## Test öncesi/sonrası kancaları (isteğe bağlı).
func before_each() -> void:
	pass


func after_each() -> void:
	pass
