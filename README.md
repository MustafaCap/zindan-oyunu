# Zindan Oyunu

Godot 4 ile yaptığım 2D izometrik, öl-baştan-başla (roguelike) bir zindan oyunu. Windows ve Linux için.
Tasarımın tamamı [`docs/GDD.md`](docs/GDD.md)'de, derleme ve araç notları [`docs/GELISTIRME.md`](docs/GELISTIRME.md)'de.

## Oyunu indir

Bağlantılar her zaman son sürümü indirir (oyun sürümü 0.10.3). Repo özel, o yüzden önce tarayıcıda GitHub hesabınla giriş yap.
Bağlantılar yerine sağdaki **Releases** bölümünden [son sürümü](https://github.com/MustafaCap/zindan-oyunu/releases/latest) açıp dosyayı oradan da indirebilirsin. Sürüm
sayfasındaki "Source code" arşivlerinde oyun yok, yalnızca kaynak kod var.

**Windows:** [oyun.indir.zip](https://github.com/MustafaCap/zindan-oyunu/releases/latest/download/oyun.indir.zip) (~80 MB)

1. Zipe sağ tıkla → Tümünü ayıkla, sonra `ZindanOyunu.exe`'ye çift tıkla. Kurulum gerekmez.
2. Windows SmartScreen uyarırsa: Ek bilgi → Yine de çalıştır (.exe imzasız).

**Linux** (64 bit, x86_64): [oyun.indir.linux.tar.gz](https://github.com/MustafaCap/zindan-oyunu/releases/latest/download/oyun.indir.linux.tar.gz) (~70 MB)

1. Arşivi aç: `tar xzf oyun.indir.linux.tar.gz` (ya da dosya yöneticisinde sağ tık → Buraya çıkar).
2. Çalıştır: `./ZindanOyunu/ZindanOyunu.x86_64` ya da dosyaya sağ tık → Program olarak çalıştır. Çalıştırma izni arşivde hazır.
3. OpenGL 3.3 destekleyen bir ekran kartı sürücüsü yeterli; ayrıca bir şey kurmak gerekmez.

İlerleme (ustalık, ilk kesişler, ses ayarları) her cihazın kendi klasöründe tutulur, cihazlar arasında taşınmaz. Windows'ta
`%APPDATA%\Godot\app_userdata\Zindan Oyunu\`, Linux'ta `~/.local/share/godot/app_userdata/Zindan Oyunu/`. Hata olursa log
dosyası da orada: `logs/godot.log`.

## Oyun

- 4 ırk (Warrior, Ghost, Archer, Magical), her birinin iki yeteneği ve kendi silah ailesi. Başlangıç silahı ırk seçiminde seçilir.
- 12 silah tipi, 4 nadirlik, 6 element ve 5 özellik; elementler arası kombolar (Elektroşok, Erime, Donma…), 12 efsanevi silah.
- 4 kat, her katın kendi düşmanları ve boss'u (Morvath, Mycela, Kordrak, Nyx'thar). Haritalar her run'da yeniden üretilir.
- Envanter 4 slot: iki aktif silah, Rezonans ve Esnek slot. Tüccar, demirci, sandıklar, gizli odalar.
- Level ve boss ödülleri, kalıcı silah tipi ustalığı.
- Karanlık, kanlı bir görünüm; sprite'lar Blender'da modellenip render edildi, sesler ve müzik kodla sentezlendi.

## Kontroller

| Tuş | İşlev |
| --- | --- |
| WASD | Yürüme |
| Fare | Nişan |
| Sol / Sağ tık | Normal / güçlü saldırı |
| Q / E | Irk yetenekleri |
| Space | Atılma |
| Tab | Aktif silah değiştir |
| 1 | İksir (Ghost kullanamaz) |
| F | Etkileşim: yerdeki silah/tılsım, sandık, tüccar, demirci, merdiven |
| I | Envanter (sürükle-bırak, sağ tık aktif ↔ Rezonans; savaşta da açılır, açıkken oyun durur) |
| 1 / 2 | Ödül ekranında seçim (açıldıktan sonra 1,2 sn beklenir) |
| O | Ses ayarları |
| Esc | Duraklatma menüsü (ana menüye dönmek run'ı bırakır, ölüm sayılır) |
| F5 | Geliştirici menüsü: ırk, level, silahlar, kata ışınlanma, loot ve ilerleme testleri, test odası |
| R | Run sonu özetinde yeni run |

Test odasında ayrıca: 2-7 / 0 aktif silahın elementi, 8 özelliği, N yeni dalga, R yeniden başlat.

## Durum

GDD'deki 11 aşamanın hepsi bitti. Son sürüm **v0.1** (oyun sürümü 0.10.2), `main` dalında.

| Aşama | Konu | Sürüm |
| --- | --- | --- |
| 0 | Proje iskeleti, veri dosyaları, test çalıştırıcı | 0.0.1 |
| 1 | Vuruş hissi: hitstop, sarsıntı, flaş, savrulma | 0.1.0 |
| 2 | Savaş çekirdeği: hasar formülü, elementler, kombolar, özellikler | 0.2.0 |
| 3 | 4 ırk ve 12 silah tipi | 0.3.1 |
| 4 | Prosedürel zindan: odalar, koridorlar, gizli oda, minimap | 0.4.0 |
| 5 | Loot, 4 slotluk envanter, tüccar ve demirci | 0.5.0 |
| 6 | Oyuncu leveli, run ödülleri, kalıcı ustalık, kayıt | 0.6.0 |
| 7 | 55 düşman ve 4 boss | 0.7.0 |
| 8 | Sanat: Blender'da sprite'lar, ışık, karolar | 0.8.0 |
| 9 | Ses: efektler ve müzik | 0.9.0 |
| 10 | Menüler, denge simülasyonu, teslim; oyun testi düzeltmeleri, Linux sürümü | 0.10.0 – 0.10.3 |

Son değişiklikler:

- 0.10.3: Linux sürümü (`oyun.indir.linux.tar.gz`).

0.10.1 ve 0.10.2, oyun testinden sonra:

- Mycela'nın mantar totemleri yalnızca bir kez, canı %20'ye inince geliyor.
- Kordrak'ın canı 42.000'den 21.000'e, zırh plakalarının hasar azaltması %70'ten %50'ye indi. Kesince %65 ihtimalle 1 efsanevi ya da
  %35 ihtimalle 2 destansı silah düşüyor (en az level 40).
- Bağışık düşmana ana silah vuruşu %75 hasar veriyor; element durumu, süreli hasar, kombo, özellikler ve efsanevi pasifler işlemiyor.
- Envanter savaşta da düzenlenebiliyor (yerden eşya almak yine savaş dışında).
- Ödül ekranında ilk 1,2 saniye tıklama çalışmıyor (yanlışlıkla seçmemek için).
- 4. kat düşmanlarının canı ×8 yerine ×6.
- Irk seçiminde başlangıç silahı ailenin 3 tipinden seçiliyor, seçim hatırlanıyor.
- Sandıkların kendi nadirlik tablosu var: 2. katta en az ender, 3. katta en az destansı (%30 efsanevi), 4. katta hep efsanevi.
- F5 menüsünden kata ışınlanma düzeltildi.
- Rün işareti değişti (dişli halka ve ortada bir göz).
- Magical'ın normal vuruşu mana harcamıyor; sağ tık 45, Q 55, E 75 mana.

Açık kalanlar (GDD, Açık Kararlar): oyunun adı, kalan 16 boss, hikâye, ayrıntılı arayüz.

## Geliştirme

Gerekenler: Godot 4.7.2 ve aynı sürümün export şablonları, `make`, Python 3. Sprite ve ses üretimi için Blender 5.2.
Kurulum yolları ve bütün komutlar [`docs/GELISTIRME.md`](docs/GELISTIRME.md)'de.

```bash
make quick           # birim testleri + test odası smoke (~1 dk); tek dosya: make unit TEST_FILTER=menus
make test            # bütün testler (uzun)
make export-windows  # build/ içine ZindanOyunu.exe ve zip
make export-linux    # build/ içine ZindanOyunu.x86_64 ve tar.gz
make sprites BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"   # sprite'lar (~35 dk)
make sfx BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"       # ses ve müzik (~15 dk)
```

Godot PATH'te değilse: `make test GODOT=/c/Users/mcap5/Godot/Godot_v4.7.2-stable_win64_console.exe`.

Oyun ana menüyle açılır; komut satırında bir oyun bayrağı verilince menü atlanır (`godot --path . -- <bayrak>`,
test odası için `godot --path . res://scenes/test_room.tscn -- <bayrak>`):

- Zindan: `--seed=N` · `--floor=N` · `--god` · `--enemy-mult=0.2` · `--enemy-hp=X` · `--reveal` · `--open-menu` · `--menu` (menüde kal)
- Botlar: `--autoplay` (bot 4 katı oynar) · `--balance` (denge botu) · `--kill-hits=N` · `--boss-rush` · `--boss-test` · `--perf=SN`
- Loot ve arayüz: `--loot-rain` · `--fill-bag` · `--open-bag` · `--open-ui=merchant|blacksmith` · `--open-pause`
- İlerleme: `--grant-levels=N` · `--end-run=SN`
- Test odası: `--race=ghost --level=20 --weapons=scythe:water,dagger:lightning:fury` · `--dummies` · `--matrix`
- Ekran görüntüsü: `--shots=KLASÖR --shot-times=0.5,2,3`
- Bir katın haritasını ASCII basmak: `godot --headless --path . -s tools/dev/print_dungeon.gd -- --floor=2 --seed=42`

## Klasör yapısı

```
project.godot          proje ayarları (1920×1080, canvas_items, input map, autoload'lar)
export_presets.cfg     Windows Desktop ön ayarı
data/                  bütün denge sayıları (JSON)
scripts/autoload/      Events, DataDB, GameState, SaveManager, Audio
scripts/...            combat, player, enemies, bosses, dungeon, loot, progression, ui
scenes/                sahneler
assets/                sprite'lar (renk + normal + ışıma), shader'lar, sesler ve müzik, menü videosu
tools/                 blender/ (sprite ve menü videosu), audio/ (ses ve müzik sentezi), dev/ (denge tablosu, doku sıkıştırma)
tests/                 headless testler (run_tests.gd)
docs/                  GDD.md (tasarım), GELISTIRME.md (geliştirme notları)
```

Yeni silah, düşman ya da ödül eklemek için ilgili JSON'a bir kayıt eklemek yeterli. `DataDB` açılışta bütün dosyaları okur; eksik
alan, yanlış tip, bilinmeyen id ya da toplamı 1 olmayan olasılık varsa hangi dosyada ve hangi alanda olduğunu söyleyen bir hata verir
(oyun ekranında da kırmızıyla görünür). `_` ile başlayan anahtarlar açıklama notudur.
