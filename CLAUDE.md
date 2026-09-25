# Zindan Oyunu — Claude Code çalışma kuralları

Bu dosya Claude Code'un her oturumda otomatik okuduğu kurallardır. Oyunun tasarımı ve yapım rehberi `docs/GDD.md`'dedir;
kaldığımız yer README'nin **Durum** bölümünde ve GDD'nin **Proje Durumu ve Çalışma Düzeni** bölümündedir.

## Her oturumun başında
1. `docs/GDD.md`'nin tamamını oku. Özellikle **Uygulamada Verilen Kararlar** (kullanıcının onayladığı değişiklikler dahil)
   ve **Proje Durumu ve Çalışma Düzeni** bölümleri tasarımın geri kalanıyla aynı ağırlıktadır.
2. README'deki **Durum** bölümünü oku; sıradaki aşamayı buradan bul.
3. `git status` ve `git branch` ile hangi dalda olduğunu kontrol et.

## Çalışma kuralları
- Oyun GDD'deki **Uygulama Rehberi**'ne göre aşama aşama yapılır. Bir aşamayı bitirmeden sonrakine geçme; aşama bitince dur
  ve kullanıcıya 3-5 maddelik "şunları test et" listesi ver.
- **Tasarım kararlarını değiştirmeden önce kullanıcıya sor.** GDD'de olmayan bir ayrıntıda en makul kararı ver, kullanıcıya
  bildir ve GDD'nin "Uygulamada Verilen Kararlar" bölümüne yaz.
- Kullanıcı bir değişiklik isterse onu hem koda/veriye hem README'ye hem GDD'ye işle (GDD'de "Kullanıcının onayladığı
  değişiklikler" tablosuna da ekle). Hiçbir bilgi eksik kalmasın.
- Oyun veri odaklıdır: denge sayıları koda yazılmaz, `data/*.json`'a yazılır (`_default` notuyla). GDScript'te statik tipler,
  her script'in başında kısa Türkçe açıklama.
- Kullanıcıyla Türkçe konuş. Kullanıcı Git öğreniyor: branch, commit, merge adımlarını kısaca açıkla.

## Git
- Her aşama kendi dalında: bir önceki aşamanın dalından `asama-N` aç (ör. `git switch -c asama-6 asama-5`).
- Commit mesajları Türkçe ve anlamlı. Push ve PR'dan önce kullanıcıya sor.
- Kullanıcı **Git Bash** kullanıyor: ona vereceğin komutlarda yol ayıracı `/` olsun (`\` değil).

## Test ve derleme (Windows)
- Godot 4.7.2 ve aynı sürümün export şablonları gerekir. `godot` komutu yoksa kullanıcıya kurulumu adım adım anlat
  (Godot'yu GitHub releases'tan indir, PATH'e ekle ya da `GODOT=/c/.../Godot_v4.7.2-stable_win64_console.exe` kullan).
- `make test` tüm testleri çalıştırır (birim, test odası smoke, ırk×silah matrisi, zindan smoke). `make` kurulu değilse
  Makefile'daki komutları doğrudan çalıştır, ör.:
  - `godot --headless --path . --import`
  - `godot --headless --path . -s tests/run_tests.gd` (çıktıda "SCRIPT ERROR" varsa test başarısızdır)
  - `godot --headless --path . --fixed-fps 60 res://scenes/test_room.tscn -- --autoplay`
  - `godot --headless --path . --fixed-fps 60 res://scenes/test_room.tscn -- --matrix`
  - `godot --headless --path . --fixed-fps 60 -- --autoplay --god --seed=1234 --enemy-mult=0.2`
- `.exe`: `godot --headless --path . --export-release "Windows Desktop" build/windows/ZindanOyunu.exe`.
- Aşama sonunda: testler → .exe → README **Durum** + `docs/GDD.md` güncelle (verilen kararlar ve proje durumu) → commit.
