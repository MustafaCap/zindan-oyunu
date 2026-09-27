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
| 8 | Sanat | ✅ Bitti (onaylandı, main'e birleştirildi) |
| 9 | Ses | ✅ Bitti (onaylandı, main'e birleştirildi) |
| 10 | Menüler, denge ve teslim | 🔶 Yapıldı, kullanıcı testi bekleniyor (yerelde commit; push ve `v0.1` etiketi onaydan sonra) |

**Kalınan yer:** Aşama 10 (sürüm 0.10.0) `main`'den açılan `asama-10` dalında yapıldı ve **yalnızca yerelde commit edildi**
(derleme: `ZindanOyunu-Derlemeler\asama-10\`). Kullanıcı oyunu baştan sona oynayıp onaylayınca: push, `main`'e birleştirme ve GitHub'da
`v0.1` sürüm etiketi. Ana menü videosu eklendi (`make menu-video`; giriş + sakin döngü + menü müziği).

**Test (kullanıcı kararı, 27 Eyl 2026):** geliştirici test çalıştırmaz (`make test`, `make quick`, bot testleri ve `make balance` yok —
aşama sonunda da); oyunu kullanıcı kendisi oynayarak test eder. En fazla derleme (.exe export'u) ile parse hatası yakalanır.

**Aşama 10'da yapılanlar (menüler, denge ve teslim):**
- **Ana menü** (oyun artık buradan açılır): oyunun adı yazılmaz (kullanıcı kararı: henüz ad yok); arka plan **kullanıcının videosu**.
  Video 10 sn ve ~1,4. sn'den sonra kan akıyor; sürekli döngüde kan bir anda kaybolup sıçradığı için (kullanıcı kararı): oyun açılışında
  videonun tamamı **bir kez** oynar (kanlı giriş), son 1,4 sn'de çapraz geçişle **kansız sakin döngüye** geçer — videonun kansız ilk 1,3 sn'si
  yarı hıza yavaşlatılıp (komşu kareler karıştırılarak) ileri-geri dizildi, 5,2 sn'lik sıçramasız döngü. Menüye sonraki dönüşlerde yalnızca
  sakin döngü oynar. **Menü müziği videonun sesi** (`assets/audio/music/menu.ogg`: yükselen ses düzeyi dengelendi, sonu başına 1,5 sn
  çapraz geçişle bağlandı, 8,5 sn sıçramasız döngü, düzeyi 1. kat ambiyansıyla aynı; ırk seçiminde de sürer). Videolar sessiz.
- **Menü düğmeleri videonun kendi yazıları:** videoda "YENİ OYUN / YÜKLE / AYARLAR / ÇIKIŞ" yazıları gömülü; düğmeler bu yazıların üstüne
  oturan görünmez tıklama alanları (ekran oranı ne olursa olsun videoyla birlikte ölçeklenir). Üzerine gelince (ya da ↑/↓ ile) yazı kızıl
  parlar ve solunda aşağı sızan kan izi belirir. YENİ OYUN → ırk seçimi, AYARLAR → ses ayarları, ÇIKIŞ → çık. **YÜKLE soluk ve tıklanmaz**
  (kayıtlı run yok; kullanıcı kararı). Video dosyaları yoksa eski korlu yedek arka plan ve Başla / Ses ayarları / Çık düğmeleri.
- **Irk seçimi:** 4 kart — ırkın animasyonlu, meşale ışığıyla aydınlanan sprite'ı (elinde başlangıç silahı), can/zırh/hız, kaynak,
  Q ve E yetenekleri, pasif, silah ailesi, başlangıç silahının kalıcı ustalık leveli. Tıkla ya da ←/→, 1-4; Enter / çift tık / "Zindana in".
- **Duraklatma menüsü (Esc):** Devam, Ses ayarları, Ana menüye dön, Oyundan çık. **Ana menüye dönmek run'ı bırakır ve ölüm sayılır**
  (kullanıcı kararı; onay sorulur, ustalık o kattaki ölüm çarpanıyla işlenir, "RUN BIRAKILDI" özeti açılır). Oyundan çık da aynı.
- **Run sonu:** önce büyük **KAZANDIN** (altın) / **ÖLDÜN** (kan kırmızısı) başlığı, altından kan damlar; sonra run özeti ve
  "Yeni run (R)" / "Ana menü (Esc)".
- **Görünüş:** karanlık, kanlı tema (`UiTheme`): kömür karası paneller, pas-kan çerçeveler, kemik beyazı serif yazı (Windows'un kendi
  Palatino/Georgia fontu; dosya eklenmedi), üzerine gelince kan kırmızısına dönen düğmeler, başlıkların altından damlayan kan.
  Ses ayarları paneli de bu temaya geçti.
- **Geliştirici menüsü F5'te** (kullanıcı kararı): eski hata ayıklama menüsü ve test odası silinmedi, gizli kısayolla kaldı; M artık bir şey yapmaz.
- **Denge simülasyonu (`make balance`):** yeni `--balance` botu tam düşman sayısı ve canıyla, ölümsüz olmadan oynar (ölümcül hasarda
  ölüm sayılıp sürer), yerdeki işaretlerden ve saldırı hazırlayan düşmandan kaçar, en güçlü iki silahı takar; 4 ırk × seed paralel
  çalışır ve kat süresi / level / ölüm / alınan hasar tablosu çıkarır. Bir kez çalıştırıldı (4 ırk × 3 seed, 12 run, run başına 30 dk sınır):

  | Kat | Hedef süre | Bot süresi (ort., min–maks) | Boss süresi | Hedef level | Level (ort.) | Kata ulaşan run |
  | --- | --- | --- | --- | --- | --- | --- |
  | 1 | 6-8 dk | 9,8 dk (4,7–20,6) | 325 sn (Morvath) | 15 | 15,0 | 12 |
  | 2 | 7-10 dk | 25,9 dk (5,4–30*) | 14 sn | 35 | 29,5 | 12 (yalnızca 2'si geçti) |
  | 3 | 8-12 dk | 22,0 dk (14,1–30*) | 136 sn | 55 | 56,5 | 2 |
  | 4 | 9-15 dk | 11,6 dk | 126 sn | 80 | 80,0 | 1 |

  (*) 30 dk botun zaman sınırı. Gözlem: 1. katın fazlası Morvath'tan (zayıf silahla 5-10 dk); asıl duvar 2. kat (12 run'ın 10'u orada
  takıldı); buz silahı yoksa Kordrak'ın plakaları (%70) 3. katta duvar olabiliyor; ganimet şansı süreleri çok değiştiriyor.
  **Denge sayılarına dokunulmadı** (kullanıcı kararı): kullanıcı oynayarak karar verecek; bot süreleri kullanıcı için önemli değil.
- **Bot hızlandırması (kullanıcı kararı):** zindan botunda (`--autoplay`) bir düşman (boss dahil) oyuncudan **4 hasarlı vuruş alınca ölür**;
  uzun savaşlar bot run'larını uzatmaz. Denge botunda (`--balance`) ve boss testinde (`--boss-test`) kapalı (onlar tam savaşı ölçer);
  `--kill-hits=N` ile değiştirilir (0 kapatır). Oyuncunun oyununu etkilemez.
- **Hata düzeltmeleri:** Mycela'nın totemleri yeniden dikilirken ikinci bir sayaç başlayıp **6 totem** olabiliyordu (Mycela hep tam cana
  dönüyordu) — düzeltildi. Zindan botunun "takıldı" denetimi hedef değişince sıfırlanmıyordu — düzeltildi.
- **Performans (`make perf`):** bu bilgisayarın Intel UHD tümleşik ekran kartında 4. katta ortalama 59,9 FPS. Yeni düşman dalgası
  doğarken sprite'ların diskten yüklenmesi ~150 ms takılma yapıyordu: artık katın düşman/boss sprite'ları kata girerken yüklenip kat
  boyunca tutuluyor (en düşük saniye 50 → 57 FPS).
- **Boyut:** ışıma katmanlarında (`_e.png`) saydam piksellerin altında gereksiz renk verisi vardı; temizlendi (38,7 MB → 2,4 MB,
  görüntü aynı; sprite hattı da artık temiz yazar). .exe 220 MB → ~189 MB. Sonra **doku sıkıştırması** (kullanıcı kararı): renk ve normal
  sayfaları %85 kaliteli kayıplı WebP olarak içe aktarılır, ışıma katmanları kayıpsız (`make textures`; kaynak PNG'ler depoda kayıpsız,
  yalnızca `.import` ayarı). .exe ~153 MB (menü videosu ve müziği dahil, ~5,3 MB), zip ~80 MB.
- Testler: 8 yeni menü testi + Mycela totem testi (menü testi video düğmelerine göre güncellendi). Bu aşamada testler çalıştırılmadı
  (kullanıcı kararı); yalnızca .exe derlendi ve menü bir kez açılıp ekran görüntüsüyle bakıldı.

**Aşama 9'da yapılanlar (ses):**
- **Ses yönü görselle aynı: karanlık, kanlı, vahşi.** Islak et ve kemik kırılması, paslı demir, gırtlak gürlemeleri ve ulumalar, taş
  zindan yankısı; uğultulu, uyumsuz ambiyanslar ve savaş davullu boss müzikleri. Hepsi numpy ile sentezlendi (dosya indirilmedi).
- **Ses sentezleyici (`make sfx`):** `tools/audio/` (dsp.py araçlar, sfx.py efekt tarifleri, music.py müzik, sfx_synth.py giriş);
  Blender 5.2'nin Python'uyla (numpy + OGG kodlayıcı `aud`) çalışır, ~15 dk (yalnızca efektler ~30 sn).
- **137 ses efekti (264 varyant, WAV):** her silah tipinin sol/sağ tık sesi, 8 ırk yeteneği, düşmana isabet gövdeye göre (et, kemik,
  taş, metal, hayalet; güçlü vuruş, kritik, kalkana engellenme, bağışıklık), 6 element, 7 kombo, İnfaz, donma, gövdeye göre ölüm (+ elit ve
  boss ölümü), düşman saldırıları/mermileri/yetenekleri, boss tehlikeleri (işaret uyarısı + patlama/alan sesleri), 4 boss kükremesi ve
  mekanik sesleri (göz kapağı, plakalar, "BULDUN!", meşale), oyuncu (atılma, hasar, ölüm, iksir, silah değiştirme, level, İkinci şans, "olmaz",
  düşük canda kalp atışı), zindan (kapı parmaklıkları, dalga davulu, oda temizlendi çanı, sandık, tuzak, altın, eşya, nadirliğe göre loot
  sesi, çatlak duvar, gizli oda, merdiven) ve arayüz (düğmeler, envanter, sürükle-bırak, tüccar, demirci, ödül ekranı).
- **Müzik (OGG, dikişsiz döngü):** 4 kat ambiyansı (48 sn: damar ve nabız · mantar ve damla · dökümhane ve uzak örs · boşluk ve koro) ve
  her boss'a kendi müziği (Morvath 100 bpm, Mycela 6/8, Kordrak 132 bpm endüstriyel, Nyx'thar 150 bpm). Kata girince ambiyans, boss
  dövüşünde kükreme + boss müziği, boss ölünce 5 sn sonra ambiyansa dönüş, run bitince zafer/yenilgi vurgusu.
- **`Audio` autoload'u:** Master → Müzik, Efektler, Arayüz kanalları (Master'da sınırlayıcı), 32 konumlu (dünyadaki yerinden duyulur) +
  12 konumsuz oynatıcı, her ses için perde oynaması / aynı anda sınırı / tekrar aralığı, oyun durunca dünya sesleri de durur.
- **Ses ayarları (O tuşu, her ekranda):** ana ses, müzik, efektler, arayüz kaydırıcıları ve "Sessiz"; açıkken oyun durur, O/Esc kapatır;
  `%APPDATA%\Godot\app_userdata\Zindan Oyunu\settings.json`'a kaydedilir (bozuk dosyaya dayanıklı).
- Testler: 14 yeni birim testi (toplam 220): dosyalar, döngü, koddaki her ses çağrısı, eşlemeler, veri hatası, kanallar, çalma sınırları,
  gövde sesleri, tehlike sesleri, olaylar, müzik akışı, ayar kaydı ve panel.

**Aşama 9'da GDD'de olmayan ayrıntılar için verilen kararlar** (sayılar `data/audio.json` içinde `_default` notuyla; tam liste GDD >
Uygulamada Verilen Kararlar > Ses):
- Müzik de sentezlendi (kullanıcıdan dosya istenmedi). Beğenilmezse ücretsiz lisanslı müzikle değiştirilebilir: dosyayı
  `assets/audio/music/`'e koymak ve `audio.json > music.tracks`'te adını yazmak yeter.
- Her boss'a ayrı müzik (GDD "boss müziği" diyordu); 2. fazda boss daha kalın sesle yeniden kükrer.
- Efektler WAV (gecikmesiz; Godot QOA ile sıkıştırır), müzik OGG; sentez Blender'ın Python'uyla (MSYS2 `python3`'ünde numpy yok).
- 4 kanal ve varsayılan düzeyler (%80 / %55 / %85 / %70); ayar paneli O tuşunda (Aşama 10'da ana menü ve duraklatma menüsünden de açılır);
  ayarlar `user://settings.json`'da (ustalık kaydından ayrı).
- Konumlu ses: 2.200 ekran pikseline kadar, doğrusal sönüm (ekran kenarı ~−5 dB), %60 sağ-sol; oyuncu, arayüz, kapı, dalga ve boss
  kükremesi ortadan.
- Düşmanın vuruş/ölüm sesi gövdesine göre (et, kemik, taş, metal, hayalet); Taş ve Hayalet varyantları gövdeyi değiştirir.
- Boss'un ≥ 0,5 sn uyarılı tehlikelerinde işaret belirince alçak bir uyarı uğultusu (okunurluk için).
- Can %25'in altındayken kalp atışı (0,95 sn'de bir). Başarısız işlemde (kaynak/bekleme yok, iksir yok, satın alınamıyor) "olmaz" sesi.
- Test odasında müzik yok (yalnızca zindanda).

**Aşama 8'de yapılanlar (sanat):**
- **Görsel yön (kullanıcı kararı): karanlık, kanlı, vahşi.** İlk Warrior (çelik zırhlı, mavi tabardlı şövalye) reddedildi; referans
  resimle yeniden yapıldı: kapüşonlu, gözleri turuncu yanan, kül tenli kaslı savaşçı, kolsuz deri yelek, kanlı yırtık etek, kanlı kılıç.
  Tarz onaylanınca aynı yönle Ghost (kemik maskeli hayalet-suikastçı), Archer (savaş boyalı mohikanlı avcı) ve Magical (boynuzlu taçlı,
  eflatun rünlü kan büyücüsü) yapıldı.
- **Sprite hattı (`make sprites`):** Blender 5.2 komut satırından; modeller koddan düşük poligonlu parçalar ve eklemlerle, 8 yön,
  animasyonlar (bekleme, yürüme, saldırı, atış/büyü, sağ/sol yumruk, hasar, ölüm; Warrior'da Kalkan Hücumu), karanlık sert gölgeleme,
  kirli yüzey dokusu, metal/ıslak kan parlaması, koyu dış çizgi, normal haritası ve karanlıkta yanan gözler için ayrı ışıma katmanı.
- **12 silah** ayrı katman (16 dönüş × 4 eğim): elin o anki konumu ve açısıyla çizilir, element rengi ağzını boyar; çoğu kanlı.
  **Demir yumruk her ırkta iki elde (kullanıcı kararı)**, yumruklar sağ-sol sırayla.
- **Warrior Kalkan Hücumu (kullanıcı kararı):** sol demir bileklikten kalkan açılır, kalkan önde hücum, bitince kaybolur.
- **Kan (kullanıcı kararı):** her vuruşta vuruş yönüne kan fışkırır ve yere leke düşer; ölümde büyük fışkırma ve kan gölü (30 sn kalır).
  Hayalet düşmanların kanı koyu mor, zehirlilerin yeşil.
- **20 düşman + 4 boss** sprite'lı: insansı, sürüngen/böcek ve et kütlesi iskeletleri; malzeme varyantları renk tonuyla, elitler aura
  renginde, öncelikli hedefler sarı dış hatla; ölünce yığılıp kan kırmızısı kenarla **eriyerek** yok olur. Morvath'ın kapalı göz ve
  Kordrak'ın plakasız hali ayrı sprite; boss'lar saldırı animasyonu oynatır.
- **4 katın karoları ve dekoru** (normal haritalı): damarlı kızıl mağara (gözler, damarlar, kemikler), yosunlu mantar mağarası (parlayan
  mantarlar), kül dökümhanesi (lav çatlakları, demir plakalar), mor boşluk (kristaller); 4 zemin, 3 duvar, 2 sütun varyantı, parmaklıklı
  kapı, çatlak duvar. **Oda nesneleri:** sandık (kapalı/açık), fenerli tüccar, örsle demirci, karanlığa inen merdiven.
- **Işık:** karanlık zindan (kata özgü ortam rengi), oyuncunun çevresinde ışık, odaya bakan duvarlarda titreyen meşaleler (4. katta mor),
  tüccar feneri, demirci ocağı, büyü mermileri ve ateş topları ışık yayar. Uyarı işaretleri, mermiler, hasar sayıları, loot ve arayüz
  karanlıkta da okunur.
- **Shader'lar:** vuruş flaşı, malzeme tonu, eriyerek ölme, dış hat, lav (ateş birikintisi, Kordrak'ın lav kanalları), sıvı (zehir), sis
  (spor bulutları, karanlık alanlar), duvar arkası silüeti.
- **İkonlar:** 12 silah ve 3 tılsım ikonu, nadirlik renginde dövme demir çerçeve (envanter, tüccar, demirci, HUD, yerdeki eşyalar).
- **Hata düzeltmesi:** vuruş flaşı shader'ı dokuyu iki kez çarpıp sprite'ları karartıyordu.

**Aşama 8'de GDD'de olmayan ayrıntılar için verilen kararlar** (sayılar `data/progression.json > blood`, `data/dungeon.json > lighting`,
`data/floors.json > light` içinde `_default` notuyla; tam liste GDD > Uygulamada Verilen Kararlar > Sanat):
- Silahlar ayrı katman (her ırk her silahı taşıyabilsin); modeller ekranda %15 büyük (çarpışma aynı); sayfalar 2×, normaller 1×, karolar 1×.
- Kare sayıları (ırk: 6/8/6/6/5/5/4/8, düşman: 4/6/5/3/6, boss: 6/8/6/3/8); ölürken silah 3. karede elden düşer.
- Irk rengi kıyafette değil arayüzde; malzeme tonu %55; elit ×1,21 boy; eriyerek ölme 0,55 sn gecikme + 0,7 sn.
- Kan sayıları (12 damla/vuruş, güçlü ×1,7, ölüm ×3,2, oyuncu ×0,7; leke 30 sn, en fazla 90).
- Işık sayıları (ortam renkleri, oyuncu ışığı 8,5 karo, her 7 duvardan birine meşale, 5 karo, ±%15 titreme).
- Karo varyant oranları (zemin %52/26/12/10, duvar %72/20/8) ve konumdan hash ile seçim.
- `bpy` ayrıca kurulmadı, Pillow gerekmedi: Blender'ın kendi Python'u ve numpy kullanıldı.

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

Aşama 0-9'da verilen kararların tamamı GDD > Uygulamada Verilen Kararlar bölümündedir.

**Bilinen durumlar / notlar:**
- Denge simülasyonu bir bottur: insandan hızlı gezer ama daha kötü kaçar ve boss mekaniklerini bilinçli oynamaz; süreler kabaca bir
  alt/üst sınır verir. Gerçek zorluk oynayarak değerlendirilmeli. Boss testi (`make bosses`) hâlâ ölümsüz ve kaçmayan botla yapılır.
- Sprite'lar `make sprites` ile yeniden üretilir (Blender 5.2, ~35 dk); tek bir karakter ya da kat için `SPRITE_ARGS=--only=...`.
  Sprite'ı olmayan bir şey eklenirse (yeni düşman vb.) eski renkli şekille çizilir.
- Ustalık ve boss ilk kesişleri `%APPDATA%\Godot\app_userdata\Zindan Oyunu\save.json` dosyasına kaydedilir. Sıfırlamak için F5 geliştirici menüsü →
  "Ustalıkları sıfırla". Testler ve bot (autoplay) ayrı dosya kullanır, oyuncunun kaydına dokunmaz.
- Test için F5 geliştirici menüsünden level seçilebilir (XP'siz, ödül vermez) ya da "+1/+5 level (XP)" ile gerçek XP verilir; "Ölümsüz (test)" açılabilir.
  "Loot (test)" satırı loot yağdırır, altın ve silah XP'si verir.
- Hata ayıklama menüsünden level düşürülürse aktif slottaki yüksek levelli silah kullanılmaya devam eder (yalnızca test durumu).
- `bpy` ayrıca kurulmadı: sprite'lar Blender'ın kendisiyle (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`) komut satırından üretilir.
- .exe ~153 MB (Aşama 8-9: ~220 MB; Aşama 10: ışıma katmanları temizlendi, renk/normal sayfaları %85 WebP). Kaynak sprite PNG'leri
  depoda kayıpsız; yeni sprite üretilince `make sprites` sıkıştırma ayarını kendisi uygular (elle: `make textures`). Sesler .exe'ye ~9 MB ekler.
- Ana menü videosu değişirse: `make menu-video VIDEO="/c/.../video.mp4" BLENDER=...` (kanın başladığı an farklıysa `MENU_CALM_END=SN`).
  Videodaki gömülü yazıların yeri `scripts/ui/main_menu.gd > VIDEO_ITEMS`'ta (1280×720 piksel); yazılar değişirse orası da değişmeli.
- Sesler `make sfx` ile yeniden üretilir (Blender 5.2, ~15 dk); yalnızca efektler için `SFX_ARGS=--sfx`, tek ses/parça için
  `SFX_ARGS=--only=hit_flesh,floor_1`. Ses ayarları `%APPDATA%\Godot\app_userdata\Zindan Oyunu\settings.json` dosyasındadır; silinirse
  varsayılanlara döner.
- Başsız (headless) testlerin sonunda "resources still in use at exit" uyarısı çıkabilir: kapanışta hâlâ çalan seslerdendir, zararsızdır.
- .exe imzasız olduğu için Windows SmartScreen "Windows bilgisayarınızı korudu" uyarısı gösterebilir: **Ek bilgi → Yine de çalıştır**.
- Ghost iksir kullanamaz (Aşama 3'te onaylandı); iksir toplamaz, tüccar ona iksir satmaz, Yedek iksir ödülü sunulmaz.
- Hata ayıklama menüsü ve test odası F5'teki gizli geliştirici menüsünde (kullanıcı kararı, Aşama 10).

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
| O | Ses ayarları: ana ses, müzik, efektler, arayüz, sessiz (her ekranda; açıkken oyun durur, O ya da Esc kapatır) |
| Esc | Duraklatma menüsü: devam, ses ayarları, ana menüye dön (run ölüm sayılır), oyundan çık · menülerde geri |
| F5 | Gizli geliştirici menüsü (eski hata ayıklama menüsü): ırk, level, silahlar; zindanda kat/yeni harita/ölümsüz, loot testi, ilerleme testi (+level, boss ödülü, ustalık sıfırla, boss odasına ışınlan), test odası ↔ zindan; test odasında düşman türü (her tür ya da eliti) |
| R | Zindan: run sonu özetinde yeni run (Esc: ana menü) · Test odası: odayı yeniden başlat |
| 2-7 / 0 | (Test odası) Aktif silahın elementi: Ateş, Su, Yıldırım, Zehir, Buz, Karanlık / elementsiz |
| 8 | (Test odası) Aktif silahın özelliğini değiştir (Öfke, İnfaz, Can Emme, Sekme, Sersemletme) |
| N | (Test odası) Yeni dalga / kuklaları yenile |

## Geliştirme

Aşama 6'dan itibaren geliştirme bu klasörde yapılıyor; kurallar [`GELISTIRME.md`](GELISTIRME.md) dosyasında.

Gerekenler: Godot 4.7.2 (headless çalışır), aynı sürümün export şablonları, `make`, Python 3. Sprite (Aşama 8) ve ses (Aşama 9) üretimi için Blender (bu bilgisayarda 5.2; kendi Python'u numpy içerir). `zip` yoksa `make export-windows`
PowerShell'in `Compress-Archive`'ini kullanır. Bu bilgisayarda Godot `C:\Users\mcap5\Godot\` klasöründe
(`Godot_v4.7.2-stable_win64_console.exe` komut satırı için), şablonlar `%APPDATA%\Godot\export_templates\4.7.2.stable\` içinde.

```bash
make quick           # geliştirirken hızlı kontrol: birim testleri + test odası smoke (~1 dk); tek dosya: make unit TEST_FILTER=menus
make test            # aşama sonunda bir kez: birim testleri (220) + test odası smoke + ırk×silah matrisi + zindan smoke + boss testi (make unit / smoke / matrix / dungeon / bosses ayrı da çalışır)
make export-windows  # build/ içine ZindanOyunu.exe üretir ve zip'ler
make balance         # Aşama 10 denge simülasyonu (uzun, ~15-25 dk): 4 ırk × seed, kat süresi/level tablosu build/balance/balance.md
make perf            # 60 FPS ölçümü: oyun penceresinde bot 4. katı 90 sn oynar, saniyelik FPS ve özet
make menu-video VIDEO="/c/.../video.mp4" BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"   # ana menü: menu_intro.ogv + menu_loop.ogv + music/menu.ogg (~1 dk; MENU_CALM_END=1.3)
make textures        # sprite sıkıştırma ayarı: renk/normal sayfaları %85 kayıplı WebP, ışıma (_e) kayıpsız (make sprites kendisi çalıştırır)
make clean-alpha BLENDER=...   # sprite ışıma katmanlarında saydam piksellerin rengini sıfırlar (dosya küçülür, görüntü aynı)
make sprites BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"   # tüm sprite'lar (~35 dk); SPRITE_ARGS=--only=warrior,tiles1,icons
make sfx BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"      # ses efektleri (WAV) + müzik (OGG), ~15 dk; SFX_ARGS=--sfx (yalnızca efektler, ~30 sn) · --music · --only=hit_flesh,floor_1
make all             # hepsi
```

Godot başka bir yerdeyse: `make test GODOT=/yol/godot` (bu bilgisayarda: `make test GODOT=/c/Users/mcap5/Godot/Godot_v4.7.2-stable_win64_console.exe`).

Geliştirme bayrakları (oyunu `godot --path . -- <bayrak>` ile çalıştırırken; test odası için `godot --path . res://scenes/test_room.tscn -- <bayrak>`).
Aşama 10'dan beri oyun ana menüyle açılır; bir oyun bayrağı verilince menü atlanıp zindan doğrudan açılır (`--menu` menüde tutar):
- Aşama 10: `--balance` (denge botu: ölümsüz değil, ölümler sayılır, kaçınır, en iyi silahları takar; kat sonunda `[Denge]` satırı) ·
  `--kill-hits=N` (düşman N hasarlı vuruşta ölür; `--autoplay`'da varsayılan 4, denge/boss testinde 0) ·
  `--perf=SN` (SN sn FPS ölçümü, sonra kapanır) · `--open-pause` (duraklatma menüsü açık başlar) · `--menu` (ana menüde kal)
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
scripts/autoload/      Events, DataDB, GameState, SaveManager, Audio (Aşama 9: ses)
scripts/...            combat, player, enemies (Enemy, EnemyHazard, EnemyProjectile), bosses (Boss, Morvath, Mycela, Kordrak, Nyxthar…), dungeon, loot, progression, ui
scenes/                sahneler
assets/                sprites (characters/, weapons/, tiles/, props/, icons/: renk + normal + ışıma), shader, audio (sfx/: 264 efekt WAV, music/: 8 OGG + menu.ogg),
                       video/ (menu_intro.ogv, menu_loop.ogv: ana menü videosu, Ogg Theora), font
tools/                 blender/ (sprite üretici: modeller, animasyonlar, karolar, ikonlar; make_preview.py; menu_video.py; clean_alpha.py),
                       audio/ (ses ve müzik sentezleyici), dev/ (balance.py denge tablosu, texture_compress.py, print_dungeon.gd)
tests/                 headless birim testleri (run_tests.gd çalıştırıcı)
docs/GDD.md            tasarım dokümanı
```

### Veri dosyaları

Yeni silah, düşman ya da ödül eklemek için ilgili JSON'a bir kayıt eklemek yeterli. `DataDB` oyun açılırken tüm dosyaları okur;
eksik alan, yanlış tip, bozuk JSON, bilinmeyen id ya da toplamı 1 olmayan olasılık varsa hangi dosyada ve hangi alanda olduğunu
söyleyen bir hata verir (oyun ekranında da kırmızıyla görünür). `_` ile başlayan anahtarlar not/açıklama sayılır.

## Git akışı

Her aşama kendi branch'inde yapılır (`asama-0`, `asama-1`, …), bitince bir Pull Request ile `main`'e birleştirilir (merge).
geliştirici aşama sonunda yalnızca yerelde commit eder; kullanıcı uygulamayı test edip onaylayınca push eder (kullanıcının git hesabıyla),
GitHub'a ulaştığını kontrol eder ve `main`'e birleştirir. Yapamazsa kullanıcıya Git Bash komutlarını verir (`git push -u origin asama-N`).
