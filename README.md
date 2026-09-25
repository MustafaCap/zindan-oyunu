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
| 7 | Düşmanlar ve boss'lar | ✅ Bitti (onaylandı, main'e birleştirildi) |
| 8 | Sanat | — |
| 9 | Ses | — |
| 10 | Menüler, denge ve teslim | — |

**Kalınan yer:** Aşama 7 (sürüm 0.7.0) bitti, onaylandı; `asama-7` GitHub'a push edildi ve `main`'e birleştirildi.
Sırada Aşama 8 (sanat): `main`'den `asama-8` dalı açılır.

**Test süresi (kullanıcı kararı):** geliştirme sırasında `make quick` (birim + smoke, ~1 dk); tam `make test` (~3,5 dk) aşama sonunda bir kez.

**Aşama 7'de yapılanlar (düşmanlar ve boss'lar):**
- **55 düşman:** 17 temel düşman (5 rol) + her birinin eliti + 21 malzeme varyantı (yeni **Zehirli** malzemesi; Taş, Alevli, Hayalet).
  Her kat artık kendi düşmanlarıyla gelir (prototip havuz ve yer tutucu elit/boss kaldırıldı). `EnemyMelee` → `Enemy` (veri odaklı:
  `enemies.json`'daki ai, attack, abilities, on_death, front_shield alanları).
- Rol yapay zekâları: takip, mesafe koruma (okçu, tükürücü, büyücü, feryatçı), duvara yapışık (Göz Yavrusu), destek (Şifacı, Çağırıcı:
  öncelikli hedef, başında sarı "!"). Saldırı tipleri: yay, mermi, ışın, yere vuruş, atılıp ısırma (Kor Köpeği), çığlık konisi. Her saldırının
  hazırlığında yerde kırmızı işaret dolar.
- Özel davranışlar: Damar Kütlesi ölünce işaretli patlar, Sporlu Böcek zehir bulutu, Tükürücü/Cüruf Büyücüsü yere birikinti/lav bırakır,
  Şifacı dostlarını iyileştirir, Demir Muhafız'ın kalkanı önden vuruşu engeller (arkasına geç; sersem/donmuşken iner), Gölge görünmezleşip
  arkandan saldırır, Feryatçı yavaşlatır, Boşluk Kulu seni kendine çeker, Boşluk Çağırıcı Gölge çağırır.
- **Elitler:** ×3 can, ×1,5 hasar, ×1,35 boy ve bir aura (Hız, Kalkan, Yenilenme, Öfke; renkli halkayla görünür).
- **Kat ölçeklemesi:** düşman canı ×1 / ×2,5 / ×5 / ×8, hasarı ×1 / ×1,9 / ×2,9 / ×4.
- **4 gerçek boss** (tüm saldırıları yerde önceden işaretli, %50'de 2. faz, HUD'da faz çizgisi ve mekanik ipucu):
  - Morvath: döner Bakış Işını (sütun arkası güvenli), Damar Kırbacı, Göz Yavruları; göz kapağı kapanınca duvardaki 3 gözü kır → 6 sn +%50.
  - Mycela: Spor Bulutu, Kök Patlaması, Spor Oku; 3 iyileştiren totem; ateş bulutu Zehir Patlaması'yla yakar; 2. fazda sporla dolan arena.
  - Kordrak: Örs Darbesi şok halkası, lav kanalları, Kor Yumruğu; plakalar %70 azaltır, 5 buz vuruşu plakaları 10 sn kırar.
  - Nyx'thar: Gölge Kopyaları (gerçeğin gölgesi var), Boşluk Yırtığı (çeker), Çığlık; karanlık arena, meşaleler (ateş yakar); 2. fazda kenarlar çöker.
- Çağrılanlar ve boss yardımcıları XP/altın/iksir vermez (kat XP toplamları değişmedi).
- Hata ayıklama: zindanda M → "Boss odasına ışınlan"; test odasında M → "Düşmanlar" listesinden her tür ya da eliti tek tek denenir.
- Testler: 13 yeni birim testi (toplam 206) ve yeni `make bosses` (bot 4 boss'u katın beklenen gücüyle 240 sn içinde keser; tüm saldırılar,
  2. faz ve ≥ 0,4 sn uyarı denetlenir).

**Aşama 7'de GDD'de olmayan ayrıntılar için verilen kararlar** (hepsi `data/enemies.json`, `data/bosses.json`, `data/floors.json` içinde
`_default` notuyla; ayrıntılı liste ve tüm sayılar GDD > Uygulamada Verilen Kararlar > Düşmanlar ve boss'lar):
- 55 = 17 temel + 17 elit + 21 varyant; varyantlar önceki katların düşmanlarının yeni katın malzemesiyle gelmesi (2. kat için yeni
  "Zehirli" malzemesi: zehre bağışık, ateşe zayıf).
- Düşman tablosunda yalnızca bağışıklık vardı; malzeme tablosuyla tutarlı zayıflıklar eklendi (taş → buz, ateş → buz/su, hayalet ve
  mantar → ateş). Bağışık olunan element zayıflıktan düşer.
- Tüm yeni düşmanların statları, saldırı süreleri, aura oranları (%30 / %1,5), sürü boyları (fare/böcek 3-5, köpek 2-4), dalgada en
  fazla 1 destek ve 2 Göz Yavrusu, sürü elitlerinin can çarpanı (fare ×9, böcek ×8, köpek ×6).
- Kat ölçeklemesi sayıları; boss can/hasarları (Morvath 9.000 / 26, Mycela 22.000 / 45, Kordrak 42.000 / 70, Nyx'thar 65.000 / 95) ve
  bütün boss saldırı/mekanik sayıları.
- Kalkan: yerden/gökten gelen alanlar, ikincil vuruşlar ve süreli hasar kalkandan geçer; sersem/donmuşken kalkan iner.
- Morvath: kapak 14 sn açık, 22 sn'de gözler kırılmazsa bonussuz açılır. Nyx'thar: en az 2 meşale hep yanar; sahte kopya vurulunca
  oyuncunun yanına ışınlanıp işaretli kesik atar ve dağılır. Mycela: totemler 30 sn sonra yeniden dikilir.
- Zindan smoke testinde düşman canı ×0,25 (`--enemy-hp`).

**Aşama 6 (ilerleme, onaylandı) özeti:**
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

Aşama 0-7'de verilen kararların tamamı GDD > Uygulamada Verilen Kararlar bölümündedir.

**Bilinen durumlar / notlar:**
- Denge (düşman ve boss sayıları, kat ölçeklemesi) ilk değerlerdir; Aşama 10'da simülasyon ve oyun testleriyle ayarlanır. Boss testi
  ölümsüz botla yapılır (bot saldırılardan kaçmaz); gerçek zorluk oynayarak değerlendirilmeli.
- Görseller hâlâ renkli şekiller (boss'lar büyük gövdeler, üstlerinde göz/çekirdek); sanat Aşama 8'de.
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
| M | Hata ayıklama menüsü: ırk, level, silahlar; zindanda kat/yeni harita/ölümsüz, loot testi, ilerleme testi (+level, boss ödülü, ustalık sıfırla, boss odasına ışınlan), test odası ↔ zindan; test odasında düşman türü (her tür ya da eliti) |
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
make quick           # geliştirirken hızlı kontrol: birim testleri + test odası smoke (~1 dk)
make test            # aşama sonunda bir kez: birim testleri (206) + test odası smoke + ırk×silah matrisi + zindan smoke + boss testi (make unit / smoke / matrix / dungeon / bosses ayrı da çalışır)
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
- Düşmanlar (Aşama 7): `--enemy-hp=X` (tüm düşmanların canı çarpanı) · `--boss-rush` (her katta boss odasının kapısında başla) ·
  `--boss-test` (boss-rush + katın beklenen level/silah gücü; boss'lar denetlenir, make bosses bunu kullanır)
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
scripts/...            combat, player, enemies (Enemy, EnemyHazard, EnemyProjectile), bosses (Boss, Morvath, Mycela, Kordrak, Nyxthar…), dungeon, loot, progression, ui
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
