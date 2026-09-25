## BossOverlay — boss arenasının zemin üstü katmanı (Mycela'nın spor sisi, Kordrak'ın lav kanalları, Nyx'thar'ın
## karanlığı ve çöken kenarları, Morvath'ın ışın işaretleri). Çizimi boss'un draw_overlay() fonksiyonu yapar.
class_name BossOverlay
extends Node2D

var boss: Boss


func _ready() -> void:
	z_index = -3


func _draw() -> void:
	if boss == null or not is_instance_valid(boss) or boss.dead:
		return
	boss.draw_overlay(self)
