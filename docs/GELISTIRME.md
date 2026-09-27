# Geliştirme notları

Oyunun tasarımı `docs/GDD.md`'de, projenin durumu README'de. Bu dosya derleme, araçlar ve çalışma düzeni için.

## Gerekenler

- **Godot 4.7.2** ve aynı sürümün export şablonları (`%APPDATA%\Godot\export_templates\4.7.2.stable\`). Komut satırından
  `..._win64_console.exe` kullanılır. PATH'te değilse Makefile'a `GODOT=` ile verilir:
  `make test GODOT=/c/Users/mcap5/Godot/Godot_v4.7.2-stable_win64_console.exe`
- **make** ve **python3**: MSYS2 (`C:\msys64\ucrt64\bin`). `zip` yok, `make export-windows` PowerShell'in `Compress-Archive`'ini kullanıyor.
- **Blender 5.2** (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`): sprite'lar ve sesler bununla üretiliyor, `bpy` ayrıca kurulmuyor.

## Komutlar

| Komut | Ne yapar |
| --- | --- |
| `make export-windows` | `build/windows/ZindanOyunu.exe` ve `build/zindan-oyunu-windows-vX.Y.Z.zip` |
| `make test` | Bütün testler: birim, test odası smoke, ırk × silah matrisi, zindan smoke, boss testi (uzun) |
| `make quick` | Birim testleri + test odası smoke (~1 dk) |
| `make unit` / `smoke` / `matrix` / `dungeon` / `bosses` | Testleri tek tek çalıştırır |
| `make sprites BLENDER="…"` | Bütün sprite'lar (~35 dk). Bir kısmı için `SPRITE_ARGS=--only=warrior,blade,tiles1,icons,props`; sonra `godot --headless --path . --import` |
| `make sfx BLENDER="…"` | Efektler (WAV) ve müzik (OGG), ~15 dk. `SFX_ARGS=--sfx` yalnızca efektler (~30 sn), `--music`, `--only=hit_flesh,floor_1` |
| `make balance` | Denge simülasyonu: 4 ırk × seed, ~15-25 dk, tablo `build/balance/balance.md` |
| `make perf` | Oyun penceresinde 90 sn FPS ölçümü |
| `make menu-video VIDEO=… BLENDER=…` | Ana menü videosundan `menu_intro.ogv`, `menu_loop.ogv` ve `menu.ogg` üretir (Godot yalnızca Theora oynatır; Blender'ın FFmpeg'i kullanılır) |
| `make textures` | Sprite sıkıştırmasını (renk/normal %85 WebP, ışıma katmanı kayıpsız) `.import`'lara yazar; `make sprites` sonunda kendisi çalışır |
| `make clean-alpha` | Işıma katmanlarındaki saydam piksellerin rengini sıfırlar |

`make` yoksa Makefile'daki komutlar doğrudan çalıştırılabilir:

```
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . --fixed-fps 60 res://scenes/test_room.tscn -- --autoplay
godot --headless --path . --fixed-fps 60 res://scenes/test_room.tscn -- --matrix
godot --headless --path . --fixed-fps 60 -- --autoplay --god --seed=1234 --enemy-mult=0.2
godot --headless --path . --export-release "Windows Desktop" build/windows/ZindanOyunu.exe
```

Test çıktısında "SCRIPT ERROR" varsa test başarısızdır.

## Kurallar ve dikkat edilecekler

- Denge sayıları koda yazılmaz, `data/*.json`'da `_default` notlarıyla durur. GDScript'te statik tipler, her script'in başında kısa açıklama.
- Görsel ve ses yönü: karanlık, kanlı, vahşi. Yeni sanat ve sesler bu tarza uymalı. Yeni bir ses eklenince `data/audio.json > sounds`'a
  varyant sayısıyla yazılır (test denetliyor).
- Oyun ana menüyle açılır (`scenes/main_menu.tscn`); komut satırında oyun bayrağı varsa menü atlanır, testler bu sayede değişmedi.
  Geliştirici (hata ayıklama) menüsü F5'te, Esc duraklatma menüsü.
- Zindan botunda (`--autoplay`) düşmanlar 4 hasarlı vuruşta ölür (`Enemy.bot_kill_hits`, `--kill-hits=N`); `--balance` ve
  `--boss-test`'te kapalı. Oyuncunun oyununu etkilemez.
- Testler ve bot oyuncunun dosyalarına (`user://save.json`, `settings.json`, `menu.json`) dokunmaz, ayrı dosyalar kullanır.
- Godot'nun içe aktarması `.import` dosyalarını yalnızca satır sonu farkıyla yeniden yazabilir (`git diff` boş, `git status` "M").
  Sprite PNG'leri de değiştiyse `git checkout -- assets/sprites` kullanılmaz (PNG'ler de geri gider). Yalnızca `.import`'ları
  geri almak için: `git diff --name-only | grep '\.import$' | xargs -r git checkout --`
- 27 Eyl 2026'dan beri testler her aşamada çalıştırılmıyor; oyun elle oynanarak test ediliyor, en azından .exe derleniyor.
  Testler kodla birlikte güncel tutuluyor.

## Git ve sürüm

- Her aşama kendi dalında (`asama-N`, bir öncekinden açılır). Commit mesajları Türkçe.
- Aşama bitince .exe derlenir, README ve GDD güncellenir, yerelde commit edilir. Oyun test edilip onaylanınca push:
  `git push -u origin asama-N`, sonra `git switch main`, `git merge --no-ff asama-N`, `git push origin main` (`gh` kurulu değil).
- Sürüm: `main`'de etiket (`git tag -a vX.Y`, `git push origin vX.Y`) ve GitHub **Releases**'e `oyun.indir.zip` (`make export-windows`
  zip'inin kopyası, içinde `ZindanOyunu.exe`). README'nin başındaki bağlantı (`releases/latest/download/oyun.indir.zip`) hep son sürümü
  indirir. .exe 153 MB olduğu için repoya konmaz (GitHub'ın dosya sınırı 100 MB).
- Derlemeler repo dışında, `ZindanOyunu-Derlemeler\asama-N\` klasörlerinde.
