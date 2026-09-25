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
| 4 | Zindan üretimi | ✅ Bitti (onaylandı) |
| 5 | Loot ve envanter | 🧪 Kullanıcı testinde |
| 6 | İlerleme | — |
| 7 | Düşmanlar ve boss'lar | — |
| 8 | Sanat | — |
| 9 | Ses | — |
| 10 | Menüler, denge ve teslim | — |

**Kalınan yer:** Aşama 5 (sürüm 0.5.0) kodlandı; `asama-5` dalı `asama-4`'ün üstünde. Kullanıcı onaylayınca Aşama 6'ya (ilerleme)
geçilecek.
- `LootGenerator`: katın nadirlik tablosu, gizli oda üst nadirlik ×2, efsanevi 3. kattan,
  12 tip, element ve özellik sayısı nadirliğe göre, kat silah leveli (1 / 10 / 25-40 / 50). 10.000 düşüşlük testte oranlar ±%1.
- Düşmeler (kullanıcı kararı): düşmanlar (elit dahil) silah düşürmez, altın düşürür (yaklaşınca toplanır; nadiren iksir).
  Boss kesilince 1 silah düşer, nadirliği katın normal oranlarıyla (ör. 3. katta efsanevi %5). Silah ayrıca sandık, gizli oda
  ve tüccardan gelir; sandıkta tılsım da çıkabilir. Silah F ile alınır; nadirliğe göre ışık sütunu.
  Sandıklar %25 tuzaklı (kırmızı işaret, 1 sn sonra patlar).
- `Inventory` + `InventoryUI` (I): envanterin tamamı 4 slot (Aktif 1, Aktif 2, Rezonans, Esnek), çanta yok. Yer yoksa F yerdekiyle
  değiştirir, eski eşya yere düşer. Sürükle-bırak, sağ tık/çift tık (aktif ↔ Rezonans), yere bırakma, stat karşılaştırmalı
  tooltip. Kilitli silah aktif slota konamaz; savaşta slotlar kilitli ve eşya alınamaz.
- Silah leveli ve yetişme XP'si (1,5 kat, oyuncuyu geçemez; yalnızca slottakiler, kilitliler almaz). XP Aşama 6'da gelir; şimdilik
  menüden "Silahlara +1000 XP".
- `ItemEffects`: Rezonans ek hasarı (%10 kilitli / %7 açık), Esnek slot (özellik ve efsanevi pasif %9, tılsım tam), 3 tılsım,
  12 efsanevi silahın pasifleri ve sağ tık ekleri.
- Tüccar (F): 3 silah + 1 tılsım + iksir satar, eşya alır (%30). Demirci (F): level atlatma, element/özellik yeniden çekme.
- Run ırkın kendi ailesinden Yaygın bir silahla başlar.

**Kullanıcının Aşama 5'te istediği değişiklikler:**
- Envanterin tamamı 4 slot, çanta yok: yeni eşya için yer yoksa bir eşya geride bırakılır.
- Düşmanlardan silah düşmez, yalnızca altın; boss 1 silah düşürür ve bu silah
  garanti iyi değildir (katın normal nadirlik oranları). "3-4. kat boss'u en az Destansı" ve "elit üst nadirlik ×2" kaldırıldı.

**Aşama 5'te GDD'de olmayan ayrıntılar için verilen kararlar** (hepsi `data/economy.json` ve `data/legendaries.json` içinde;
ayrıntılı liste GDD > Uygulamada Verilen Kararlar > Loot ve envanter):
- Düşme oranları, altın miktarları (× kat çarpanı 1-4), tüccar fiyatları, demirci bedelleri, tuzak %25.
- 4. katta gizli oda ×2 için Yaygın yetmediğinden kalan Ender'den düşülür.
- Başlangıç silahı: Warrior kılıç, Ghost hançer, Archer yay, Magical asa (Yaygın, level 1).
- Silah XP eğrisi oyuncununkiyle aynı; XP'yi yalnızca 4 slottaki açık silahlar alır.
- Rezonans ek hasarı element durumu bırakmaz ve kombo yapmaz (ikincil vuruş).
- 12 efsanevi silah önerildi (her tipten bir; ad, element, pasif, sağ tık eki) — kullanıcı değiştirebilir.
- **GEÇİCİ:** Aşama 6'ya kadar kata inince level katın alt sınırına çıkar (15 / 35 / 55); Aşama 6'da kalkar.

Aşama 0-4'te verilen kararlar da GDD > Uygulamada Verilen Kararlar bölümündedir.

**Bilinen durumlar / notlar:**
- Aşama 6'ya kadar XP ile level atlanmaz ve düşmanlar katla güçlenmez; 1. kat level 1'de zordur. Test için M menüsünden level seçilebilir
  ya da "Ölümsüz (test)" açılabilir. Menüdeki "Loot (test)" satırı loot yağdırır, altın ve silah XP'si verir.
- Hata ayıklama menüsünden level düşürülürse aktif slottaki yüksek levelli silah kullanılmaya devam eder (yalnızca test durumu).
- `bpy` (Blender Python) çalışma ortamının paket deposunda bulunamadı. Aşama 8'e kadar gerekmiyor; o aşamada tekrar denenecek ya da başka yol bulunacak.
- .exe imzasız olduğu için Windows SmartScreen "Windows bilgisayarınızı korudu" uyarısı gösterebilir: **Ek bilgi → Yine de çalıştır**.
- Ghost iksir kullanamaz (Aşama 3'te onaylandı); iksir toplamaz, tüccar ona iksir satmaz.
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
| F | Etkileşim: yerdeki silah/tılsım, sandık, tüccar, demirci, merdiven |
| I | Envanter: 4 slot (sürükle-bırak, sağ tık aktif ↔ Rezonans; açıkken oyun durur) |
| M | Hata ayıklama menüsü: ırk, level, silahlar; zindanda kat/yeni harita/ölümsüz, loot testi, test odası ↔ zindan |
| R | Zindan: ölünce ya da kazanınca yeni run · Test odası: odayı yeniden başlat |
| 2-7 / 0 | (Test odası) Aktif silahın elementi: Ateş, Su, Yıldırım, Zehir, Buz, Karanlık / elementsiz |
| 8 | (Test odası) Aktif silahın özelliğini değiştir (Öfke, İnfaz, Can Emme, Sekme, Sersemletme) |
| N | (Test odası) Yeni dalga / kuklaları yenile |
| Esc | (Prototip) Çık |

## Geliştirme

Aşama 6'dan itibaren geliştirme Claude Code ile bu klasörde yapılıyor; kurallar [`CLAUDE.md`](CLAUDE.md) dosyasında.

Gerekenler: Godot 4.7.2 (headless çalışır), aynı sürümün export şablonları, `make`, `zip`, Python 3.

```bash
make test            # birim testleri (166) + test odası smoke + ırk×silah matrisi + zindan smoke (loot, tüccar, demirci dahil) (make unit / smoke / matrix / dungeon ayrı da çalışır)
make export-windows  # build/ içine ZindanOyunu.exe üretir ve zip'ler
make sprites         # sprite'ları üretir (Aşama 8)
make sfx             # ses efektlerini üretir (Aşama 9)
make all             # hepsi
```

Godot başka bir yerdeyse: `make test GODOT=/yol/godot`.

Geliştirme bayrakları (oyunu `godot --path . -- <bayrak>` ile çalıştırırken; test odası için `godot --path . res://scenes/test_room.tscn -- <bayrak>`):
- Zindan: `--seed=N` (aynı seed aynı haritalar) · `--floor=N` (N. kattan başla) · `--god` (hasar alınmaz) ·
  `--enemy-mult=0.2` (düşman sayısı çarpanı) · `--reveal` (minimapin tamamı) · `--open-menu` · `--autoplay` (bot 4 katı oynar)
- Loot/arayüz: `--loot-rain` (çevreye loot saçar) · `--fill-bag` (boş slotları doldurur) · `--open-bag` (envanteri açar) · `--open-ui=merchant` / `blacksmith`
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
