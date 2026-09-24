# Zindan Oyunu

2D izometrik, öl-baştan-başla (roguelike) bir zindan oyunu. Godot 4 ile yapılıyor; hedef platform Windows.
Tasarımın tamamı [`docs/GDD.md`](docs/GDD.md) içinde; oyun oradaki **Uygulama Rehberi**'ni adım adım takip ederek yapılıyor.

## Durum

| Aşama | Konu | Durum |
| --- | --- | --- |
| 0 | Ortam ve iskelet | ✅ Bitti |
| 1 | Vuruş hissi prototipi | ✅ Bitti (vuruş hissi onaylandı) |
| 2 | Savaş çekirdeği | ✅ Bitti (kombolar onaylandı) |
| 3 | Irklar ve silahlar | ✅ Bitti (onaylandı) |
| 4 | Zindan üretimi | 🧪 Kullanıcı testinde |
| 5 | Loot ve envanter | — |
| 6 | İlerleme | — |
| 7 | Düşmanlar ve boss'lar | — |
| 8 | Sanat | — |
| 9 | Ses | — |
| 10 | Menüler, denge ve teslim | — |

**Kalınan yer:** Aşama 4 (sürüm 0.4.0) kodlandı. Oyun artık 4 katlık zindanla açılır:
- `DungeonGenerator` her kat için seed'den harita üretir: oda ızgarası (girişten boss'a ana yol + yan dallar), oda
  tipleri (savaş, elit, tüccar, demirci, sandık, gizli, boss), 11 oda şablonu (8 savaş şablonu) + döndürme/aynalama,
  3 karoluk koridorlar, rastgele engeller (her odanın tüm zemini kapıdan ulaşılabilir kalır) ve düşman dalgaları.
- `RoomController`: odaya girince kapılar kilitlenir, dalgalar gelir, temizlenince açılır; savaş sürerken ırk/silah
  değişikliği kapalı (`GameState.in_combat`, GDD: slot değişimi yalnızca oda dışında).
- `DungeonRun` (ana sahne): 4 katın placeholder renk paletleri, boss sonrası tam can + merdivenle alt kata iniş,
  4. katta "KAZANDIN!", çatlak duvarı kırılarak bulunan gizli oda, F ile sandık/tüccar/demirci (yer tutucu), minimap,
  duvar arkası siluet, boss can barı, seed göstergesi.
- `DungeonNav`: düşmanlar ve test botu engellerin etrafından dolaşır.
- `make dungeon`: ölümsüz bot sabit seed'le 4 katı baştan sona yürür (her oda, gizli oda, boss'lar, merdivenler).
- Hata ayıklama menüsü (M) zindanda da açılır: kat seçimi + "Bu kattan yeni harita", "Test odasına git", "Ölümsüz (test)".
Kullanıcı onaylayınca Aşama 5'e (loot ve envanter) geçilecek.

**Aşama 4'te GDD'de olmayan ayrıntılar için verilen kararlar** (hepsi `data/dungeon.json` ve `data/floors.json` içinde;
ayrıntılı liste GDD > Uygulamada Verilen Kararlar > Zindan (Aşama 4)):
- Run Süresi tablosundaki oda sayısı (boss dahil) giriş odasını ve gizli odayı saymaz; bu ikisi ektir. Savaş odası en az 3.
- Ana yol oda sayısının %60'ı; boss ana yolun sonunda, tek kapılı. Tüccar/demirci/sandık önce çıkmaz odalara, elit en az 2 oda derine.
- Katın düşman sayısı (60/70/80/90) savaş odalarına bölünür, oda başına 2-4 dalga (dalga başına ≤ 8); kat başına 2 elit.
- Aşama 7'ye kadar tüm katlarda 1. kat düşman modelleri + malzeme varyantları (2. kat Alevli, 3. kat Taş/Alevli,
  4. kat Hayalet); yer tutucu elit (×3 can) ve katın boss adını taşıyan yer tutucu boss (×6 can, dev Damar Kütlesi).
- Gizli oda 0-1 (GDD aralığı); çatlak duvar 3 vuruşta kırılır; içinde sandık.
- Kilitli odanın dışına düşen oyuncu/düşman içeri geri alınır (güvenlik ağı).

Aşama 0-3'te verilen kararlar da GDD > Uygulamada Verilen Kararlar bölümündedir.

**Bilinen durumlar / notlar:**
- Aşama 6'ya kadar level atlanmaz ve düşmanlar katla güçlenmez; level 1'de 60 düşmanlı 1. kat zordur. Test için M menüsünden
  level seçilebilir ya da "Ölümsüz (test)" açılabilir.
- `bpy` (Blender Python) çalışma ortamının paket deposunda bulunamadı. Aşama 8'e kadar gerekmiyor; o aşamada tekrar denenecek ya da başka yol bulunacak.
- .exe imzasız olduğu için Windows SmartScreen "Windows bilgisayarınızı korudu" uyarısı gösterebilir: **Ek bilgi → Yine de çalıştır**.
- Ghost iksir kullanamaz (Aşama 3'te onaylandı; `data/races.json` > ghost > healing > potions).
- Hata ayıklama menüsü ve test odası geçicidir; Aşama 10'da gerçek menüler gelir.

## Oyunu çalıştırma (Windows)

1. `zindan-oyunu-windows-vX.Y.Z.zip` dosyasını bir klasöre çıkar.
2. `ZindanOyunu.exe`'ye çift tıkla.
3. Hata olursa log dosyası: `%APPDATA%\Godot\app_userdata\Zindan Oyunu\logs\godot.log`

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
| F | Etkileşim: sandık, tüccar, demirci, merdiven |
| M | Hata ayıklama menüsü: ırk, level, silahlar; zindanda kat/yeni harita/ölümsüz, test odası ↔ zindan |
| R | Zindan: ölünce ya da kazanınca yeni run · Test odası: odayı yeniden başlat |
| 2-7 / 0 | (Test odası) Aktif silahın elementi: Ateş, Su, Yıldırım, Zehir, Buz, Karanlık / elementsiz |
| 8 | (Test odası) Aktif silahın özelliğini değiştir (Öfke, İnfaz, Can Emme, Sekme, Sersemletme) |
| N | (Test odası) Yeni dalga / kuklaları yenile |
| Esc | (Prototip) Çık |

## Geliştirme

Gerekenler: Godot 4.7.2 (headless çalışır), aynı sürümün export şablonları, `make`, `zip`, Python 3.

```bash
make test            # birim testleri + test odası smoke + ırk×silah matrisi + zindan smoke (make unit / smoke / matrix / dungeon ayrı da çalışır)
make export-windows  # build/ içine ZindanOyunu.exe üretir ve zip'ler
make sprites         # sprite'ları üretir (Aşama 8)
make sfx             # ses efektlerini üretir (Aşama 9)
make all             # hepsi
```

Godot başka bir yerdeyse: `make test GODOT=/yol/godot`.

Geliştirme bayrakları (oyunu `godot --path . -- <bayrak>` ile çalıştırırken; test odası için `godot --path . res://scenes/test_room.tscn -- <bayrak>`):
- Zindan: `--seed=N` (aynı seed aynı haritalar) · `--floor=N` (N. kattan başla) · `--god` (hasar alınmaz) ·
  `--enemy-mult=0.2` (düşman sayısı çarpanı) · `--reveal` (minimapin tamamı) · `--open-menu` · `--autoplay` (bot 4 katı oynar)
- Bir katın haritasını ASCII basmak: `godot --headless --path . -s tools/dev/print_dungeon.gd -- --floor=2 --seed=42`
- `--autoplay` — test odasında oyuncuyu bot oynatır (smoke testi bunu kullanır; hiç kombo yapamazsa test düşer)
- `--race=ghost --level=20 --weapons=scythe:water,dagger:lightning:fury` — ırk, level ve iki silah (tip:element[:özellik])
- `--dummies` — dalgalar yerine saldırmayan kuklalar · `--open-menu` — hata ayıklama menüsü açık başlar
- `--matrix` — 4 ırk × 12 silah tipini sırayla otomatik dener (make matrix bunu kullanır)
- `--loadout=water,lightning` — (Aşama 2 uyumu) iki kılıcın elementi
- `--shots=KLASÖR --shot-times=0.5,2,3` — verilen saniyelerde ekran görüntüsü kaydeder

## Klasör yapısı

```
project.godot          proje ayarları (1920×1080, canvas_items, input map, autoload'lar)
export_presets.cfg     Windows Desktop ön ayarı
data/                  tüm denge sayıları (JSON) — koda sayı yazılmaz
scripts/autoload/      Events, DataDB, GameState, SaveManager
scripts/...            combat, player, enemies, bosses, dungeon, loot, progression
scenes/                sahneler
assets/                sprite, normal map, ses, font, shader
tools/                 Blender sprite üretici, ses sentezleyici
tests/                 headless birim testleri (run_tests.gd çalıştırıcı)
docs/GDD.md            tasarım dokümanı
```

### Veri dosyaları

Yeni silah, düşman ya da ödül eklemek için ilgili JSON'a bir kayıt eklemek yeterli. `DataDB` oyun açılırken tüm dosyaları okur;
eksik alan, yanlış tip, bozuk JSON, bilinmeyen id ya da toplamı 1 olmayan olasılık varsa hangi dosyada ve hangi alanda olduğunu
söyleyen bir hata verir (oyun ekranında da kırmızıyla görünür). `_` ile başlayan anahtarlar not/açıklama sayılır.

## Git akışı

Her aşama kendi branch'inde yapılır (`asama-0`, `asama-1`, …), bitince bir Pull Request ile `main`'e birleştirilir (merge).
