## Headless test çalıştırıcısı.
## Kullanım: godot --headless --path . -s tests/run_tests.gd
## tests/ içindeki tüm test_*.gd dosyalarını bulur, "test_" ile başlayan fonksiyonları çalıştırır.
## Hata varsa çıkış kodu 1 olur (make test başarısız sayılır).
extends SceneTree

const TEST_DIR := "res://tests"


func _initialize() -> void:
	# Autoload'ların _ready'si bitsin diye bir kare bekle.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var total_tests := 0
	var total_asserts := 0
	var all_failures: PackedStringArray = []
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("%s/%s" % [TEST_DIR, file])
		var suite: Object = script.new()
		var names: Array[String] = []
		for m: Dictionary in script.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not n in names:
				names.append(n)
		print("• %s (%d test)" % [file, names.size()])
		for n: String in names:
			suite.set("current_test", "%s::%s" % [file.get_basename(), n])
			# Her test temiz başlar: run durumu sıfır, kalıcı kayıt (ustalık, ilk kesiş) boş ve oyuncunun gerçek
			# kayıt dosyasından ayrı bir dosyada (testler user://save.json'a dokunmaz).
			var sm := root.get_node("SaveManager")
			sm.set("save_path", "user://save_unit_tests.json")
			sm.call("reset")
			root.get_node("GameState").call("reset_run")
			var before: int = (suite.get("failures") as PackedStringArray).size()
			suite.call("before_each")
			suite.call(n)
			suite.call("after_each")
			total_tests += 1
			var fails: PackedStringArray = suite.get("failures")
			print("    %s %s" % ["✓" if fails.size() == before else "✗", n])
		total_asserts += int(suite.get("assertions"))
		all_failures.append_array(suite.get("failures"))
	print("")
	if all_failures.is_empty():
		print("SONUÇ: %d test, %d doğrulama — HEPSİ GEÇTİ" % [total_tests, total_asserts])
		quit(0)
	else:
		for f: String in all_failures:
			printerr("  HATA: " + f)
		print("SONUÇ: %d test, %d doğrulama — %d HATA" % [total_tests, total_asserts, all_failures.size()])
		quit(1)
