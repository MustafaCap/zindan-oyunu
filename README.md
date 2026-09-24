# Zindan Oyunu

2D izometrik, öl-baştan-başla (roguelike) bir zindan oyunu. Godot 4 ile yapılıyor; hedef platform Windows.
Tasarımın tamamı [`docs/GDD.md`](docs/GDD.md) içinde; oyun oradaki **Uygulama Rehberi**'ni adım adım takip ederek yapılıyor.

## Durum

| Aşama | Konu | Durum |
| --- | --- | --- |
| 0 | Ortam ve iskelet | ✅ Bitti |
| 1 | Vuruş hissi prototipi | ✅ Bitti (vuruş hissi onaylandı) |
| 2 | Savaş çekirdeği | 🧪 Kullanıcı testinde |
| 3 | Irklar ve silahlar | — |
| 4 | Zindan üretimi | — |
| 5 | Loot ve envanter | — |
| 6 | İlerleme | — |
| 7 | Düşmanlar ve boss'lar | — |
| 8 | Sanat | — |
| 9 | Ses | — |
| 10 | Menüler, denge ve teslim | — |

**Kalınan yer:** Aşama 2 kodlandı: `DamageCalc` (hasar formülü), `StatusEffects` (6 element durumu), `Combos` (7 kombo),
`Traits` (5 özellik), `HitResolver` (hepsini vuruşta birleştirir), düşman üstünde bağışıklık/zayıflık ikonları. Test odasında
oyuncunun iki elementli kılıcı var (Tab ile geçiş) ve 1. kat düşmanları + Taş/Hayalet varyantları geliyor. Kullanıcı kombolarını
test edip onaylayınca Aşama 3'e (ırklar ve silahlar) geçilecek.

**Aşama 2'de GDD'de olmayan ayrıntılar için verilen kararlar** (hepsi `data/` içinde, `_default` notuyla işaretli; oyun testinde ayarlanır):
- Su'nun kendi hasarı ×0,8. Yıldırım zinciri 3 karo menzil. Buz yığını her buz vuruşunda 3 sn tazelenir.
- Arkadan vuruş: hedefin baktığı yönden 90°'den fazla açıyla gelen vuruş.
- Kombo sayıları: Elektroşok 6 karodaki ıslaklara %60 · Erime +%200 · Zehir Patlaması 2,5 karo, %80 · Buhar 2 karo, 4 sn %40 ıskalama · Çürüme 6 sn.
- Kombo ilk elementi tüketir (Çürüme'de de zehir tüketilir; sonraki zehir iki kat vurur). Bir vuruşta en fazla bir kombo.
- Sekme 3 karo menzil. Sersemletme boss'ta 1 sn %30 yavaşlatır.
- Zincir, sekme ve kombo alan hasarları "ikincil vuruş"tur: element bırakır ama yeni kombo/zincir/özellik tetiklemez.
- Fiziksel hasara element hasarı bonusları uygulanmaz.

**Bilinen durumlar / notlar:**
- `bpy` (Blender Python) çalışma ortamının paket deposunda bulunamadı. Aşama 8'e kadar gerekmiyor; o aşamada tekrar denenecek ya da başka yol bulunacak.
- .exe imzasız olduğu için Windows SmartScreen "Windows bilgisayarınızı korudu" uyarısı gösterebilir: **Ek bilgi → Yine de çalıştır**.

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
| 1 | İksir |
| F | Etkileşim |
| R | (Prototip) Odayı yeniden başlat |
| 2-7 / 0 | (Test odası) Aktif silahın elementi: Ateş, Su, Yıldırım, Zehir, Buz, Karanlık / elementsiz |
| 8 | (Test odası) Aktif silahın özelliğini değiştir (Öfke, İnfaz, Can Emme, Sekme, Sersemletme) |
| N | (Test odası) Yeni dalga |
| Esc | (Prototip) Çık |

## Geliştirme

Gerekenler: Godot 4.7.2 (headless çalışır), aynı sürümün export şablonları, `make`, `zip`, Python 3.

```bash
make test            # birim testleri + otomatik oynayan smoke testi (make unit / make smoke ayrı ayrı da çalışır)
make export-windows  # build/ içine ZindanOyunu.exe üretir ve zip'ler
make sprites         # sprite'ları üretir (Aşama 8)
make sfx             # ses efektlerini üretir (Aşama 9)
make all             # hepsi
```

Godot başka bir yerdeyse: `make test GODOT=/yol/godot`.

Geliştirme bayrakları (oyunu `godot --path . -- <bayrak>` ile çalıştırırken):
- `--autoplay` — oyuncuyu bot oynatır (smoke testi bunu kullanır; hiç kombo yapamazsa test düşer)
- `--loadout=water,lightning` — test odasındaki iki silahın elementi
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
