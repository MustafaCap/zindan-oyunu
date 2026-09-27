# Geliştirme notları

Oyunun tasarımı `docs/GDD.md`'de, projenin durumu README'de. Bu dosya derleme, araçlar ve çalışma düzeni için.

## Gerekenler

- **Godot 4.7.2** ve aynı sürümün export şablonları (`%APPDATA%\Godot\export_templates\4.7.2.stable\`). Komut satırından
  `..._win64_console.exe` kullanılır. PATH'te değilse Makefile'a `GODOT=` ile verilir:
  `make test GODOT=/c/Users/mcap5/Godot/Godot_v4.7.2-stable_win64_console.exe`
- **make** ve **python3**: MSYS2 (`C:\msys64\ucrt64\bin`). `zip` yok, `make export-windows` PowerShell'in `Compress-Archive`'ini kullanıyor.
- **Blender 5.2** (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`): sprite'lar ve sesler bununla üretiliyor, `bpy` ayrıca kurulmuyor.
- **Android için** (yalnızca `make export-android`): Java 17+ (JDK) ve Android SDK'nın `platform-tools` ile `build-tools`'u. Ayrıntı aşağıda.

## Komutlar

| Komut | Ne yapar |
| --- | --- |
| `make export-windows` | `build/windows/ZindanOyunu.exe` ve `build/zindan-oyunu-windows-vX.Y.Z.zip` |
| `make export-linux` | `build/linux/ZindanOyunu.x86_64` ve `build/zindan-oyunu-linux-vX.Y.Z.tar.gz` (tar.gz çalıştırma iznini korur; `tools/dev/pack_linux.py`) |
| `make export-android` | `build/android/ZindanOyunu.apk` ve `build/zindan-oyunu-android-vX.Y.Z.apk` (arm64, Android 7+, `tools/android/zindan-oyunu.keystore` ile imzalı) |
| `make android-icons` | Android uygulama simgelerini (`assets/icon/`) Warrior sprite'ı ve kılıç ikonundan yeniden üretir |
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
- Testler ve bot oyuncunun dosyalarına (`user://save.json`, `run.json`, `settings.json`, `menu.json`) dokunmaz, ayrı dosyalar kullanır.
  Run kaydı (`run.json`, v0.11.1) komut satırında oyun bayrağı varken hiç yazılmaz; birim testleri `run_unit_tests.json` kullanır.
- Godot'nun içe aktarması `.import` dosyalarını yalnızca satır sonu farkıyla yeniden yazabilir (`git diff` boş, `git status` "M").
  Sprite PNG'leri de değiştiyse `git checkout -- assets/sprites` kullanılmaz (PNG'ler de geri gider). Yalnızca `.import`'ları
  geri almak için: `git diff --name-only | grep '\.import$' | xargs -r git checkout --`
- 27 Eyl 2026'dan beri testler her aşamada çalıştırılmıyor; oyun elle oynanarak test ediliyor, en azından .exe derleniyor.
  Testler kodla birlikte güncel tutuluyor.

## Android

Oyun Android'de Godot'nun hazır APK şablonuyla derlenir (Gradle gerekmez). Dokunmatik mod telefonda kendiliğinden açılır
(`Mobile` autoload'u); masaüstünde `godot --path . -- --touch --ui-scale=1.385` telefon görünümünü ve dokunmatik kontrolleri
fareyle dener (`--ui-scale` olmadan masaüstü ölçeği).

**Bu bilgisayarda kurulum (bir kez):**

1. JDK 17 (ör. Adoptium Temurin 17) ve Android SDK: en kolayı Android Studio (SDK Manager'dan "Android SDK Platform-Tools" ve
   "Android SDK Build-Tools 35"). Yalnızca komut satırı araçlarıyla da olur: `sdkmanager "platform-tools" "build-tools;35.0.0"`.
2. Godot editöründe Editor → Editor Settings → Export → Android: **Java SDK Path** (JDK klasörü) ve **Android SDK Path**
   (ör. `C:\Users\mcap5\AppData\Local\Android\Sdk`). Komut satırından derleme de bu ayarları okur.
3. `make export-android GODOT=/c/Users/mcap5/Godot/Godot_v4.7.2-stable_win64_console.exe`

**İmza anahtarı:** `tools/android/zindan-oyunu.keystore` (alias `zindan`, parola `zindan-oyunu`) yalnızca yan yükleme (APK'yı
elle kurma) içindir ve bilerek repoda: aynı anahtarla imzalanan yeni APK eskisinin üstüne kurulur, ilerleme silinmez. Anahtar
değişirse telefondaki oyun kaldırılıp yeniden kurulmalı (ilerleme gider). Google Play'e çıkılacaksa repoda olmayan ayrı bir
yükleme anahtarı üretilir ve `make export-android ANDROID_KEYSTORE=... ANDROID_KEY_USER=... ANDROID_KEY_PASS=...` ile verilir;
Play ayrıca APK yerine AAB ister (Gradle derlemesi: Project → Install Android Build Template, ön ayarda `gradle_build/use_gradle_build`).

**Sürüm kodu:** `export_presets.cfg` > Android > `version/code` oyun sürümünden türetilir (0.11.0 → 1100, `major*10000 +
minor*100 + patch`) ve sürüm her değiştiğinde elle güncellenir; artmazsa telefon güncellemeyi kurmaz (`test_project` denetler).

**Telefonda denemek:** APK'yı telefona at (USB, Drive) ve dokun; ya da USB hata ayıklama açıkken `adb install -r build/android/ZindanOyunu.apk`.
Log: `adb logcat -s godot`. Performans ölçümü (`--perf`) telefonda yok; kare hızı sorunu olursa önce ışık sayısı ve çözünürlük denenir.

**GitHub Actions (`.github/workflows/android.yml`, "Derlemeler"; v0.11.1'den beri üç sürüm):** her dala ve `v*` etiketlerine
push'ta Windows zip'ini, Linux tar.gz'sini ve APK'yı GitHub'ın makinesinde derler (`make export-windows export-linux
export-android`; Android SDK orada hazır), zip ve tar.gz'nin içini ve APK imzasını denetler. Actions → "Derlemeler" → çalıştırma
→ Artifacts → `ZindanOyunu-windows`, `ZindanOyunu-linux`, `ZindanOyunu-apk` (her biri zip, içinde dosya; 30 gün durur).
`v*` etiketi push'lanınca üç dosya o etiketin sürümüne `oyun.indir.zip`, `oyun.indir.linux.tar.gz` ve `oyun.indir.apk` adlarıyla
eklenir (sürüm yoksa açılır, aynı adlı dosya varsa yenisi konur). Actions sekmesinden "Run workflow" ile elle de çalışır.
Derlemeler 30 MB'tan büyük olduğu için dosyaları sohbet ya da e-postayla göndermek yerine bu yol kullanılır.

**Bulut oturumu (Claude Code):** dl.google.com kapalı olduğu için Android SDK indirilemez. `tools/android/setup_sdk_lite.sh`
Godot'nun baktığı en küçük SDK'yı kurar (`~/Android/Sdk`: boş `adb` ve Maven Central'daki apksig ile çalışan `apksigner`;
yalnızca v2 imzası, Android 7+ için yeterli). Godot 4.7.2 ve şablonlar GitHub'dan indirilir.

## Git ve sürüm

- Her aşama kendi dalında (`asama-N`, bir öncekinden açılır). Commit mesajları Türkçe.
- Aşama bitince .exe derlenir, README ve GDD güncellenir, yerelde commit edilir. Oyun test edilip onaylanınca push:
  `git push -u origin asama-N`, sonra `git switch main`, `git merge --no-ff asama-N`, `git push origin main` (`gh` kurulu değil).
- Sürüm: `main`'de etiket (`git tag -a vX.Y`, `git push origin vX.Y`; v0.11.1'den beri etiket push'lanınca GitHub Actions üç
  dosyayı sürüme kendisi ekler) ve GitHub **Releases**'e Linux için `oyun.indir.linux.tar.gz`
  (`make export-linux` arşivinin kopyası), Windows için `oyun.indir.zip` (`make export-windows`
  zip'inin kopyası, içinde `ZindanOyunu.exe`), Android için `oyun.indir.apk` (`make export-android` APK'sının kopyası). README'nin başındaki bağlantı (`releases/latest/download/oyun.indir.zip`) hep son sürümü
  indirir. .exe 153 MB olduğu için repoya konmaz (GitHub'ın dosya sınırı 100 MB).
- Derlemeler repo dışında, `ZindanOyunu-Derlemeler\asama-N\` klasörlerinde.

## Linux'ta denemek (bu bilgisayarda)

WSL'de Ubuntu kurulu ve WSLg pencere açabiliyor. `make export-linux`'tan sonra arşiv WSL'de açılıp çalıştırılabilir:

```
wsl -d Ubuntu
mkdir -p ~/zindan-test && cd ~/zindan-test
tar xzf "/mnt/c/Users/mcap5/Git_Dosyaları/ZindanOyunu-Derlemeler/zindan-oyunu/build/zindan-oyunu-linux-vX.Y.Z.tar.gz"
./ZindanOyunu/ZindanOyunu.x86_64
```

WSL'de çizim yazılımsal (Mesa llvmpipe) olduğu için yavaştır ve bu Ubuntu'da ses kütüphanesi olmadığından oyun sessiz sürücüye
geçer; ikisi de normal bir Linux masaüstünde sorun değil. `-- --seed=5 --shots=KLASÖR --shot-times=4,7` ile ekran görüntüsü alınabilir.

