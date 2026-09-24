# Zindan Oyunu

2D izometrik, öl-baştan-başla (roguelike) bir zindan oyunu. Godot 4 ile yapılıyor; hedef platform Windows.
Tasarımın tamamı [`docs/GDD.md`](docs/GDD.md) içinde; oyun oradaki **Uygulama Rehberi**'ni adım adım takip ederek yapılıyor.

## Durum

| Aşama | Konu | Durum |
| --- | --- | --- |
| 0 | Ortam ve iskelet | ✅ Bitti |
| 1 | Vuruş hissi prototipi | ✅ Bitti (vuruş hissi onaylandı) |
| 2 | Savaş çekirdeği | ✅ Bitti (kombolar onaylandı) |
| 3 | Irklar ve silahlar | 🧪 Kullanıcı testinde |
| 4 | Zindan üretimi | — |
| 5 | Loot ve envanter | — |
| 6 | İlerleme | — |
| 7 | Düşmanlar ve boss'lar | — |
| 8 | Sanat | — |
| 9 | Ses | — |
| 10 | Menüler, denge ve teslim | — |

**Kalınan yer:** Aşama 3 kodlandı: 4 ırk (`RaceStats` statlar + ırk-silah matrisi, `RaceKit` Enerji/Mana/bekleme süreleri,
`RaceAbilities` Q/E yetenekleri, Ghost'un iyileşme kuralı), 12 silah tipinin sol ve sağ tık saldırıları (`WeaponAttacks`,
`Projectile`, `GroundEffect`), iki aktif silah + Tab (statlar aktif silahın ailesine göre yenilenir), Magical dışı ırkta büyü
silahı sağ tık beklemesi ×1,5 ve **M** ile açılan hata ayıklama menüsü (ırk, level, iki silahın tipi/elementi/özelliği,
dalga ya da kukla). `make matrix` 48 ırk × silah kombinasyonunun hepsini otomatik dener. Kullanıcı onaylayınca Aşama 4'e
(zindan üretimi) geçilecek.

**Aşama 3'te GDD'de olmayan ayrıntılar için verilen kararlar** (hepsi `data/races.json` ve `data/weapon_types.json` içinde,
`_default` notuyla işaretli; oyun testinde ayarlanır):
- Irk pasifleri: Archer +%10 saldırı menzili ve +%5 kritik şansı; Magical +%15 element hasarı (her silahta).
- Warrior Q Zırh: 3 sn, +%20 hasar azaltma ve +%3 hasar. E Yer sarsıntısı: önde 3 karo, 100° yay, aktif silahın ×2,5'i.
- Ghost Q Faz: 1 sn; saldırınca erken biter, düşmanların içinden geçilir. E Gölge adımı: farenin en yakınındaki düşmanın
  (7 karo içinde) arkasına ışınlanır; hedef yoksa bekleme başlamaz.
- Archer Q Geri sıçrama: 3 karo geri, öne 24°'lik yelpazede 3 ok (×0,8). E Ok yağmuru: farenin gösterdiği yerde 2,2 karo
  alana 6 dalga ok (her biri ×0,45).
- Magical Q Uçuş: 2,5 sn, sütun/engellerin üstünden geçer (dış duvarlardan geçemez), +%20 hız; engelin üstünde biterse
  engelden çıkana kadar uçmaya devam eder. E Element fırtınası: farenin gösterdiği yerde 2,6 karo alana 5 vuruş (×0,7).
- Yetenek hasarları aktif silahın vuruşunun katıdır ve onun elementini taşır (Q/E ile de kombo yapılır).
- Warrior enerjisi isabet eden **her saldırı** başına bir kez +2 (vurulan düşman sayısından bağımsız). Sağ tık 5-7 sn → 6 sn.
- Magical her silahta mana harcar (sol tık 2, sağ tık 70). Magical dışı ırk büyü silahında sol tık bedava, sağ tık = ırkın
  sağ tık beklemesi × 1,5 (Warrior 9 sn, Ghost 7,5 sn, Archer 9 sn).
- İki farklı ailede silah taşınınca ırk-silah matrisi **aktif silaha** göre işler; Tab'la geçince maks can değişir, can
  oranı korunur.
- Ghost'ta Can Emme özelliği aktif silahtaysa öldürme başına ek %3 iyileşme verir.
- Silahların sağ tık ayrıntıları (menzil, hız, çarpan): Balta fırlatma 5 karo gidip döner (gidişte ve dönüşte vurur,
  ×1,4) · Seri yumruk 5 × ×0,55, sonuncusu 0,8 sn sersemletir · Hasat 220° yay, ×1,4, arkadan +%20 · Saplama: farenin
  yakınındaki düşmanın arkasına atılıp ×2,2 · Yere vuruş 2,2 karo alan ×1,5 ve 2 sn %40 yavaşlatma · Güçlü atış 1,2 sn'de
  ×1'den ×3'e dolar, deler · Saçma 40°'lik yelpaze, 5 × ×0,7 · Mızrak 8 karo, deler, saplanır; tekrar sağ tık ya da 6 sn
  sonra geri döner; havadayken dürtme yok, bekleme dönünce başlar · Güdümlü sayfalar 4 × ×0,6 · Element küresi ×2,0,
  2 karo patlama · Rün tuzağı ×2,5, 5 karoya kurulur, 0,5 sn'de kurulur, aynı anda tek tuzak.
- Rün'ün sol tıkı: farenin gösterdiği yerde (menzil içinde) 0,3 sn sonra patlayan küçük rün (1,1 karo).
- İksir (1 tuşu) test için şimdiden çalışıyor: 2 iksir, maks canın %40'ı. Tüccar ve iksir düşmesi Aşama 5'te.

**Bilinen durumlar / notlar:**
- `bpy` (Blender Python) çalışma ortamının paket deposunda bulunamadı. Aşama 8'e kadar gerekmiyor; o aşamada tekrar denenecek ya da başka yol bulunacak.
- .exe imzasız olduğu için Windows SmartScreen "Windows bilgisayarınızı korudu" uyarısı gösterebilir: **Ek bilgi → Yine de çalıştır**.
- **Açık karar:** "Ghost iksir kullanamaz" kuralı GDD'deki gibi uygulandı ama GDD'de hâlâ onay bekliyor
  (`data/races.json` > ghost > healing > potions ile açılıp kapanır).
- Hata ayıklama menüsü ve test odası geçicidir; Aşama 4'te gerçek zindan, Aşama 10'da gerçek menüler gelir.

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
| F | Etkileşim |
| M | (Test odası) Hata ayıklama menüsü: ırk, level, silahlar, düşmanlar |
| R | (Prototip) Odayı yeniden başlat |
| 2-7 / 0 | (Test odası) Aktif silahın elementi: Ateş, Su, Yıldırım, Zehir, Buz, Karanlık / elementsiz |
| 8 | (Test odası) Aktif silahın özelliğini değiştir (Öfke, İnfaz, Can Emme, Sekme, Sersemletme) |
| N | (Test odası) Yeni dalga / kuklaları yenile |
| Esc | (Prototip) Çık |

## Geliştirme

Gerekenler: Godot 4.7.2 (headless çalışır), aynı sürümün export şablonları, `make`, `zip`, Python 3.

```bash
make test            # birim testleri + smoke testi + ırk×silah matrisi (make unit / make smoke / make matrix ayrı da çalışır)
make export-windows  # build/ içine ZindanOyunu.exe üretir ve zip'ler
make sprites         # sprite'ları üretir (Aşama 8)
make sfx             # ses efektlerini üretir (Aşama 9)
make all             # hepsi
```

Godot başka bir yerdeyse: `make test GODOT=/yol/godot`.

Geliştirme bayrakları (oyunu `godot --path . -- <bayrak>` ile çalıştırırken):
- `--autoplay` — oyuncuyu bot oynatır (smoke testi bunu kullanır; hiç kombo yapamazsa test düşer)
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
