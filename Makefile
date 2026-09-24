SHELL := /bin/bash
# Zindan Oyunu — derleme ve test komutları
# Kullanım: make test | make export-windows | make sprites | make sfx | make all

GODOT   ?= godot
BLENDER ?= blender
PYTHON  ?= python3
VERSION := $(shell grep -m1 'config/version' project.godot | cut -d'"' -f2)
WIN_DIR := build/windows
WIN_ZIP := build/zindan-oyunu-windows-v$(VERSION).zip

.PHONY: all import test unit smoke sprites sfx export-windows clean

all: sprites sfx test export-windows

# Godot'nun .godot/ önbelleğini oluşturur (ilk kez ya da yeni dosya eklendiğinde gerekli)
import:
	@mkdir -p build
	@$(GODOT) --headless --path . --import > /dev/null 2>&1

test: unit smoke

# Birim testleri
unit: import
	$(GODOT) --headless --path . -s tests/run_tests.gd

# Otomatik oynayan bot test odasını temizlemeli (çıkış kodu 0); hata ya da ölüm testi düşürür
smoke: import
	@$(GODOT) --headless --path . --fixed-fps 60 -- --autoplay 2>&1 | tee build/smoke.log | grep -E "TestRoom|SCRIPT ERROR|ERROR" ; \
	code=$${PIPESTATUS[0]}; \
	if grep -q "SCRIPT ERROR" build/smoke.log; then echo "SMOKE: script hatası"; exit 1; fi; \
	if [ $$code -ne 0 ]; then echo "SMOKE: başarısız (kod $$code)"; exit 1; fi; \
	echo "SMOKE: geçti"

sprites:
	$(PYTHON) tools/blender/render_sprites.py

sfx:
	$(PYTHON) tools/audio/sfx_synth.py

export-windows: import
	rm -rf $(WIN_DIR) && mkdir -p $(WIN_DIR)
	$(GODOT) --headless --path . --export-release "Windows Desktop" $(WIN_DIR)/ZindanOyunu.exe
	cd $(WIN_DIR) && zip -q -r ../$(notdir $(WIN_ZIP)) .
	@echo "Hazır: $(WIN_ZIP)"

clean:
	rm -rf build .godot
