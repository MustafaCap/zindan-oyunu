## Geliştirme aracı: bir katın haritasını ASCII olarak konsola basar.
## Kullanım: godot --headless --path . -s tools/dev/print_dungeon.gd -- --floor=1 --seed=42
## (Autoload'lar -s script'i derlenirken henüz yok; bu yüzden asıl kod çalışma anında yüklenir.)
extends SceneTree

func _initialize() -> void:
	process_frame.connect(func() -> void:
		load("res://tools/dev/print_dungeon_impl.gd").new().run()
		quit(0), CONNECT_ONE_SHOT)
