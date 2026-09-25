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
| 5 | Loot ve envanter | ✅ Bitti (onaylandı) |
| 6 | İlerleme | ✅ Bitti (main'e birleştirildi) |
| 7 | Düşmanlar ve boss'lar | — |
| 8 | Sanat | — |
| 9 | Ses | — |
| 10 | Menüler, denge ve teslim | — |

**Kalınan yer:** Aşama 6 (sürüm 0.6.0) bitti; `asama-6` (ve altındaki `asama-5`) GitHub'a push edildi ve `main`'e birleştirildi.
Sırada Aşama 7 (düşmanlar ve boss'lar): `main`'den `asama-7` dalı açılır.

**Aşama 6'da yapılanlar (ilerleme):**
- Oyuncu XP'si ve leveli (`Leveling`, `GameState.add_xp`): sonraki levele 100 + 20 × level, maks 80. Düşmanlar kat ve türe göre XP verir
  (normal 40/120/180/280, elit 150/500/900/1800, boss 800/2400/3600/7200). Üretilen haritalarda katın tüm düşmanları kesilirse oyuncu tam
  15 / 35 / 55 / 80'de çıkar (testte 4 seed'le doğrulandı). Level atlayınca can, mana ve statlar yenilenir, silahlar da aynı XP'yi alır
  (yetişme ×1,5), kilidi açılan silahlar bildirilir.
- **Aşama 5'teki GEÇİCİ "kata inince level alt sınıra çıkar" kuralı kaldırıldı** (`economy.interim_floor_min_level` silindi).
- Level ödülü: her 5 levelde (run başına 16) level havuzundan 2 seçenek (`Rewards`, `RewardUI`: tıkla ya da 1/2). Boss ödülü: 1 büyük stat +
  1 özel etki (özel etkiler run başına bir kez). Tavana ulaşan stat havuzdan çıkar. Ödül ekranı savaşı bölmez, oda temizlenince açılır.
- 15 stat ödülünün hepsi ve 11 özel etkinin hepsi oyunda çalışır (Çift vuruş, Ek mermi/kılıç dalgası, Delici, Element izi, Kombo ustası,
  Kritik zinciri, Rezonans güçlendirme, Hiddet, Cellat, Yedek iksir, İkinci şans).
- Silah tipi ustalığı (`Mastery`, kalıcı): run sonunda 100 XP × derinlik çarpanı (1. kat ölüm ×0,1 … zafer ×3,0), hasar payına göre silah
  tiplerine bölünür; 12 levellik eğri 114 referans maç. Bonuslar: hasar (formüldeki U), saldırı hızı, menzil, element.
- Boss ilk kesişi: kalıcı +%0,3 hasar, boss kesildiği anda kaydedilir.
- Run sonu özet ekranı (`RunSummary`): kat, level, süre, öldürme, altın, alınan ödüller, silah tiplerine göre hasar payı ve ustalık XP'si,
  ilk kesişler. Ustalık kaydedilir ve dosyadan geri okunarak doğrulanır.
- `SaveManager`: bozuk dosyada yedek alıp temiz başlar; tek tek bozuk girdileri atlar (yanlış tip, aralık dışı level, tekrar eden boss).
- Stat tavanları tüm kaynakların toplamına uygulanır (ırk, matris, ödüller, ustalık, efsanevi pasif): saldırı hızı +%150, menzil +%50,
  kritik %60, hasar azaltma %75, bekleme azaltma %40.
- HUD: XP barı, alınan ödüller satırı, "ödül bekliyor" uyarısı. Tooltip'te silah tipinin ustalık leveli ve bonusları; statlar ödül ve
  ustalık dahil.
- Hata ayıklama menüsünde yeni "İlerleme (test)" satırı: +1 / +5 level (XP ile), boss ödülü aç, ustalıkları sıfırla.

**Kullanıcının Aşama 6'da istediği değişiklikler:**
- Geçici "kata inince level alt sınıra çıkar" kuralı kaldırıldı.
- Warrior'ın Q yeteneği **Zırh** yerine **Kalkan Hücumu**: farenin yönünde 4 karo atılır (dokunulmaz), yolundaki düşmanlara aktif silahın
  ×1,5'i kadar güçlü vuruş, itme ve 0,6 sn sersemletme (boss'ta 1 sn %30 yavaşlatma); bedeli 40 enerji.
- İksir düşme oranı azaltıldı: normal düşman %1,5 → %1, elit %25 → %10 (kat başına ortalama ~0,8 iksir; tüccar aynı).

**Aşama 6'da GDD'de olmayan ayrıntılar için verilen kararlar** (hepsi `data/rewards.json` ve `data/progression.json` içinde `_default`
notuyla; ayrıntılı liste GDD > Uygulamada Verilen Kararlar > İlerleme):
- Ustalık level 1'den başlar ve level 1 de bonus verir (+%5 hasar, +%3,33 hız, +%1,67 menzil, +%2,5 element) — GDD tablosu level × bonus
  (level 6 = +%30, 12 = +%60) olduğu için. İstenirse level 1 bonussuz yapılabilir (o zaman level 12 = +%55 olur).
- Level ödülü ekranı savaş bitince açılır (level hemen atlanır). 4. kat boss'unda boss ödülü sunulmaz (run zaten biter).
- Space bekleme süresi azaltmaya tavan eklendi: ödüller + Rüzgâr Tüyü toplamı en fazla %50.
- "2. katı bitirme" (×1,0): 2. kat boss'u kesilip 3. kata inilmeden ölüm. Hata ayıklama menüsünden yeni harita açmak ya da oyunu kapatmak
  run'ı işlemez (ustalık yalnızca ölüm/zaferde).
- Ghost'a "Yedek iksir" sunulmaz; Ghost'ta can emme ödülü öldürme başına aynı yüzde kadar iyileşmeye dönüşür.
- Özel etki ayrıntıları: Ek mermi yakın silahta 4 karo giden kılıç dalgası, uzak silahta 8° kaymış küçük mermi; Delici patlayan küre ve
  saplanan mızrağı değiştirmez; Element izi 3 parça, 3 sn, 0,5 sn arayla %15; Cellat yalnızca İnfaz işlerken; İkinci şans 1,5 sn dokunulmazlık.

**Aşama 5 (loot ve envanter, onaylandı) özeti:**
- `LootGenerator`: katın nadirlik tablosu, gizli oda üst nadirlik ×2, efsanevi 3. kattan, 12 tip, element ve özellik sayısı nadirliğe göre,
  kat silah leveli (1 / 10 / 25-40 / 50). 10.000 düşüşlük testte oranlar ±%1.
- Düşmeler (kullanıcı kararı): düşmanlar (elit dahil) silah düşürmez, altın düşürür (yaklaşınca toplanır; nadiren iksir: Aşama 6'dan beri normal %1, elit %10). Boss kesilince
  1 silah düşer, nadirliği katın normal oranlarıyla. Silah ayrıca sandık, gizli oda ve tüccardan gelir; sandıkta tılsım da çıkabilir.
  Silah F ile alınır; nadirliğe göre ışık sütunu. Sandıklar %25 tuzaklı (kırmızı işaret, 1 sn sonra patlar).
- `Inventory` + `InventoryUI` (I): envanterin tamamı 4 slot (Aktif 1, Aktif 2, Rezonans, Esnek), çanta yok (kullanıcı kararı). Yer yoksa F
  yerdekiyle değiştirir, eski eşya yere düşer. Sürükle-bırak, sağ tık/çift tık (aktif ↔ Rezonans), yere bırakma, stat karşılaştırmalı
  tooltip. Kilitli silah aktif slota konamaz; savaşta slotlar kilitli ve eşya alınamaz.
- Silah leveli ve yetişme XP'si (1,5 kat, oyuncuyu geçemez; yalnızca slottakiler, kilitliler almaz).
- `ItemEffects`: Rezonans ek hasarı (%10 kilitli / %7 açık), Esnek slot (özellik ve efsanevi pasif %9, tılsım tam), 3 tılsım,
  12 efsanevi silahın pasifleri ve sağ tık ekleri.
- Tüccar (F): 3 silah + 1 tılsım + iksir satar, eşya alır (%30). Demirci (F): level atlatma, element/özellik yeniden çekme.
- Run ırkın kendi ailesinden Yaygın bir silahla başlar (Warrior kılıç, Ghost hançer, Archer yay, Magical asa).
- Aşama 5 kararları: düşme oranları, altın miktarları (× kat çarpanı 1-4), tüccar fiyatları, demirci bedelleri, tuzak %25; 4. katta gizli
  oda ×2 için Yaygın yetmediğinden kalan Ender'den düşülür; silah XP eğrisi oyuncununkiyle aynı; Rezonans ek hasarı element durumu
  bırakmaz ve kombo yapmaz; 12 efsanevi silah önerildi (kullanıcı değiştirebilir).

Aşama 0-6'da verilen kararların tamamı GDD > Uygulamada Verilen Kararlar bölümündedir.

**Bilinen durumlar / notlar:**
- Düşmanlar Aşama 7'ye kadar katla güçlenmez ve tüm katlarda 1. kat modelleri (yer tutucu elit/boss) kullanılır; artık level XP ile
  arttığı için 2-4. katlar görece kolaylaşır. Denge Aşama 7 ve 10'da.
- Ustalık ve boss ilk kesişleri `%APPDATA%\Godot\app_userdata\Zindan Oyunu\save.json` dosyasına kaydedilir. Sıfırlamak için M menüsü →
  "Ustalıkları sıfırla". Testler ve bot (autoplay) ayrı dosya kullanır, oyuncunun kaydına dokunmaz.
- Test için M menüsünden level seçilebilir (XP'siz, ödül vermez) ya da "+1/+5 level (XP)" ile gerçek XP verilir; "Ölümsüz (test)" açılabilir.
  "Loot (test)" satırı loot yağdırır, altın ve silah XP'si verir.
- Hata ayıklama menüsünden level düşürülürse aktif slottaki yüksek levelli silah kullanılmaya devam eder (yalnızca test durumu).
- `bpy` (Blender Python) çalışma ortamının paket deposunda bulunamadı. Aşama 8'e kadar gerekmiyor; o aşamada tekrar denenecek ya da başka yol bulunacak.
- .exe imzasız olduğu için Windows SmartScreen "Windows bilgisayarınızı korudu" uyarısı gösterebilir: **Ek bilgi → Yine de çalıştır**.
- Ghost iksir kullanamaz (Aşama 3'te onaylandı); iksir toplamaz, tüccar ona iksir satmaz, Yedek iksir ödülü sunulmaz.
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
| 1 / 2 (ödül ekranında) | Level ya da boss ödülünden birini seç (kartlara tıklamak da olur; açıkken oyun durur) |
| M | Hata ayıklama menüsü: ırk, level, silahlar; zindanda kat/yeni harita/ölümsüz, loot testi, ilerleme testi (+level, boss ödülü, ustalık sıfırla), test odası ↔ zindan |
| R | Zindan: ölünce ya da kazanınca (özet ekranında) yeni run · Test odası: odayı yeniden başlat |
| 2-7 / 0 | (Test odası) Aktif silahın elementi: Ateş, Su, Yıldırım, Zehir, Buz, Karanlık / elementsiz |
| 8 | (Test odası) Aktif silahın özelliğini değiştir (Öfke, İnfaz, Can Emme, Sekme, Sersemletme) |
| N | (Test odası) Yeni dalga / kuklaları yenile |
| Esc | (Prototip) Çık |

## Geliştirme

Aşama 6'dan itibaren geliştirme Claude Code ile bu klasörde yapılıyor; kurallar [`CLAUDE.md`](CLAUDE.md) dosyasında.

Gerekenler: Godot 4.7.2 (headless çalışır), aynı sürümün export şablonları, `make`, Python 3. `zip` yoksa `make export-windows`
PowerShell'in `Compress-Archive`'ini kullanır. Bu bilgisayarda Godot `C:\Users\mcap5\Godot\` klasöründe
(`Godot_v4.7.2-stable_win64_console.exe` komut satırı için), şablonlar `%APPDATA%\Godot\export_templates\4.7.2.stable\` içinde.

```bash
make test            # birim testleri (193) + test odası smoke + ırk×silah matrisi + zindan smoke (loot, tüccar, demirci, ödüller, ustalık kaydı dahil) (make unit / smoke / matrix / dungeon ayrı da çalışır)
make export-windows  # build/ içine ZindanOyunu.exe üretir ve zip'ler
make sprites         # sprite'ları üretir (Aşama 8)
make sfx             # ses efektlerini üretir (Aşama 9)
make all             # hepsi
```

Godot başka bir yerdeyse: `make test GODOT=/yol/godot` (bu bilgisayarda: `make test GODOT=/c/Users/mcap5/Godot/Godot_v4.7.2-stable_win64_console.exe`).

Geliştirme bayrakları (oyunu `godot --path . -- <bayrak>` ile çalıştırırken; test odası için `godot --path . res://scenes/test_room.tscn -- <bayrak>`):
- Zindan: `--seed=N` (aynı seed aynı haritalar) · `--floor=N` (N. kattan başla) · `--god` (hasar alınmaz) ·
  `--enemy-mult=0.2` (düşman sayısı çarpanı) · `--reveal` (minimapin tamamı) · `--open-menu` · `--autoplay` (bot 4 katı oynar)
- Loot/arayüz: `--loot-rain` (çevreye loot saçar) · `--fill-bag` (boş slotları doldurur) · `--open-bag` (envanteri açar) · `--open-ui=merchant` / `blacksmith`
- İlerleme: `--grant-levels=N` (run başında N level'lik XP; ödül ekranı açılır) · `--end-run=SN` (SN saniye sonra oyuncu ölür; özet ekranı).
  `--autoplay` kalıcı kaydı `user://save_autoplay.json`'a yazar (her seferinde sıfırdan)
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
scripts/...            combat, player, enemies, bosses, dungeon, loot, progression (Leveling, Mastery, Rewards, RunBonuses), ui
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
Claude aşama sonunda yalnızca yerelde commit eder; kullanıcı uygulamayı test edip onaylayınca push eder (kullanıcının git hesabıyla),
GitHub'a ulaştığını kontrol eder ve `main`'e birleştirir. Yapamazsa kullanıcıya Git Bash komutlarını verir (`git push -u origin asama-N`).
