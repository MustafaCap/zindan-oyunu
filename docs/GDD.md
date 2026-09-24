# Zindan Oyunu — Tasarım Dokümanı (GDD)

Sep 23, 2026 · @Mustafa

Bu doküman oyunun tam tasarımı ve yapım rehberidir. Yeni bir sohbette oyunu yapmaya başlamak için bu dosyayı ekle ve en alttaki **Uygulama Rehberi**'nde verilen başlangıç mesajını gönder. Tüm sayılar başlangıç değerleridir ve oyun testlerinde ayarlanır.

## Genel Bakış

Tamamen emekle ilerlenen, öl-baştan-başla (roguelike) bir 2D izometrik zindan oyunu. Zindan temizlenir, loot toplanır ve kalıcı silah ustalığı sayesinde her run'da biraz daha güçlü dönülür.

| Konu | Karar |
| --- | --- |
| Motor | Godot 4 |
| Kamera | İzometrik |
| Görsel | Blender'da modellenip 8 yönden render edilen 3D görünümlü sprite'lar, normal map ile dinamik ışık |
| Platform | Windows .exe |
| Hedef içerik | \~100 silah, 4 ırk, 55 sıradan düşman, 20 boss, 4 etap |

100 silah ve 55 düşman veri odaklı üretilir: \~12 temel silah tipi ve \~15-18 temel düşman modeli, element, özellik ve varyantlarla çoğaltılır. Yeni içerik eklemek bir tabloya satır eklemek kadar kolay olmalıdır.

## Temel Döngü ve Run Yapısı

Her run level 1'de ve boş çantayla başlar. Ölünce yalnızca silah tipi ustalığı ve boss ilk kesiş bonusları kalır.

```mermaid
flowchart LR
  A[Run başlar<br/>Level 1] --> B[Odaları temizle<br/>loot topla]
  B --> C[Kat boss'u]
  C -->|Kat 1-3| B
  C -->|Kat 4| D[Zafer]
  B -->|Ölüm| E[Ustalık XP'si<br/>işlenir]
  D --> E
  E --> A
```

| Run sonunda | Ne olur |
| --- | --- |
| Oyuncu leveli (maks 80) | Sıfırlanır |
| Tüm silahlar, tılsımlar, eşyalar | Kaybolur |
| Boss'un run içi ödülü | Kaybolur |
| Silah tipi ustalığı (maks 12) | Kalır |
| Boss ilk kesiş bonusu (+%0,3 hasar) | Kalır |

## Kontroller ve Slotlar

WASD ile yürünür, saldırılar farenin gösterdiği yöne gider. Oyuncunun 4 slotu var ve çantayla slotlar arası değişim yalnızca oda dışında (koridorda ya da temizlenmiş odada) yapılabilir.

| Tuş | İşlev |
| --- | --- |
| WASD | Yürüme |
| Fare | Nişan (tüm saldırılar fare yönüne) |
| Sol tık | Aktif silahın normal saldırısı |
| Sağ tık | Aktif silahın güçlü saldırısı |
| Q | Birinci ırk yeteneği |
| E | İkinci ırk yeteneği |
| Space | Klasik atılma (tüm ırklarda aynı) |
| Tab | İki aktif silah arasında anında geçiş |
| 1 | İksir |
| F | Etkileşim (loot, kapı, tüccar) |

| Slot | Ne konur | Etkisi |
| --- | --- | --- |
| Aktif silah 1 | Açık silah | Tam güçle kullanılır |
| Aktif silah 2 | Açık silah | Tam güçle kullanılır, savaşta tuşla geçilir |
| Rezonans | Kilitli ya da açık silah | Kilitliyken normal saldırısının %10'u, açıkken %7'si kadar ek hasar |
| Esnek | Silah (kilitli ya da açık) veya tılsım | Silahsa pasifinin %9'u, tılsımsa tılsımın tam etkisi |

Diğer tüm silahlar çantada durur ve etki etmez.

## Zindan

Zindan 4 etaptan oluşur ve her etapta daha derine inilir. Harita yapısı (odalar, duvarlar, engeller) her run'da prosedürel olarak yeniden üretilir.

| Etap | Tema | Bulunan silah leveli | Not |
| --- | --- | --- | --- |
| 1 | Damarlı Mağara: bazı bölümlerinde duvarlarda damarlar ve gözler; iskeletler, fareler | 1 |  |
| 2 | Mantar Mağaraları: zehir, böcekler | 10 |  |
| 3 | Kül Dökümhanesi: ateş, taş golemler | 25-40 | Efsanevi silahlar buradan itibaren düşer |
| 4 | Boşluk: gölge, hayaletler | 50 |  |

Her etabın 5 boss'luk bir havuzu vardır ve her run'da bu havuzdan rastgele biri çıkar. 20 boss'un hepsini görmek için birçok run gerekir.

## Irklar

4 ırk var: Warrior, Ghost, Archer, Magical. Her ırk her silahı kullanabilir. Kendi silah ailesinde en iyidir, diğer ailelerde küçük bir ayar yer.

| Irk | Silah ailesi | Q | E | Kaynak | Pasif |
| --- | --- | --- | --- | --- | --- |
| Warrior | Kılıç, balta, demir yumruk | Zırh: kısa süreli, az hasar emen zırh ve +%3 hasar | Yer sarsıntısı: önündeki alana büyük hasar | Enerji | Yüksek can ve zırh |
| Ghost | Tırpan, hançer, gürz | Faz: maks 1 sn dokunulmaz ve düşmanlara görünmez | Gölge adımı: hedef düşmanın arkasına ışınlanır | Yok (bekleme süresi) | Fiziksele dirençli, ateşe zayıf; özel iyileşme kuralı |
| Archer | Yay, arbalet, mızrak | Geri sıçrama: geriye atılırken önüne 3 ok atar | Ok yağmuru: seçilen alana çoklu ok | Yok (bekleme süresi) | Menzil ve kritik bonusu |
| Magical | Kitap, asa, rün | Uçuş: kısa süre engel ve tuzakların üstünden uçar | Element fırtınası: aktif silahın elementinde alan hasarı | Mana | Element hasarı yüksek, can düşük |

Yakın ırklar (Warrior-Ghost, Archer-Magical) arasında ceza küçük, uzak ırklar arasında büyüktür. Ceza, o ırkın silahla birleşince bozacağı güce göre seçilir: tank ırklar uzak silahta can kaybeder, kırılgan ırklar yakın silahta biraz can kazanıp hasar ya da hız kaybeder.

| Irk ↓ / Silah ailesi → | Warrior | Ghost | Archer | Magical |
| --- | --- | --- | --- | --- |
| Warrior | 0 | −%5 saldırı hızı | −%25 maks can | −%20 maks can, −%10 element |
| Ghost | −%5 saldırı hızı | 0 | −%20 maks can | −%15 maks can, −%10 element |
| Archer | +%10 can, −%15 hasar | +%10 can, −%10 hasar | 0 | −%8 hasar |
| Magical | +%15 can, −%15 saldırı hızı | +%10 can, −%15 saldırı hızı | −%8 hasar | 0 |

Değerler başlangıç noktasıdır, oyun testlerinde ayarlanır. Ustalık ırktan bağımsızdır: Warrior ile yay kullanılırsa Yay ustalığı yine artar.

## Oyuncu Leveli ve Silah Leveli

Oyuncu her run'da level 1'den başlar ve en fazla 80'e çıkar. Silahlar da en fazla 80 level olur ve her 5 levelde istatistikleri +%5 artar.

- **Silah stat artışı:** Her 5 levelde oran yenilenir, üst üste katlanmaz: level 5'te +%5, level 10'da +%10 … level 80'de +%80. Oran her zaman silahın temel değerine uygulanır.
- **Yetişme XP'si:** Oyuncunun levelinin altındaki silah, oyuncunun kazandığı XP'nin 1,5 katını alır (oyuncu 100 XP alırsa silah 150 alır). Oyuncunun levelini yakalayınca normal hıza döner. Bu kural her katta aynıdır.
- **Kilitli silah:** Oyuncunun levelinden yüksek silah, oyuncu o levele gelene kadar kilitli kalır ve aktif slotta kullanılamaz. Rezonans ya da Esnek slota konabilir veya geride bırakılabilir.

**Level hedefi:** 1. kat 1→15 · 2. kat 15→35 · 3. kat 35→55 · 4. kat 55→80. XP eğrisi bu aralıklara göre ayarlanır.

### XP eğrisi

Bir sonraki levele gereken XP = 100 + 20 × mevcut level. Düşman XP'leri, her katın hedef level aralığına tam denk gelecek şekilde ayarlandı: katın tüm düşmanları ve boss'u kesilirse oyuncu katın hedef üst levelinde çıkar.

| Kat | Level aralığı | Gereken toplam XP | Normal düşman | Elit | Boss | Tahmini normal düşman sayısı |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 1→15 | 3.500 | 40 | 150 | 800 | \~60 |
| 2 | 15→35 | 11.800 | 120 | 500 | 2.400 | \~70 |
| 3 | 35→55 | 19.800 | 180 | 900 | 3.600 | \~80 |
| 4 | 55→80 | 36.000 | 280 | 1.800 | 7.200 | \~90 |

Kat başına 2 elit varsayılmıştır. Odaları atlayan oyuncu hedefin altında kalır; Deneyim kazanımı ödülleri bu açığı kapatır.

## Run İçi Ödüller

Run içinde iki ödül kaynağı var. İkisinde de kendi havuzundan gelen 2 seçenekten biri seçilir ve ödüller run bitince gider.

| Kaynak | Ne zaman | Havuz | Örnek |
| --- | --- | --- | --- |
| Level ödülü | Her 5 levelde (run başına 16 kez) | Küçük stat artışları | +%5 saldırı hızı |
| Boss ödülü | Her boss kesişinde | Büyük stat artışları ve saldırıyı değiştiren özellikler | +%10 saldırı hızı; çift vuruş; saldırıya küçük ek mermi |

### Level ödül havuzu

Küçük ve tekrar seçilebilir stat artışları. Her 5 levelde havuzdan rastgele 2 tanesi sunulur; tavana ulaşan stat artık çıkmaz.

| Ödül | Değer |
| --- | --- |
| Saldırı hızı | +%5 |
| Hasar | +%5 |
| Element hasarı | +%6 |
| Skill hasarı (sağ tık, Q, E) | +%5 |
| Maks can | +%8 |
| Kritik şansı | +%3 |
| Kritik hasarı | +%10 |
| Saldırı menzili | +%4 |
| Hareket hızı | +%4 |
| Bekleme süresi azaltma | +%3 |
| Space bekleme süresi azaltma | +%5 |
| Hasar azaltma | +%3 |
| Can emme | +%1 |
| Deneyim kazanımı | +%8 |
| Altın bulma | +%10 |

### Boss ödül havuzu

İki tür ödül var. Her boss sonrası sunulan 2 seçenekten biri büyük stat artışı, diğeri özel etki olur. Böylece oyuncu her seferinde "güvenli güç mi, build değiştiren etki mi" kararı verir. Özel etkiler bir run'da yalnızca bir kez alınabilir.

| Büyük stat (tekrar seçilebilir) | Değer |
| --- | --- |
| Saldırı hızı | +%10 |
| Hasar | +%12 |
| Element hasarı | +%15 |
| Skill hasarı (sağ tık, Q, E) | +%15 |
| Maks can | +%20 |
| Kritik şansı | +%8 |
| Kritik hasarı | +%25 |
| Saldırı menzili | +%10 |
| Hareket hızı | +%10 |
| Bekleme süresi azaltma | +%8 |
| Hasar azaltma | +%8 |
| Can emme | +%3 |

| Özel etki (run başına bir kez) | Etkisi |
| --- | --- |
| Çift vuruş | Normal saldırı %25 ihtimalle iki kez vurur |
| Ek mermi | Normal saldırı %30 hasarlı küçük bir mermi daha fırlatır (yakın silahta kılıç dalgası) |
| Delici | Mermiler ve dalgalar 1 düşmanı deler |
| Element izi | Space sonrası aktif silahın elementinde yerde iz kalır |
| Kombo ustası | Kombo hasarı +%30 |
| Kritik zinciri | Kritik vuruş %20 ihtimalle sağ tık, Q ve E beklemelerini 1 sn azaltır |
| Rezonans güçlendirme | Rezonans bonusu kilitliyken %15, açıkken %10 olur |
| Hiddet | Öfke tavanı %6'dan %10'a çıkar |
| Cellat | İnfaz eşiği +%2 (boss'larda +%1) |
| Yedek iksir | İksir kapasitesi +1 ve tüm iksirler dolar |
| İkinci şans | Ölünce bir kez %30 canla dirilir |

## Silah Tipi Ustalığı

Ustalık, silahın kendisine değil silah tipine (Kılıç, Yay, Asa…) bağlıdır ve oyunda kalıcı olan tek ilerlemedir. Maks level 12'dir.

| Bonus | Level başına | Level 6 | Level 12 |
| --- | --- | --- | --- |
| Hasar | +%5 | +%30 | +%60 |
| Saldırı hızı | +%3,33 | +%20 | +%40 |
| Saldırı menzili | +%1,67 | +%10 | +%20 |
| Element hasarı | +%2,5 | +%15 | +%30 |

**XP dağılımı:** Run boyunca ustalık XP'si birikir ve run bitince işlenir. XP, verilen toplam hasarın silah tiplerine göre yüzdesiyle bölünür. Örneğin hasarın %70'i kılıçtan, %30'u yaydan geldiyse XP de aynı oranda gider.

**XP eğrisi:** Referans birimi 1 maç = 100 XP, yani 2. katı tamamlayıp ölen bir oyuncunun kazancı.

| Level | Gereken maç | Gereken XP | Toplam maç |
| --- | --- | --- | --- |
| 1 → 2 | 3 | 300 | 3 |
| 2 → 3 | 4 | 400 | 7 |
| 3 → 4 | 6 | 600 | 13 |
| 4 → 5 | 8 | 800 | 21 |
| 5 → 6 | 12 | 1.200 | 33 |
| 6 → 7 | 12 | 1.200 | 45 |
| 7 → 8 | 13 | 1.300 | 58 |
| 8 → 9 | 13 | 1.300 | 71 |
| 9 → 10 | 13 | 1.300 | 84 |
| 10 → 11 | 14 | 1.400 | 98 |
| 11 → 12 | 16 | 1.600 | 114 |

**Derinlik çarpanı:** 1. katta ölüm ×0,1 · 2. katta ölüm ×0,3 · 2. katı bitirme ×1,0 · 3. katta ölüm ×1,5 · 4. katta ölüm ×2,0 · zafer ×3,0.

## Rezonans ve Esnek Slot

Kilitli silahlar çöp değildir: iki özel slot sayesinde kullanılamazken bile güç verirler. Bu, "çok istediğim silahı taşıyıp kilidini açmayı bekleyeyim mi, geride mi bırakayım?" kararını doğurur.

- **Rezonans slotu (1 adet):** Kilitli ya da açık silah konur. Kilidi açılan silah slotta kalabilir, ancak bonus %10'dan %7'ye düşer. Aktif silah her vuruşta, kilitli silahın normal saldırısının %10'u kadar ek hasarı onun elementiyle verir. Örneğin zehirli kılıç ve kilitli yıldırım asasıyla her vuruşta zehir arttı küçük bir yıldırım.
- **Esnek slot (1 adet):** Silah konursa (kilitli ya da açık) pasif özelliğinin %9'u işler. Tılsım konursa tılsımın kendi etkisi tam işler.
- **Bağışıklık geçerlidir:** Rezonans hasarı da bağışıklık kurallarına uyar. Taş düşmana yıldırım rezonansı işlemez.
- **İstifleme yok:** Tek Rezonans slotu olduğu için çantadaki diğer kilitli silahlar etki etmez.

### Tılsımlar (ilk sürüm)

| Tılsım | Etkisi |
| --- | --- |
| Kan Taşı | Her öldürme 10 sn boyunca +%2 hasar verir, maks 5 yığın |
| Rüzgâr Tüyü | Space bekleme süresi %30 azalır; atılmadan sonra 2 sn +%15 hareket hızı |
| Element Kalbi | Bir kombo tetiklenince 3 sn boyunca +%20 element hasarı |

## Elementler, Özellikler ve Kombolar

6 element ve 5 özellik vardır. Elementler bağışıklık ve kombo sistemine girer. Özellikler herhangi bir elementle birleşir (örn. "Öfkeli Buz Kılıcı", "İnfazcı Zehir Hançeri"). 12 silah tipi × 6 element × 5 özellik × nadirlik ile 100 silah hedefi rahatça aşılır.

| Element | Tek başına etkisi |
| --- | --- |
| Ateş | Yanma: süreli hasar |
| Su | Islatma: kendi hasarı düşük, kombo hazırlar |
| Yıldırım | Yakındaki düşmana zincirleme sıçrar |
| Zehir | İstiflenen süreli hasar |
| Buz | Yavaşlatma, istiflenince kısa süre dondurur |
| Karanlık | Hedefe arkasından vurulursa +%10 hasar; kısa süreli Gölge işareti bırakır |

| Özellik | Etkisi |
| --- | --- |
| Öfke | Aynı hedefe her vuruşta +%1 hasar, hedef başına ayrı birikir, maks %6 |
| İnfaz | Hedefin canı %7'nin altına düşünce anında öldürür; boss'larda eşik %3 |
| Can Emme | Verilen hasarın %3'ü can olarak döner |
| Sekme | Vuruş %35 ihtimalle yakındaki ikinci düşmana %50 hasarla seker |
| Sersemletme | Vuruş %8 ihtimalle hedefi 0,8 sn sersemletir; boss'larda bunun yerine 1 sn yavaşlatır |

**Kombolar:** Hedefin üzerinde bir element varken ikinci bir elementle vurulursa kombo tetiklenir ve ilk element tüketilir.

| Kombo | Sonuç |
| --- | --- |
| Su + Yıldırım | Elektroşok: tüm ıslak düşmanlara zincirleme hasar |
| Ateş + Buz | Erime: büyük tek seferlik hasar |
| Su + Buz | Donma: hedef 2 sn donar |
| Donmuş + Yıldırım | Kırılma: garantili kritik vuruş |
| Ateş + Zehir | Zehir Patlaması: alan hasarı |
| Ateş + Su | Buhar: hedeflerin isabeti düşer |
| Zehir + Karanlık | Çürüme: iyileşme engellenir, zehir hasarı iki katına çıkar |

Boss'lar dondurulduktan sonra 8 sn donmaya bağışık olur. İki aktif silah arasında geçiş komboların ana aracıdır: Su yayıyla ıslat, Yıldırım asasına geç, Elektroşok patlat.

## Düşmanlar, Boss'lar ve Bağışıklık

55 sıradan düşman \~15-18 temel modelin varyantlarından (taş, zehirli, elit, hayalet sürümü) üretilir. 20 boss, etap başına 5'erli havuzlara bölünür ve her birinin özel bir mekaniği olur.

### İlk düşman listesi

17 temel düşman, 5 rolde: yakın dövüş, uzak, sürü, tank, destek. Her birinin elit sürümü (daha büyük, bir auralı) ve katlar arası element varyantlarıyla 55'e tamamlanır.

| Kat | Düşman | Rol | Davranış | Bağışık |
| --- | --- | --- | --- | --- |
| 1 | İskelet Savaşçı | Yakın | Oyuncuya yürür, basit kılıç darbesi | — |
| 1 | İskelet Okçu | Uzak | Mesafe korur, tek ok atar | — |
| 1 | Mağara Faresi | Sürü | 5-8'li gruplar, hızlı ve zayıf | — |
| 1 | Göz Yavrusu | Uzak | Duvara yapışık durur, kısa ışın atar | — |
| 1 | Damar Kütlesi | Tank | Yavaş, ölünce etrafına patlar | — |
| 2 | Sporlu Böcek | Sürü | Ölünce zehir bulutu bırakır | Zehir |
| 2 | Mantar Adam | Tank | Yavaş, geniş yumruk | Zehir |
| 2 | Zehir Tükürücü | Uzak | Yerde zehir birikintisi bırakan tükürük | Zehir |
| 2 | Mantar Şifacı | Destek | Yakındaki düşmanları iyileştirir, öncelikli hedef | Zehir |
| 3 | Taş Golemcik | Tank | Zırhlı, yavaş, yere vurur | Yıldırım |
| 3 | Kor Köpeği | Yakın | Sürü halinde hızlı saldırır | Ateş |
| 3 | Cüruf Büyücüsü | Uzak | Ateş topu atar, yere lav bırakır | Ateş |
| 3 | Demir Muhafız | Yakın | Kalkanı önden hasarı engeller; arkadan vurulmalı | Yıldırım |
| 4 | Gölge | Yakın | Kısa süre görünmezleşip arkadan saldırır | Fiziksel |
| 4 | Feryatçı | Uzak | Çığlığı yavaşlatır | Fiziksel |
| 4 | Boşluk Kulu | Tank | Karanlık hasarı, oyuncuyu kendine çeker | Karanlık |
| 4 | Boşluk Çağırıcı | Destek | Sürekli Gölge çağırır, öncelikli hedef | Fiziksel |

**Boss ödülü:**

- Her kesişte boss ödül havuzundan gelen 2 seçenekten biri seçilir (Run İçi Ödüller bölümü)
- İlk kesişte ayrıca kalıcı +%0,3 hasar (20 boss ile maks +%6)

**Bağışıklık:** Her düşmanın malzemesine göre elementlere karşı Bağışık, Dirençli ya da Zayıf durumu vardır. Bağışık olunan element, o elementle efsunlu silahları ve Rezonans hasarını da kapsar.

| Düşman türü | Bağışık | Zayıf |
| --- | --- | --- |
| Taş | Yıldırım | Buz |
| Hayalet | Fiziksel | Ateş |
| Ateş elementali | Ateş | Buz, Su |

Yaygın (elementsiz) silahlar hayaletlere %25 hasar verir. Haksız run'ları önlemek için düşmanın üstünde bağışıklık ikonu görünür ve oyuncunun her zaman ikinci bir aktif silahı vardır.

## Boss'lar (İlk Sürüm)

İlk sürümde her katta 1 boss var; kat havuzları sonradan 5'er boss'a tamamlanır. Her boss'un %50 canda başlayan ikinci fazı ve bir elementi ödüllendiren özel bir mekaniği vardır. Saldırıların hepsi yerde kırmızı işaretle önceden gösterilir.

| Kat | Boss | Bağışık | Zayıf |
| --- | --- | --- | --- |
| 1 | Morvath, Ana Göz | — | Yıldırım |
| 2 | Mycela, Spor Kraliçesi | Zehir | Ateş |
| 3 | Kordrak, Erimiş Demirci | Yıldırım | Buz |
| 4 | Nyx'thar, Yankısız | Fiziksel | Ateş |

### 1. Kat — Morvath, Ana Göz

**Görünüş:** Mağara duvarına gömülü, 3-4 oyuncu boyunda ıslak ve etli bir göz kütlesi. Çevresinden zemine ve duvarlara nabzı atan kırmızı-mor damarlar yayılır; duvarlarda 3 küçük göz vardır. Hareket etmez, arena onun etrafındaki yarım daire şeklindeki mağara odasıdır.

| Saldırı | Ne yapar | Nasıl kaçınılır |
| --- | --- | --- |
| Bakış Işını | Arenayı yavaşça tarayan döner ışın | Space ile ışının içinden geçmek ya da kaya sütunların arkasına saklanmak |
| Damar Kırbacı | Zeminde çizgiler halinde damarlar fışkırır | Kırmızı çatlak işaretlerinden çıkmak |
| Göz Yavruları | 4-6 küçük sürünen göz doğurur | Alan hasarıyla temizlemek |

**Özel mekanik — Kapanan Göz Kapağı:** Morvath düzenli olarak göz kapağını kapatır ve hasar almaz. Duvardaki 3 küçük göz kırılınca kapak açılır ve 6 sn boyunca %50 fazla hasar alır. Islak damarlar yıldırımı iletir: yıldırım hasarı duvardaki gözlere de sıçrar.

**2. faz (%50):** Damarlar nabzı hızlanır ve zeminin bazı bölgeleri sürekli hasar verir. Bakış Işını ikiye bölünür ve ters yönlere döner.

### 2. Kat — Mycela, Spor Kraliçesi

**Görünüş:** Mantardan yapılmış, uzun ve ince insansı bir gövde; başında geniş, altı parlayan yeşil-mor bir mantar şapkası. Kolları kök gibi yere uzanır, etrafında sürekli toz halinde sporlar uçuşur. Arena, yer yer büyük mantarların olduğu yuvarlak bir mağara.

| Saldırı | Ne yapar | Nasıl kaçınılır |
| --- | --- | --- |
| Spor Bulutu | Arenada birkaç saniye kalan zehirli bulutlar bırakır | Bulutlardan uzak durmak |
| Kök Patlaması | Oyuncunun altından sırayla kökler fışkırır | Sürekli hareket etmek |
| Spor Oku | Oyuncuya doğru yelpaze şeklinde 5 spor fırlatır | Aralarındaki boşluğa girmek |

**Özel mekanik — İyileştiren Mantarlar:** Mycela arenaya 3 mantar totemi diker; totemler yaşadıkça onu iyileştirir. Totemler öncelikli hedeftir. Ateş, spor bulutlarını yakıp yok eder; üzerinde zehir olan bulut ateşle vurulursa Zehir Patlaması tetiklenir ve boss'a da hasar verir.

**2. faz (%50):** Arena yavaşça sporla dolar; temiz hava alanları küçülür. Mycela köklerini çekip arenada hızla yer değiştirmeye başlar.

### 3. Kat — Kordrak, Erimiş Demirci

**Görünüş:** Kara taştan yontulmuş, iri omuzlu bir golem. Göğsünde turuncu parlayan erimiş bir çekirdek, vücudunda demir zırh plakaları, elinde örs başlı dev bir çekiç. Arena, zemininde lav kanalları olan bir dökümhane salonu.

| Saldırı | Ne yapar | Nasıl kaçınılır |
| --- | --- | --- |
| Örs Darbesi | Çekici yere vurur, genişleyen bir şok halkası yayılır | Space ile halkanın üzerinden atlamak |
| Lav Dolumu | Zemindeki kanalları lavla doldurur | Kanalların dışında durmak |
| Kor Yumruğu | Oyuncuya doğru hızlı bir atılım ve yumruk | Yana kaçmak |

**Özel mekanik — Soğutma:** Zırh plakaları gelen hasarı %70 azaltır. Buz hasarı plakaları soğutur; 5 buz yığınında plakalar kırılır ve zırh 10 sn boyunca kalkar. Ateş + Buz Erime kombosu zırhsız Kordrak'a çok büyük hasar verir. Taş gövdesi nedeniyle yıldırım işlemez.

**2. faz (%50):** Plakalar kalıcı olarak düşer, çekirdek açığa çıkar. Kordrak hızlanır ve her Örs Darbesi'nden sonra etrafa ateş topları saçar.

### 4. Kat — Nyx'thar, Yankısız (final boss'u)

**Görünüş:** Havada süzülen, yırtık bir pelerine benzeyen uzun bir hayalet. Yüzünün yerinde boş bir karanlık ve içinde sönmeyen tek bir soluk ışık; alt kısmı duman gibi dağılır. Arena, uçurumla çevrili, kenarlarında meşale tutacakları olan yürünebilir bir taş platform.

| Saldırı | Ne yapar | Nasıl kaçınılır |
| --- | --- | --- |
| Gölge Kopyaları | 3 kopyaya bölünür; gerçek olanın tek farkı yere gölge düşürmesidir | Gerçek olanı bulmak; sahteye vurmak onu oyuncunun yanına ışınlar |
| Boşluk Yırtığı | Oyuncuyu içine çeken portallar açar | Çekime karşı yürümek ya da Space |
| Çığlık | Etrafındaki alana gecikmeli patlama | İşaret dolmadan alanı terk etmek |

**Özel mekanik — Karanlık Perdesi:** Nyx'thar arenayı karartır; yalnızca yanan meşalelerin çevresi güvenlidir, karanlıkta durmak canı yavaşça eritir. Ateş hasarı sönmüş meşaleleri yeniden yakar. Hayalet olduğu için fiziksele bağışıktır (yaygın silahlar %25 hasar verir).

**2. faz (%50):** Platformun kenarları uçuruma çöker ve arena küçülür. Gölge Kopyaları 5'e çıkar ve kopyalar da Boşluk Yırtığı açabilir.

## Skill Sistemi

Her silahın iki saldırısı var: sol tık normal saldırı, sağ tık güçlü saldırı. Irkın iki yeteneği Q ve E'de (Irklar bölümü). Space tüm ırklarda aynı klasik atılmadır.

### Silah tipleri

Warrior silahları hızlı ve kısa menzilli, Ghost silahları kısa menzilli ve yüksek hasarlı, Archer silahları uzun menzilli, yavaş-orta hızlı ve biraz düşük hasarlı, Magical silahları orta menzilli ve standart hasarlıdır. Menzil karo cinsindendir; hasar = nadirlik temel hasarı × çarpan.

| Tip | Aile | Saldırı/sn | Menzil | Hasar çarpanı | Güçlü saldırı (sağ tık) |
| --- | --- | --- | --- | --- | --- |
| Kılıç | Warrior | 1,4 | 1,5 | ×1,0 | Dönen kesik: etrafındaki herkese hasar |
| Balta | Warrior | 1,1 | 1,6 | ×1,25 | Balta fırlatma: geri dönen balta |
| Demir yumruk | Warrior | 2,0 | 1,0 | ×0,7 | Seri yumruk: 5 hızlı yumruk, sonuncusu sersemletir |
| Tırpan | Ghost | 0,9 | 2,0 | ×1,5 | Hasat: geniş yay, arkadan vurulanlara +%20 |
| Hançer | Ghost | 1,6 | 1,0 | ×0,9 | Saplama: ileri atılıp hedefin arkasından vurma |
| Gürz | Ghost | 0,7 | 1,4 | ×1,9 | Yere vuruş: alan hasarı ve yavaşlatma |
| Yay | Archer | 0,9 | 9 | ×0,9 | Güçlü atış: basılı tutunca dolan delici ok |
| Arbalet | Archer | 0,6 | 10 | ×1,3 | Saçma: yelpaze şeklinde 5 cıvata |
| Mızrak | Archer | 0,8 | 3,5 | ×1,0 | Fırlatma: uzağa saplınır, tekrar basınca geri döner |
| Kitap | Magical | 1,2 | 5 | ×0,85 | Güdümlü sayfalar: hedef arayan 4 mermi |
| Asa | Magical | 1,0 | 6 | ×1,0 | Element küresi: çarpınca patlayan büyük küre |
| Rün | Magical | 0,8 | 5 | ×1,2 | Rün tuzağı: üzerine basılınca patlayan rün alanı |

### Kaynaklar

| Irk | Kaynak | Nasıl çalışır |
| --- | --- | --- |
| Warrior | Enerji, sabit 100 | Q 40, E 70 enerji harcar. Saniyede 10 dolar, her isabetli vuruşta +2. Sağ tık bekleme süreli (5-7 sn). |
| Magical | Mana: 120 + level × 4 (level 80'de 440) | Sol tık 1, sağ tık 55, Q 65, E 90 mana harcar. Saniyede maks mananın %3'ü dolar, enerjiden yavaş. Maks levelde arka arkaya 5-6 skill atılabilir. |
| Archer | Yok | Sağ tık 6 sn, Q 8 sn, E 18 sn bekleme süresi |
| Ghost | Yok | Sağ tık 5 sn, Q 12 sn, E 10 sn bekleme süresi |

Magical dışındaki bir ırk kitap, asa ya da rün kullanırsa silah mana yerine bekleme süresiyle çalışır; bu süreler normalin 1,5 katıdır.

### Irk başlangıç statları

| Irk | Can (level 1) | Level başına can | Hareket hızı | Zırh |
| --- | --- | --- | --- | --- |
| Warrior | 150 | +6 | 1,0 | %15 |
| Ghost | 100 | +4 | 1,1 | %0 |
| Archer | 90 | +3,5 | 1,05 | %0 |
| Magical | 80 | +3 | 1,0 | %0 |

## Denge: Stat Tavanları

Bir run'da 16 level ödülü, boss ödülleri, silah leveli ve ustalık üst üste biner. Kontrolden çıkmaması için her statta tüm kaynakların toplamı bir tavanla sınırlıdır.

| Stat | Toplam tavan (başlangıç değeri) |
| --- | --- |
| Saldırı hızı | +%150 |
| Saldırı menzili | +%50 |
| Kritik şansı | %60 |
| Hasar azaltma | %75 |
| Bekleme süresi azaltma | %40 |

Hasarın tavanı yoktur, onun yerine düşmanlar ölçeklenir: her katta düşman canı ve hasarı, o katın hedef oyuncu level aralığına göre artar. Tavana ulaşan stat, ödül seçeneklerinde artık çıkmaz. Değerler oyun testlerinde ayarlanır.

## Nadirlik ve Efsanevi Silahlar

4 nadirlik seviyesi var. Nadirlik; temel hasarı, element ve özellik sayısını belirler.

| Nadirlik | Renk | Temel hasar | Element | Özellik | Ekstra |
| --- | --- | --- | --- | --- | --- |
| Yaygın | Gri | 100 | Yok (fiziksel) | Yok |  |
| Ender | Mavi | 125 | 1 | Yok |  |
| Destansı | Mor | 175 | 1 | 1 |  |
| Efsanevi | Turuncu | 260 | 1 | 1 veya 2 | Kendine özel pasif ve skill |

Temel hasar silah tipine göre bir çarpanla ayarlanır: hızlı silahlar (hançer, demir yumruk) daha düşük, yavaş silahlar (balta, gürz) daha yüksek vurur. Böylece saldırı başına değil saniye başına hasar dengelenir.

**Düşme oranları:**

| Kat | Yaygın | Ender | Destansı | Efsanevi |
| --- | --- | --- | --- | --- |
| 1 | %75 | %22 | %3 | %0 |
| 2 | %55 | %33 | %12 | %0 |
| 3 | %35 | %38 | %22 | %5 |
| 4 | %20 | %38 | %32 | %10 |

Elit düşmanlar ve gizli odalar üst nadirlik şanslarını iki katına çıkarır. 3. ve 4. kat boss'ları en az Destansı silah düşürür.

Efsanevi pasif örnekleri: her 5. vuruş gökten yıldırım indirir; öldürülen düşman elementinde patlar; bir kombo tetiklenince sağ tık, Q ve E bekleme süreleri sıfırlanır. Her efsanevi silahın adı ve pasifi elle tasarlanır.

## Ekonomi ve Oda Tipleri

Altın yalnızca run içinde harcanır ve ölünce gider. Her kat, savaş odalarının arasına serpiştirilmiş özel odalar içerir.

| Oda | Kat başına | İşlevi |
| --- | --- | --- |
| Savaş | Çoğunluk | Düşman dalgaları, loot ve altın |
| Elit | 1-2 | Güçlü tek düşman, daha iyi loot |
| Tüccar | 1 | Silah, tılsım ve iksir satın alma; çantadaki silahları satma |
| Demirci | 1 | Altınla silah leveli atlatma ya da ek stat yeniden çekme |
| Sandık | 1-2 | Ücretsiz loot, bazen tuzaklı |
| Gizli oda | 0-1 | Duvar kırılarak bulunur, yüksek nadirlik şansı |
| Boss | 1 | Kat sonu |

Oda değişimi kuralı burada da geçerli: tüccar ve demirci odaları savaş dışı sayılır, slot değişimi yapılabilir.

## Can ve İyileşme

Can kıt bir kaynaktır: temel iyileşme sınırlı iksirler ve boss sonrası tam iyileşmedir.

- **İksir:** Run'a 2 iksirle başlanır, en fazla 3 taşınır. Her biri maks canın %40'ını doldurur. Yenisi tüccardan alınır ya da nadiren düşmandan düşer. Kullanım tuşu: 1.
- **Boss sonrası:** Kat boss'u kesilince can tamamen dolar.
- **Diğer kaynaklar:** Can emme ödülleri ve özellikleri, tılsımlar.
- Temizlenen odalarda otomatik iyileşme yoktur.

**Ghost istisnası:** Ghost iksir kullanamaz ve can emmeyle iyileşmez. Yalnızca iki yolla iyileşir: öldürdüğü her düşman maks canının %4'ünü (elit %10) doldurur, kat boss'u kesilince canı tamamen dolar. Ghost'ta can emme etkileri öldürme başına ek iyileşmeye dönüşür.

## Run Süresi

Tam bir run (4 kat, zafer) hedefi 30-45 dakikadır. Harita boyutu ve düşman sayısı buna göre ayarlanır.

| Kat | Hedef süre | Oda sayısı (boss dahil) |
| --- | --- | --- |
| 1 | 6-8 dk | 8 |
| 2 | 7-10 dk | 9 |
| 3 | 8-12 dk | 10 |
| 4 | 9-15 dk | 11 |

## Menüler ve Oyun Sonu

İlk sürümde yalnızca iki ekran var: Başla tuşu olan ana menü ve ırk seçim ekranı. Ustalık levelleri ve boss ilk kesiş bonusları otomatik kaydedilir. 4. kat boss'u kesilince "Kazandın" ekranı çıkar ve ana menüye dönülür. Ayrıntılı arayüz tasarımı ve hikâye sonraya bırakıldı.

## Görsel Stil ve Efektler

Oyun 2D ama 3D gibi görünmeli ve vuruşlar iyi hissettirmelidir.

- **Sprite üretimi:** Karakter ve düşmanlar Blender'da low-poly modellenir, animasyonlanır ve 8 yönden render alınarak sprite sheet'e dönüştürülür. Aynı render'dan normal map de çıkarılır.
- **Işık:** Meşaleler ve büyüler normal map sayesinde karakterleri dinamik olarak aydınlatır.
- **Shader'lar:** Vuruşta beyaz flaş, eriyerek ölme, outline, sis, su ve lav.
- **Vuruş hissi:** Hitstop (mikro donma), ekran sarsıntısı, uçan hasar sayıları, büyük ve renkli kritik yazısı, silah izi, kıvılcım ve kan partikülleri, savrulan düşmanlar.
- **Loot:** Düşen eşyanın nadirliğine göre ışık sütunu (efsanevi = turuncu).
- **Arayüz:** Godot'nun Control sistemiyle özel tema: envanter ızgarası, sürükle-bırak, stat karşılaştırmalı tooltip, skill çubuğu. Ekranlar kodlamadan önce mockup olarak tasarlanır.
- **Ses:** Ses efektleri kodla sentezlenir. Müzik için basit sentez ya da ücretsiz müzik kütüphaneleri kullanılır.

## Açık Kararlar

- [ ] Oyunun adı
- [ ] Ghost'un iksir kullanamaması onaylanıyor mu?
- [ ] Kalan 16 boss (kat başına 4)
- [ ] Hikâye ve lore
- [ ] Ayrıntılı arayüz tasarımı
- [x] Kontroller: WASD, fare nişan, sol/sağ tık silah, Q/E ırk, Space atılma
- [x] Kaynaklar: Warrior enerji, Magical mana, Archer ve Ghost bekleme süresi
- [x] Silah ailesi karakterleri (menzil, hız, hasar)
- [x] 3 tılsım, 17 temel düşman, XP eğrisi, 4 boss
- [x] Menüler: Başla ve ırk seçimi; zaferde "Kazandın"
- [x] Level ve boss ödül havuzları (15 + 12 stat, 11 özel etki)
- [x] Nadirlik: Yaygın 100, Ender 125, Destansı 175, Efsanevi 260
- [x] Magical'ın uçuşu, dört ırkın pasifleri
- [x] Silah stat artışı: her 5 levelde oran yenilenir, katlanmaz (maks +%80)
- [x] Oyuncu level hedefi: 1→15, 15→35, 35→55, 55→80
- [x] 3\. kat silah leveli 25-40
- [x] Ustalık XP'si derinlik çarpanları
- [x] Boss ilk kesiş bonusu +%0,3 (20 boss ile maks +%6)
- [x] 12 silah tipi: kılıç, balta, demir yumruk, tırpan, hançer, gürz, yay, arbalet, mızrak, kitap, asa, rün

## Uygulama Rehberi

Bu bölüm, oyunu sıfırdan yapacak bir Claude oturumu için yazıldı. Oyun 11 aşamada (0-10) yapılır; her aşama oynanabilir ya da test edilebilir bir sonuçla biter ve kullanıcının onayıyla bir sonrakine geçilir. Tasarımın kaynağı bu dokümandır; yukarıdaki tablolar oyundaki veri dosyalarının birebir karşılığıdır.

**Yeni sohbete gönderilecek başlangıç mesajı:**

```
Ekteki dosya zindan oyunumun tasarım dokümanı (GDD). Oyunu bu dokümandaki
"Uygulama Rehberi"ni adım adım takip ederek yapacağız.
- Önce dokümanın tamamını oku.
- Aşama 0'dan başla; bir aşamayı bitirmeden sonrakine geçme.
- Her aşama sonunda testleri çalıştır, Windows .exe'yi derleyip bana gönder,
  GitHub reposuna push et ve bana neyi test etmem gerektiğini yaz.
- Tasarım kararlarını değiştirmeden önce bana sor; dokümanda olmayan
  bir ayrıntıda en makul kararı ver ve bana bildir.
```

Sonraki oturumlarda kaldığın yerden devam etmek için: "GDD ekte, repo şu: \<link>. Aşama N'den devam et."

### Teknik Altyapı

| Araç | Kullanım | Nereden |
| --- | --- | --- |
| Godot 4 (en güncel kararlı 4.x) | Motor; Linux headless sürümü testler ve export için | GitHub releases (godotengine/godot) |
| Godot export şablonları | Linux'tan Windows .exe derlemek | Aynı sürümün GitHub release'i |
| GDScript | Tüm oyun kodu | — |
| Blender (Python `bpy`) | Low-poly modeller, 8 yönlü sprite render'ı, normal map | `pip install bpy` |
| Python + numpy + Pillow | Sprite sheet paketleme, ses efekti sentezi | pip |
| GitHub | Kod deposu; kullanıcının GitHub bağlantısı varsa repo onunla açılır | Kullanıcının hesabı |

Çalışma ortamında GitHub ve paket depoları dışındaki sitelere erişim olmayabilir. Bir araç kurulamıyorsa durum kullanıcıya söylenir ve dosyayı kendisinin eklemesi istenir.

**Repo adı:** `zindan-oyunu` (oyunun adı belirlenince değiştirilir).

```
zindan-oyunu/
  project.godot
  export_presets.cfg      # Windows Desktop ön ayarı
  Makefile
  README.md               # nasıl derlenir, nasıl oynanır
  docs/GDD.md             # bu dokümanın kopyası
  data/                   # tüm denge sayıları (JSON)
  scenes/                 # main_menu, race_select, game, player, enemies, bosses, rooms, ui
  scripts/
    autoload/             # Events, DataDB, GameState, SaveManager
    combat/               # DamageCalc, StatusEffects, Combos
    player/  enemies/  bosses/
    dungeon/              # DungeonGenerator, RoomController
    loot/                 # LootGenerator, Inventory
    progression/          # Leveling, Mastery, Rewards
  assets/                 # sprites, normals, audio/sfx, audio/music, fonts, shaders
  tools/
    blender/render_sprites.py
    audio/sfx_synth.py
  tests/                  # headless birim testleri
  build/                  # export çıktıları (git'e girmez)
```

| Make hedefi | Ne yapar |
| --- | --- |
| `make test` | Godot'u headless çalıştırıp `tests/` içindeki tüm testleri koşar |
| `make sprites` | Blender script'iyle tüm sprite ve normal map'leri yeniden üretir |
| `make sfx` | Ses efektlerini sentezleyip `assets/audio/sfx` içine yazar |
| `make export-windows` | `build/windows/` içine .exe üretir ve zip'ler |
| `make all` | Hepsini sırayla çalıştırır |

### Mimari ve Veri

Oyun veri odaklıdır: denge sayılarının hiçbiri koda yazılmaz, hepsi `data/` altındaki JSON dosyalarından okunur. Yeni silah ya da düşman eklemek bir JSON kaydı eklemektir.

| Dosya | İçerik | GDD kaynağı |
| --- | --- | --- |
| `races.json` | Can, hız, zırh, kaynak, Q/E, pasif | Irklar, Skill Sistemi |
| `race_weapon_matrix.json` | Irk-silah ailesi ceza ve bonusları | Irklar |
| `weapon_types.json` | 12 tip: aile, hız, menzil, çarpan, sağ tık | Skill Sistemi |
| `rarities.json` | Temel hasar, element/özellik sayısı | Nadirlik |
| `loot_tables.json` | Kat bazında nadirlik oranları ve silah levelleri | Nadirlik, Zindan |
| `elements.json` | 6 element, durum etkileri, 7 kombo | Elementler |
| `traits.json` | 5 özellik | Elementler |
| `legendaries.json` | Efsanevi silahlar ve pasifleri | Nadirlik |
| `talismans.json` | 3 tılsım | Rezonans ve Esnek Slot |
| `enemies.json` | 17 düşman, rol, bağışıklık, XP | Düşmanlar |
| `bosses.json` | 4 boss, fazlar, saldırılar | Boss'lar |
| `rewards.json` | Level ve boss ödül havuzları | Run İçi Ödüller |
| `progression.json` | XP eğrisi, ustalık eğrisi, derinlik çarpanları, stat tavanları | Level, Ustalık, Denge |
| `floors.json` | 4 kat: tema, oda sayıları, düşman havuzu | Zindan, Run Süresi |

**Autoload'lar:** `Events` (sinyal merkezi), `DataDB` (JSON'ları yükler ve doğrular), `GameState` (aktif run: level, çanta, slotlar, buff'lar), `SaveManager` (kalıcı veri: ustalıklar, boss ilk kesişleri; `user://save.json`).

**Hasar formülü:** Tüm hasar tek bir `DamageCalc` fonksiyonundan geçer ve birim testleriyle korunur.

```latex
\text{Hasar} = T \times \text{Ç} \times (1+L) \times (1+U) \times (1+B) \times E \times K \times A \times (1-Z)
```

| Terim | Anlam |
| --- | --- |
| T | Nadirlik temel hasarı (100 / 125 / 175 / 260) |
| Ç | Silah tipi hasar çarpanı |
| L | Silah level oranı (her 5 levelde yenilenir: 0,05 … 0,80) |
| U | Ustalık hasar bonusu (level × 0,05) |
| B | Toplam hasar buff'ları, kendi aralarında toplanarak: level ve boss ödülleri, ilk kesiş bonusu, Öfke, ırk-silah cezası |
| E | Element çarpanı = durum çarpanı × (1 + element hasarı bonusları) |
| K | Kritikse 1,5 + kritik hasarı bonusları, değilse 1 |
| A | Karanlık silahla arkadan vuruşta 1,1, diğer durumlarda 1 |
| Z | Hedefin zırhı / hasar azaltması (tavan %75) |

**Dokümanda söylenmeyen ayrıntılar için varsayılanlar:**

- Elementli bir silahın tüm hasarı o elementtir; yaygın silahlar fizikseldir.
- Durum çarpanı: bağışık 0 (yaygın silah hayalete 0,25), dirençli 0,5, normal 1, zayıf 1,5.
- Temel kritik şansı %5.
- Yanma: 3 sn, saniyede vuruş hasarının %20'si. Zehir: yığın başına 4 sn, saniyede %8, maks 5 yığın. Islak ve Gölge işareti: 4 sn. Buz: yığın başına %10 yavaşlatma, 5 yığında 1,5 sn donma. Yıldırım: 2 hedefe %50 hasarla sıçrar.
- Rezonans hasarı = kilitli silahın T × Ç × (1+L) değerinin %10'u (açıksa %7'si), onun elementiyle; oyuncunun buff'larından etkilenmez.
- Esnek slottaki silah: özelliklerinin ve efsanevi pasifinin sayısal değerleri %9 ile işler.
- Space atılması: 1 sn bekleme, ilk 0,2 sn dokunulmazlık.
- Saldırı hızı = tipin saldırı/sn değeri × (1 + hız bonusları), tavanlara uyar.

### Yapım Aşamaları 0-5

#### Aşama 0 — Ortam ve iskelet

1. Godot 4'ün Linux headless sürümünü ve aynı sürümün export şablonlarını GitHub'dan indir; `godot --version` ile doğrula.
2. `pip install bpy numpy pillow --break-system-packages`. `bpy` kurulamazsa not al; Aşama 8'e kadar gerekmiyor.
3. Repo iskeletini kur. `project.godot`: 1920×1080 pencere, canvas\_items stretch, Y-sort. Input map: WASD, sol/sağ tık, Q, E, Space, Tab, 1, F.
4. Autoload iskeletleri ve `data/` JSON dosyalarını oluştur; `DataDB` eksik ya da hatalı alanda açık bir hata versin.
5. Headless test çalıştırıcısını (`tests/run_tests.gd`) ve Makefile'ı yaz.
6. Windows Desktop export ön ayarını kur; `make export-windows` ile .exe üret ve zip'le.
7. GitHub reposunu aç, README yaz, push et.

**Kabul:** `make test` geçer; boş pencere açan .exe kullanıcının Windows'unda çalışır.

#### Aşama 1 — Vuruş hissi prototipi

1. İzometrik TileMap ile tek oda (renkli placeholder karolar), çarpışmalı duvarlar ve sütunlar.
2. Oyuncu: WASD ile 8 yön, fareye bakma, Space atılması.
3. Kılıç: sol tık yay şeklinde vuruş, sağ tık Dönen kesik.
4. İskelet Savaşçı: takip ve saldırı yapay zekâsı, can barı.
5. Vuruş hissi: 60 ms hitstop, ekran sarsıntısı, beyaz flaş shader'ı, uçan hasar sayıları, kıvılcım partikülü, geri savrulma.
6. Can, ölüm ve yeniden başlama.

**Kabul:** Kullanıcı .exe'de odayı temizler ve vuruşların iyi hissettirdiğini onaylar; onaylamazsa bu aşamada ayar yapılır.

#### Aşama 2 — Savaş çekirdeği

1. `DataDB`'yi elements, traits, weapon\_types, rarities ve 1. kat enemies ile doldur.
2. `DamageCalc`: hasar formülü ve her terim için birim testi (bağışık = 0, yaygın silah hayalete %25, kritik, arkadan vuruş, zırh tavanı).
3. `StatusEffects` ile 6 element durumu; `Combos` ile 7 kombo (ilk element tüketilir, boss donmadan sonra 8 sn bağışık).
4. 5 özellik: Öfke, İnfaz (boss'ta %3), Can Emme, Sekme, Sersemletme.
5. Düşmanın üstünde bağışıklık ikonu.

**Kabul:** Tüm testler geçer; test odasında kombolar görsel olarak tetiklenir.

#### Aşama 3 — Irklar ve silahlar

1. 4 ırk: statlar, Q/E yetenekleri, kaynaklar (enerji, mana, bekleme süresi), Ghost'un iyileşme kuralı.
2. 12 silah tipinin normal ve sağ tık saldırıları (placeholder görsellerle).
3. İki aktif slot ve Tab; ırk-silah matrisi; Magical dışındaki ırkta büyü silahı beklemesi ×1,5.
4. Geçici hata ayıklama menüsü: ırk, silah ve element seçip deneme.

**Kabul:** Her ırk × silah tipi kombinasyonu hata ayıklama odasında denenebilir.

#### Aşama 4 — Zindan üretimi

1. `DungeonGenerator`: kat başına oda grafiği (oda sayıları Run Süresi tablosundan), başlangıçtan boss'a; elit, tüccar, demirci, sandık ve gizli odaların yerleşimi.
2. 6-8 elle çizilmiş oda şablonu ve rastgele engel yerleşimi; her run yeni seed.
3. Oda akışı: girince kapılar kilitlenir, düşman dalgaları gelir, temizlenince açılır. Savaş dışında slot değişimi serbest.
4. 4 katın placeholder renk paletleri ve katlar arası geçiş.
5. Testler: aynı seed aynı haritayı üretir, her odaya ulaşılabilir.

**Kabul:** 4 kat baştan sona yürünebilir.

#### Aşama 5 — Loot ve envanter

1. `LootGenerator`: kat nadirlik tablosu, tip, element, özellik, kat silah leveli aralığı, efsanevi 3. kattan itibaren.
2. Silah leveli, yetişme XP'si ve kilitli silahlar.
3. Çanta ve 4 slot (2 aktif, Rezonans, Esnek); sürükle-bırak arayüz; stat karşılaştırmalı tooltip.
4. Altın, tüccar (al-sat, iksir), demirci (level atlatma, stat yeniden çekme), iksir sistemi.
5. Nadirliğe göre loot ışık sütunları.

**Kabul:** 10.000 düşüşlük simülasyon testinde oranlar tabloya ±%1 uyar; envanter oynanabilir.

### Yapım Aşamaları 6-10

#### Aşama 6 — İlerleme

1. Oyuncu XP ve leveli (XP eğrisi formülü), düşman XP'leri.
2. Her 5 levelde level havuzundan 2 seçenekli ödül ekranı; tavana ulaşan stat havuzdan çıkar.
3. Boss ödülü: 1 büyük stat + 1 özel etki seçeneği.
4. Ustalık: hasar payına göre XP, derinlik çarpanı, 12 levellik eğri ve bonuslar; run sonu özet ekranı.
5. `SaveManager`: ustalıklar ve boss ilk kesişleri; bozuk kayıt dosyasına dayanıklı.
6. Stat tavanları.

**Kabul:** Testlerde kat XP toplamları hedef levellere birebir uyar ve ustalık eğrisi 114 referans maç tutar. Run sonunda ustalık kaydedilir, oyun yeniden açılınca korunur.

#### Aşama 7 — Düşmanlar ve boss'lar

1. 17 düşman, rolüne göre durum makinesi yapay zekâsı ve elit sürümleri.
2. 4 boss: saldırılar, yerde kırmızı uyarı işaretleri, özel mekanikler, 2. fazlar, boss can barı.
3. Kat bazında düşman güç ölçeklemesi.

**Kabul:** Her boss yenilebilir ve tüm saldırıları önceden işaretlidir.

#### Aşama 8 — Sanat

1. `tools/blender/render_sprites.py`: karakterleri koddan low-poly modelle; bekleme, yürüme, saldırı, hasar alma ve ölüm animasyonları.
2. Ortografik izometrik kamera, 8 yön, toon benzeri gölgeleme; renk ve normal geçişleri ayrı render.
3. Pillow ile sprite sheet paketleme; Godot'da normal map'li CanvasTexture ve meşaleler için PointLight2D.
4. 4 katın karo setleri ve dekorları: damar ve gözler, mantarlar, lav kanalları, boşluk platformları.
5. Shader'lar: flaş, eriyerek ölme, outline, sis, lav ve su.
6. Silah ve tılsım ikonları, nadirlik renk çerçeveleri.

Önce tek bir ırkın karakteri yapılıp kullanıcıya gösterilir; tarz onaylanınca diğerlerine geçilir.

**Kabul:** Kullanıcı görsel tarzı onaylar ve tüm placeholder'lar değişir.

#### Aşama 9 — Ses

1. `tools/audio/sfx_synth.py`: vuruş, kritik, atılma, element başına sesler, kombo, nadirliğe göre loot, level atlama ve arayüz sesleri.
2. Müzik: kat başına ambient döngü ve boss müziği. Sentez yeterli olmazsa kullanıcıdan ücretsiz lisanslı müzik dosyaları istenir.
3. Ses kanalları ve ses seviyesi ayarları.

**Kabul:** Kullanıcı onayı.

#### Aşama 10 — Menüler, denge ve teslim

1. Ana menü, ırk seçimi, duraklatma menüsü, "Kazandın" ve run özeti ekranları.
2. Denge: otomatik simülasyonla kat başına ortalama süre ve level; ardından kullanıcı testleri.
3. 60 FPS hedefiyle performans ve hata düzeltmeleri.
4. Final .exe, README ve GitHub'da `v0.1` sürüm etiketi.

**Kabul:** Kullanıcı oyunu baştan sona oynar.

### Çalışma Kuralları ve Teslim

- **Tek kaynak bu doküman.** Bir tasarım kararı değişecekse önce kullanıcıya sorulur; onaylanan değişiklik hem `data/` dosyalarına hem `docs/GDD.md`'ye işlenir.
- **Her aşama sonunda:** `make test` → `make export-windows` → .exe zip'ini kullanıcıya gönder → GitHub'a push → kullanıcıya 3-5 maddelik "şunları test et" listesi.
- **Test Windows'ta kullanıcıda yapılır.** Hata raporu için log dosyası `%APPDATA%\Godot\app_userdata\<proje adı>\logs` altındadır.
- **Önce placeholder, sonra sanat.** Oynanış Aşama 7'ye kadar renkli şekillerle yapılır; sanat Aşama 8'de gelir.
- **Kod:** GDScript'te statik tipler, her script'in başında kısa bir açıklama, koda gömülü denge sayısı yok.
- **Git:** Her aşama kendi branch'inde (`asama-0`, `asama-1` …), bitince `main`'e merge edilir; commit mesajları Türkçe ve anlamlıdır. Kullanıcı Git öğreniyor: branch, commit ve merge adımları kısaca açıklanır.
- **Oturumlar arası devamlılık:** README'nin "Durum" bölümü her aşama sonunda güncellenir (bitmiş aşamalar, kalınan adım, bilinen hatalar); yeni sohbet oradan devam eder.
- **Açık kararlar** (oyunun adı, Ghost'un iksir kuralı, kalan 16 boss, hikâye, ayrıntılı arayüz) oyunun yapımını engellemez; ilgili aşamaya gelindiğinde kullanıcıya sorulur.
