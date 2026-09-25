SHELL := /bin/bash
# Zindan Oyunu — derleme ve test komutları
# Kullanım: make test | make unit | make smoke | make matrix | make dungeon | make bosses | make export-windows | make all

GODOT   ?= godot
BLENDER ?= blender
PYTHON  ?= python3
VERSION := $(shell grep -m1 'config/version' project.godot | cut -d'"' -f2)
WIN_DIR := build/windows
WIN_ZIP := build/zindan-oyunu-windows-v$(VERSION).zip

TEST_ROOM := res://scenes/test_room.tscn
# Zindan smoke testi: sabit seed, ölümsüz bot, düşman sayısı ×0,2 ve canı ×0,25 (haritanın yürünebilirliği denenir)
DUNGEON_ARGS ?= --autoplay --god --seed=1234 --enemy-mult=0.2 --enemy-hp=0.25
# Aşama 7 boss testi: bot her katta doğrudan boss'a gider, katın beklenen level ve silah gücüyle (ateş + buz kılıç)
BOSS_ARGS ?= --autoplay --god --boss-test --seed=7 --weapons=sword:fire,sword:ice

.PHONY: all import test quick unit smoke matrix dungeon bosses sprites sfx export-windows clean

all: sprites sfx test export-windows

# Godot'nun .godot/ önbelleğini oluşturur (ilk kez ya da yeni dosya eklendiğinde gerekli)
import:
	@mkdir -p build
	@$(GODOT) --headless --path . --import > /dev/null 2>&1

test: unit smoke matrix dungeon bosses

# Geliştirme sırasında hızlı kontrol (~1 dk): birim testleri + test odası smoke. Tam paket (make test) aşama sonunda bir kez.
quick: unit smoke

# Birim testleri (bir test script hatasıyla yarıda kesilirse de başarısız sayılır)
unit: import
	@$(GODOT) --headless --path . -s tests/run_tests.gd 2>&1 | tee build/unit.log ; \
	code=$${PIPESTATUS[0]}; \
	if grep -q "SCRIPT ERROR" build/unit.log; then echo "UNIT: script hatası (build/unit.log)"; exit 1; fi; \
	exit $$code

# Otomatik oynayan bot test odasını temizlemeli (çıkış kodu 0); hata ya da ölüm testi düşürür
smoke: import
	@$(GODOT) --headless --path . --fixed-fps 60 $(TEST_ROOM) -- --autoplay 2>&1 | tee build/smoke.log | grep -E "TestRoom|SCRIPT ERROR|ERROR" ; \
	code=$${PIPESTATUS[0]}; \
	if grep -q "SCRIPT ERROR" build/smoke.log; then echo "SMOKE: script hatası"; exit 1; fi; \
	if [ $$code -ne 0 ]; then echo "SMOKE: başarısız (kod $$code)"; exit 1; fi; \
	echo "SMOKE: geçti"

# Aşama 3 kabulü: her ırk × silah tipi (48 kombinasyon) sol tık, sağ tık, Q, E ve Tab ile denenir
matrix: import
	@$(GODOT) --headless --path . --fixed-fps 60 $(TEST_ROOM) -- --matrix 2>&1 | tee build/matrix.log | grep -E "\[Matris\] (✗|SONUÇ)|SCRIPT ERROR|ERROR" ; \
	code=$${PIPESTATUS[0]}; \
	if grep -q "SCRIPT ERROR" build/matrix.log; then echo "MATRIX: script hatası"; exit 1; fi; \
	if [ $$code -ne 0 ]; then echo "MATRIX: başarısız (kod $$code) — ayrıntı: build/matrix.log"; exit 1; fi; \
	echo "MATRIX: geçti"

# Aşama 4 kabulü: bot 4 katı baştan sona yürür — her odaya girer, gizli duvarı kırar, boss'ları keser, merdivenle iner
dungeon: import
	@$(GODOT) --headless --path . --fixed-fps 60 -- $(DUNGEON_ARGS) 2>&1 | tee build/dungeon.log | grep -E "\[Otopilot\] (.*(bitti|TAKILDI|GEZİLEMEYEN|SÜRE)|loot)|\[Zindan\] (ZAFER|Gizli|OYUNCU|Run sonu)|SCRIPT ERROR|ERROR" ; \
	code=$${PIPESTATUS[0]}; \
	if grep -q "SCRIPT ERROR" build/dungeon.log; then echo "DUNGEON: script hatası"; exit 1; fi; \
	if [ $$code -ne 0 ]; then echo "DUNGEON: başarısız (kod $$code) — ayrıntı: build/dungeon.log"; exit 1; fi; \
	echo "DUNGEON: geçti"

# Aşama 7 kabulü: her boss yenilebilir (süre sınırı içinde), tüm saldırılarını kullanır, 2. faza girer ve her
# saldırısı en az bosses.min_warn_sec önceden işaretlidir
bosses: import
	@$(GODOT) --headless --path . --fixed-fps 60 -- $(BOSS_ARGS) 2>&1 | tee build/bosses.log | grep -E "\[BossTest\]|\[Zindan\] ZAFER|\[Otopilot\] (TAKILDI|SÜRE)|SCRIPT ERROR|ERROR" ; \
	code=$${PIPESTATUS[0]}; \
	if grep -q "SCRIPT ERROR" build/bosses.log; then echo "BOSSES: script hatası"; exit 1; fi; \
	if [ $$code -ne 0 ]; then echo "BOSSES: başarısız (kod $$code) — ayrıntı: build/bosses.log"; exit 1; fi; \
	echo "BOSSES: geçti"

sprites:
	$(PYTHON) tools/blender/render_sprites.py

sfx:
	$(PYTHON) tools/audio/sfx_synth.py

export-windows: import
	rm -rf $(WIN_DIR) && mkdir -p $(WIN_DIR)
	$(GODOT) --headless --path . --export-release "Windows Desktop" $(WIN_DIR)/ZindanOyunu.exe
	@rm -f $(WIN_ZIP)
	@# zip yoksa (Windows Git Bash) PowerShell'in Compress-Archive'i kullanılır
	@if command -v zip > /dev/null 2>&1; then cd $(WIN_DIR) && zip -q -r ../$(notdir $(WIN_ZIP)) . ; 	else powershell.exe -NoProfile -Command "Compress-Archive -Path '$(WIN_DIR)/*' -DestinationPath '$(WIN_ZIP)' -Force" ; fi
	@echo "Hazır: $(WIN_ZIP)"

clean:
	rm -rf build .godot
