# Pari: ürün ve mühendislik incelemesi

11 Eylül 2026 · İncelenen proje: `/Users/ahmet/Pari`

**Ana değerlendirmem:** Pari'nin önündeki en yakın engel, Vivino'nun büyüklüğünden önce, mevcut parçaların güvenilir ve anlaşılır bir ilk kullanım deneyiminde birleşmemesi. Şu an yeni özellik eklemekten daha yüksek getirili iş, dar bir kullanıcı ihtiyacını seçip bunun baştan sona çalışmasını sağlamak. Native iOS uygulamasını veya Supabase altyapısını baştan yazmak için bir gerekçe görmedim.

Bu değerlendirme bir pazar başarısı garantisi değildir. Kod, ürünün nasıl çalışmak istediğini gösteriyor; insanların tekrar kullanmak veya para ödemek isteyeceğini henüz göstermiyor.

**İncelemenin kapsamı ve kanıt düzeyi**

Dosya ağacı, iOS giriş/navigasyon akışları, kayıt/düzenleme, tarama, öneriler, mahzen, grup oturumları, sosyal servisler, veri ithalatı, migration zinciri, Edge Functions, önbellekler ve test kapsamını inceledim. Kritik bulgularda ekran → servis → SQL yolunu izledim. Projede 51 migration, iki Edge Function ve altı Swift test dosyası var.

Bu konuşmanın önceki çalıştırmasında mevcut iOS kodu derlendi ve **42/42 test geçti**. Bu incelemede Python değerlendirme betiğinin **16 metrik kontrolü geçti**. Bunlar model kalitesini veya canlı backend'i doğrulamıyor.

Docker servisi çalışmıyordu. Üç SQL sorununu, asıl migration dosyalarından alınan ilgili şema/policy parçalarını ve sentetik kullanıcıları kullanarak **PGlite 0.5.8 üzerinde izole PostgreSQL deneylerinde** yeniden ürettim. Dört kontrol: mahzen upsert hatası; oturum üyeliği SELECT hatası; masadan ayrılma DELETE hatası; arkadaşlara özel kaydın arkadaş olmayan kullanıcı tarafından okunması. Bu, bütün Supabase migration zincirinin veya gerçek proje ayarlarının yeniden test edildiği anlamına gelmez.

[Deney sonuçları](/Users/ahmet/Pari/docs/reviews/2026-09-11/sql-reproductions.json) · [Yeniden üretme betiği](/Users/ahmet/Pari/docs/reviews/2026-09-11/sql-reproduce.mjs). Betik `@electric-sql/pglite@0.5.8` kurulu geçici bir klasöre kopyalanıp çalıştırılabilir; canlı backend bağlantısı kullanmaz.

Canlı Supabase şemasını, kullanıcı verilerini ve dağıtılmış Edge Functions durumunu incelemedim. Bu turda bilgisayar kullanım izinleri tamamlanmadığı için bütün ekranları etkileşimli olarak gezemedim; görsel gözlemler önceki simülatör çalıştırmasında görülen giriş/ana ekran ile sınırlı. Aşağıdaki kaynak bulguları, migration'ların tarif ettiği davranışla ilgilidir; gerçek backend farklı olabilir.

**1. Ürünün başarı ölçüsünü değiştirirdim**

Vivino ile bütün özelliklerde yarışmak, küçük bir ekibin iş listesini sürekli büyütür. Pari için başlangıçta seçilecek daha yararlı bir hedef: şarap sevip uzman olmak istemeyen birinin, sevdiği şarapları hatırlamasını ve bir sonraki gerçek seçim anında daha rahat karar vermesini sağlamak.

Önerdiğim ürün cümlesi: **“Beğendiğin şarapları hatırla. Bir sonraki seçimini kendi zevkine göre yap.”** Bu bir konumlandırma hipotezi; tek başına benzersizlik iddiası değil.

Vivino'nun güncel geliştirici açıklamasında etiket/menü tarama, kişisel Match for You, kişisel günlük ve içim pencereli mahzen zaten var. Dolayısıyla README ve SQL yorumlarındaki bazı “Vivino bunu yapamaz” gerekçeleri sağlam değil. Özellikle bir şirketin satış modeli, grup önerisini teknik olarak yapamayacağını göstermez. [Vivino'nun resmi mağaza açıklaması](https://play.google.com/store/apps/details?id=vivino.web.app&hl=en).

Pari'nin denenmeye değer yaklaşımı, daha kısa bir iş akışı ve kullanıcının kendi geçmişine dayanan açıklamalar olabilir. Kullanıcının Vivino'yu tamamen bırakmasını gerektirmeyen, yanında kullanabileceği bir ürün tasarlamak da mümkün. Bu yaklaşımı görüşme ve kullanım gözlemleriyle sınamak gerekir.

Ben ilk sürümde üç işi bir araya getirirdim:

1. Bir şarabı hızla kaydet: fotoğraf veya arama, kısa tepki, isteğe bağlı not.
2. Sonradan hatırla: hangi şarap, hangi yıl, hangi bağlam ve neden sevildi.
3. Bir seçim anında geçmişi kullan: eldeki birkaç şişe veya mevcut menü içinden gerekçeli birkaç seçenek.

Grup modu bu döngünün ikinci aşamada genişlemesi olur. Kullanıcı tek başınayken de değer görmeli; arkadaş kurmak, başkalarına uygulama yükletmek veya uzun bir puan geçmişi oluşturmak ilk faydanın şartı olmamalı.

**2. Korumaya değer mühendislik kararları**

- SwiftUI ve Supabase ile operasyon yükünü küçük tutan bir yapı var. Bu aşamada yeni backend framework'ü veya mikroservisler önermiyorum.
- Şarap kataloğu ile kullanıcının içtiği şişenin vintage bilgisinin ayrılması doğru yönde. Bu, kişisel hafızanın doğruluğu için önemli.
- Liste taramasında eşleşmeyen şarapların korunması, kullanıcıya eksikleri göstermeyi mümkün kılıyor. Bu davranış korunmalı.
- Anthropic anahtarını sunucuda tutmak, tarama için kullanıcı doğrulamak ve kota kontrolü başarısız olunca isteği durdurmak iyi temeller.
- Yapısal tadım verisinin isteğe bağlı olması, meraklı kullanıcıya derinlik sunarken temel kaydı sade tutmaya elverişli.
- Ortak tema, bağımsız sıralama matematiği ve mevcut testler geliştirmeye devam etmek için kullanılabilir bir temel.

**3. İlk kullanıcı deneyimi: değer çok geç geliyor**

Normal başlangıç yaş kapısı, telefon/e-posta doğrulaması ve profil kurulumundan geçiyor. Ana tab sosyal ekran; feed'in varsayılan sekmesi Global. Zevk kalibrasyonu mevcut profil kurulumunun parçası değil. [RootView](/Users/ahmet/Pari/Pari/Features/Root/RootView.swift:27), [FeedViewModel](/Users/ahmet/Pari/Pari/Features/Social/FeedViewModel.swift:50), [ProfileSetupView](/Users/ahmet/Pari/Pari/Features/Auth/ProfileSetupView.swift:40).

Önerim: ana ekranda “Şarap kaydet”, “Önceki şaraplarım” ve “Bir seçim yap” gibi anlaşılır işler. Yeni kullanıcı örnek bir listeyle veya kendi ilk kaydıyla hemen ilerleyebilmeli. Hesap, senkronizasyon/kaydı koruma/paylaşım için anlamlı bir anda istenebilir. Bunun için gerçek bir misafir veri modeli gerekir; bu konuşmada eklediğimiz `--bypass-login` yalnızca ekran önizlemesidir ve böyle bir ürün akışı sağlamaz.

Puan kaydını yalnızca 1–10 ölçeğine bağlamazdım. “Tekrar seçerim / Emin değilim / Bana göre değil” gibi daha kolay bir ilk tepkiyi deneyip sayısal puanı isteğe bağlı açardım. Bunun öneri motoruna nasıl eşleneceği açıkça tanımlanmalı; tepkiyi gelişi güzel 10 veya 1'e çevirmek veri kalitesini bozabilir.

Özel bir günlük yönü seçilirse **“Yalnızca ben”** görünürlüğü de gerekir. Şu an modellerde yalnızca Public ve Friends Only var; varsayılanlar herkese açık. Bu bir ürün kararıdır ve mevcut sosyal ürün varsayımlarını değiştirir.

**4. Yayın öncesi öncelikli doğruluk ve güven sorunları**

| Öncelik | Kaynak bulgusu | Kullanıcıya etkisi | Önerilen düzeltme |
|---|---|---|---|
| P1 | Friends Only, tadım okuma policy'sinde ve son feed RPC'lerinde kontrol edilmiyor | Profili herkese açık birinin arkadaşlara özel tadımı başkalarına görünür | Profil, tadım ve engelleme görünürlüğünü tek yetkilendirme kuralında birleştir; doğrudan tablo, view, RPC ve görsel erişimini birlikte test et |
| P1 | `compute_user_taste_profile(uuid)` SECURITY DEFINER ve authenticated rolüne açık; çağıranın hedef kişi olduğunu kontrol etmiyor | Kullanıcı başka birinin zevk vektörünü isteyebilir | İç yardımcıyı dış API'den çıkar; doğrudan EXECUTE izinlerini kapat; kendi profilini ve grup üyeliğini doğrulayan wrapper'ları kullan |
| P1 | Katalog UPDATE policy'si bütün authenticated kullanıcılar için `USING(true)` | Standart tablo izinleriyle herhangi bir oturum ortak katalog satırlarını değiştirebilir | Katalog düzeltmelerini sınırlı alanlı, doğrulanmış RPC veya moderasyon kuyruğuna taşı |
| P1 | Hesap silmenin son SQL tanımı yalnızca `deleted_at` yazıyor | Arayüzün “kalıcı olarak silinir” sözü gerçekleşmiyor | Sunucuda tamamlanan silme işi, saklama süresi davranışı, Storage ve log temizliği; UI metni gerçek işlemle aynı olmalı |
| P1 | Düzenleme ekranındaki görünürlük ve yapısal tadım değerleri update çağrısına gönderilmiyor | Kullanıcı kaydettiğini düşündüğü değişikliği kaybetmiş oluyor | Decode ve update sözleşmesine alanları ekle; kaydet → yeniden yükle testi |
| P1 | Tadım ve feed kaydı iki ayrı ağ işlemi | İkinci işlem hata verirse tadım kaydolmuş olsa bile kullanıcı hata görür; tekrar deneme çift kayıt oluşturabilir | Tek transaction/RPC; istemci işlem kimliğiyle tekrarları güvenle karşıla |
| P1 | Feed cache anahtarları hesap kimliği içermiyor ve çıkışta temizlenmiyor | Aynı cihazda farklı hesap, önceki hesabın önbelleğe alınmış içeriğini görebilir | Hesap bazlı cache anahtarı; çıkış, hesap değişimi ve gizlilik değişiminde temizleme |

Friends Only sorununu sentetik iki kullanıcıyla yeniden ürettim: A'nın profili `everyone`, tadımı `friends`; B ile arkadaş değiller. B rolüyle doğrudan SELECT, tadımı döndürdü. Son feed RPC'leri de yalnızca profil görünürlüğünü kontrol ediyor. [Tadım policy'si](/Users/ahmet/Pari/supabase/migrations/20250801000000_privacy_rls_feed_audit.sql:109), [son feed filtresi](/Users/ahmet/Pari/supabase/migrations/20260803000000_tasting_vintage.sql:204).

İlgili diğer kaynaklar: [zevk vektörü fonksiyonu](/Users/ahmet/Pari/supabase/migrations/20260803000010_fix_vector_cast.sql:31), [katalog policy'si](/Users/ahmet/Pari/supabase/migrations/00000000000000_baseline_base_tables.sql:122), [son hesap silme tanımı](/Users/ahmet/Pari/supabase/migrations/20250801000000_privacy_rls_feed_audit.sql:342), [silme ekranının sözü](/Users/ahmet/Pari/Pari/Features/Profile/DeleteAccountView.swift:80), [düzenlemenin gönderdiği alanlar](/Users/ahmet/Pari/Pari/Features/Wine/WineCardView.swift:562), [iki aşamalı kayıt](/Users/ahmet/Pari/Pari/Services/TastingService.swift:100), [feed cache anahtarları](/Users/ahmet/Pari/Pari/Services/FeedService.swift:31).

Görünürlük alanı `TastingRow` select/decode yolunda da yok; yeniden okunan nesne varsayılan Public oluyor. Güncelleme çağrısı görünürlük göndermediği için bu bulgu, tek başına “düzenleme özel kaydı public'e çeviriyor” anlamına gelmez; görünürlük hem yanlış gösteriliyor hem de düzenlemeden kaydedilemiyor. [Select sözleşmesi](/Users/ahmet/Pari/Pari/Services/TastingService.swift:15), [varsayılan değer](/Users/ahmet/Pari/Pari/Models/Tasting.swift:56).

Moment görselleri public bucket'a yükleniyor ve herkese açık URL üretiliyor. Kaydın metnini friends-only yapmak görsel URL'sini özel yapmaz. Paylaşım yetkisine bağlı imzalı URL veya eşdeğer kontrollü erişim gerekir. Hesap silme yolunda yalnızca avatarın istemciden silinmesi deneniyor; moment görselleri ve öneri logları için tamamlanmış temizlik göremedim. [Bucket](/Users/ahmet/Pari/supabase/migrations/20260318000000_tastings_moment_image.sql:5), [yükleme](/Users/ahmet/Pari/Pari/Services/MomentStorageService.swift:17).

Ayrıca `feed_with_details` son migration'da `security_invoker` olmadan oluşturuluyor. Doğrudan API erişimi varsa view, RPC'deki filtreleri atlayabilir; gerçek proje grant'leri kontrol edilmeli. Supabase bunun için view yetkilerinin ve `security_invoker` seçeneğinin ayrıca ele alınmasını açıklıyor. [View tanımı](/Users/ahmet/Pari/supabase/migrations/20260803000000_tasting_vintage.sql:126), [Supabase RLS belgeleri](https://supabase.com/docs/guides/database/postgres/row-level-security).

**5. “Mahzen” özelliği henüz tam bir envanter değil**

My Cellar ekranı `TastingService.fetchTastings` kullanıyor: içilmiş şarapların geçmişini gösteriyor. `CellarBottleService.addBottles` ve `drinkOne` için uygulamada bir çağrı noktası bulamadım. Envanter SQL'i mevcut olsa da kullanıcı şişe adedini yönetemiyor. [CellarViewModel](/Users/ahmet/Pari/Pari/Features/Cellar/CellarViewModel.swift:43).

Bu servisi bağlamadan önce üç düzeltme gerekiyor:

- Upsert `user_id,wine_id,vintage` sütunlarını hedefliyor; tekil indeks `COALESCE(vintage,-1)` ifadesini içeriyor. İzole PostgreSQL deneyi **42P10** verdi. NULL vintage davranışıyla uyumlu indeks/constraint ve RPC tasarlanmalı. [İstemci](/Users/ahmet/Pari/Pari/Services/CellarBottleService.swift:131), [indeks](/Users/ahmet/Pari/supabase/migrations/20260803000013_cellar_bottles.sql:50), [PostgreSQL ON CONFLICT açıklaması](https://www.postgresql.org/docs/current/sql-insert.html).
- `addBottles` mevcut miktara eklemek yerine verilen miktarla üzerine yazıyor. “2 şişe daha ekle” ile “toplamı 2 yap” ayrı işlemler olmalı.
- `drinkOne` önce miktarı okuyor, sonra azaltılmış değeri yazıyor. Eşzamanlı işlemler aynı eski değeri okuyabilir. Sunucuda atomik azaltma ve sıfır sınırı gerekir.

Ürün tarafında “İçtiklerim”, “Denemek istediklerim” ve “Evde olanlar” ayrımını netleştirirdim. İlk sürümün odağı kişisel hafızaysa envanteri sonraya bırakmak da geçerli bir seçim.

İçim penceresi şu an üzüm/yapısal özelliklerden hesaplanan bir sezgisel formül. Kaynakta `is_estimate` üretiliyor fakat `open_tonight` cevabı ve Swift modeli bunu taşımıyor; ekranda “Past its window” gibi kesin etiketler var. Bu veriyi saklama koşulu, üretici ve vintage doğrulaması olmadan kesin tarih gibi göstermemek gerekir. Önerim açık “tahmini” etiketi, kaynak, belirsizlik ve kullanıcı düzeltmesi. [Formül](/Users/ahmet/Pari/supabase/migrations/20260803000013_cellar_bottles.sql:108), [etiket](/Users/ahmet/Pari/Pari/Services/CellarBottleService.swift:33).

**6. Grup modu: fikir ile masadaki deneyim arasındaki boşluk**

Grup öneri fonksiyonu katalogdan aday buluyor; taranan menüdeki şaraplar, bütçe ve kadeh/şişe tercihi parametreleri yok. Restoranda bulunmayan iyi bir öneri, o andaki seçimi çözmüyor. Menü taramasıyla grup oturumunun ortak bir aday listesi kullanması gerekir. [Grup aday havuzu](/Users/ahmet/Pari/supabase/migrations/20260803000011_tasting_sessions.sql:257).

Üyelik tablosunun SELECT policy'si aynı tabloyu tekrar sorguluyor. İzole deneyde hem SELECT hem uygulamanın kullandığı koşullu DELETE **42P17 / infinite recursion** hatası verdi. `leave` hatayı yutuyor ve ekran kapanıyor; ayrıldığını düşünen kullanıcı tabloda kalabilir. Güvenli bir üyelik helper'ı veya doğrulanmış leave RPC'si ve sonucu görünür kılan durum modeli gerekli. [Policy](/Users/ahmet/Pari/supabase/migrations/20260803000011_tasting_sessions.sql:57), [leave çağrısı](/Users/ahmet/Pari/Pari/Services/TastingSessionService.swift:186).

Host tarafındaki `memberCount` yaratılırken 1; yenileme yalnızca önerileri yüklüyor, oturum sayısını güncellemiyor. Başkaları katılsa da metin “kimse katılmadı” kalabilir. Üyelik değişimini gözleyen bir yenileme kanalı gerekir. [Oturum oluşturma](/Users/ahmet/Pari/Pari/Services/TastingSessionService.swift:77), [yenileme](/Users/ahmet/Pari/Pari/Features/Social/TastingSessionView.swift:51).

Tadımı olmayan üyeler hesaplamaya katılmıyor. Bu nedenle “herkese uygun” iddiası bütün masa için geçerli olmayabilir. Katkı veren kişi sayısı açık gösterilmeli; yeni katılımcı birkaç geçici tercih belirtebilmeli. Tam kayıt ve uygulama yükletmek yerine tek cihazdan tercih eklemeyi ilk deney olarak denerdim; web/QR katılımını daha sonra gerçek talebe göre kurardım. [Hesaba katılan üyeler](/Users/ahmet/Pari/supabase/migrations/20260803000011_tasting_sessions.sql:220).

Kosinüs benzerliği eşiği, kimsenin şarabı sevmeyeceği ihtimalini ortadan kaldırmaz. Ürün açıklaması matematiğin verebildiği güven düzeyinde kalmalı.

**7. Öneri motoru: önce geçerli ölçüm, sonra daha fazla model**

En belirgin değerlendirme hatası `eval_recommender_ndcg` içinde. Dış sorgu en yeni tadımları çıkarıyor gibi görünse de çağırdığı `compute_user_taste_profile(u.uid)` bütün kullanıcı geçmişini tekrar okuyor. Test için ayrılmış puanlar profilin içinde kalıyor. Ayrıca değerlendirme yalnızca embedding yakınlığı sıralıyor; üretimdeki `recommend_wines` ağırlıkları, taste-twin sinyali ve exploration davranışı test edilmiyor. [Holdout hatası](/Users/ahmet/Pari/supabase/eval/recommender_eval.sql:75), [değerlendirilen sıralama](/Users/ahmet/Pari/supabase/eval/recommender_eval.sql:96).

Önerim: zaman kesitine bağlı eğitim görünümü/snapshot; test verisinden etkilenmeyen şarap embedding'leri ve benzerlikler; üretim sıralayıcısını yan etkisiz çalıştıran ortak çekirdek. Basit popülerlik ve kategori tercihine karşı karşılaştırma yap. 0, 1–5 ve daha çok tadımı olan kullanıcıları ayrı ölç. Python metrik kontrollerinin geçmesi bu veri sızıntısını yakalamaz.

Şu an yüzde eşleşme, doğrudan kosinüs benzerliğinin yüzle çarpılması. Bu, “%85 ihtimalle seversin” şeklinde kalibre edilmiş bir olasılık değildir. Başlangıçta “sevdiğin şaraplara yakın; elimizde az veri var” gibi gerekçeli bir dil daha dürüst. [Gösterim](/Users/ahmet/Pari/Pari/Models/WineRecommendation.swift:59).

Profil ağırlığı 5.5'i nötr varsayıyor. Kullanıcıların kişisel puan ölçekleri farklı olduğunda bu varsayım ayrıca test edilmeli. Görece sert puanlayan birinin iyi bulduğu 5 puanlı şarap, mevcut formülde ters yönde katkı yapar. [Ağırlık](/Users/ahmet/Pari/supabase/migrations/20260803000010_fix_vector_cast.sql:55).

Tadım oluştururken taste-vector cache temizleniyor; düzenleme/silmede aynı invalidation yok. Bir kullanıcının fikrini değiştirmesi önerilere zamanında yansımalı. SQL'in döndürdüğü `discovery` nedeni de Swift enum'unda ayrı karşılanmıyor. Bu ayrıntılar model karmaşıklığından daha önce düzeltilmeli.

**8. Sessiz hatalar ürün kararlarını da yanıltıyor**

Öneriler, koleksiyonlar ve mahzen servisleri başarısız olduğunda boş dizi döndürüyor. For You bunu “henüz öneri yok” olarak gösterebiliyor. Grup ekranı öneri hatasını “kimse yeterince şarap puanlamadı” mesajına dönüştürüyor. Kullanıcıya yanlış teşhis konduğu gibi geliştirici de backend sorununun yerine kullanıcı/veri eksikliğine çözüm üretmeye başlayabilir. [For You yükleme](/Users/ahmet/Pari/Pari/Features/Social/ForYouView.swift:23), [grup hata yolu](/Users/ahmet/Pari/Pari/Features/Social/TastingSessionView.swift:56).

`loading / content / genuinelyEmpty / failed / stale` durumları ayrı taşınmalı. UI sade kalabilir: son başarılı sonucu koru, tekrar deneme sun, hata kodunu kişisel veriden arındırarak kaydet.

PostHog şu an kapalı. Önce küçük bir olay seti yeterli: ilk başarılı kayıt, tarama sonucu onayı/düzeltmesi, kararın tamamlanması, tekrar kullanım ve başarısız kayıt/tarama. Ürün analitiği ile operasyonel hata kaydı ayrı amaçlara hizmet eder. [AnalyticsConfig](/Users/ahmet/Pari/Pari/Core/AnalyticsConfig.swift:21).

**9. Katalog ve AI: büyüklükten önce doğru tanıma**

Yerel kaynak veri 100.646 satır; hazır import 100.472 şarap içeriyor. Kaynak CSV'de Turkey olarak işaretlenmiş yalnızca **57** şarap var. Bu canlı katalog sayısı değildir. Türkiye/Anadolu odaklı bir ilk kitle seçilecekse, üzüm taksonomisine Anadolu çeşitleri eklemek tek başına yeterli olmaz; gerçekten karşılaşılacak üretici ve şarapları doğrulamak gerekir.

Import kaynak kimliklerini, veri sürümünü ve provenance alanlarını çıktıya taşımıyor; deduplikasyon ad + üreticiye dayanıyor. İleride katalog birleştirme/düzeltme işlerini güvenilir yapmak için dış kaynak ID'si, normalize üretici/şarap kimliği ve alias kayıtları eklerdim. Etiket fotoğrafından çıkarılmış geçici bilgiyle doğrulanmış katalog bilgisini ayırırdım. [Import](/Users/ahmet/Pari/scripts/import_xwines.py:89).

Hazır importta 3.515 kategori boş. Bunun önemli bir kısmı, betiğin Dessert/Port ve Fortified türlerini bilinçli olarak boş bırakmasından kaynaklanabilir; her boşluk bozuk veri değildir. Dört kategorili modelin ürün kapsamı seçilen kitleye göre değerlendirilmeli. Şişe görselleri de bu importta yok; kartların görsel kalitesini katalog boyutu kendiliğinden çözmeyecek.

Tarama sonunda katalogya yazma, kullanıcı eşleşmeyi onaylamadan çalışıyor. İyi bir akış: görüntüden çıkar → katalog adaylarını getir → emin değilse doğrulat/düzelttir → onaylanan kaydı sakla. Liste taramasında OCR doğruluğu, katalog eşleştirme doğruluğu ve kişisel uygunluk üç ayrı güven ölçüsü olmalı. [Tarama ViewModel'i](/Users/ahmet/Pari/Pari/Features/Scan/WineLabelScanViewModel.swift:32).

Edge Functions için iyileştirmeler: JSON şemasını gerçekten doğrulamak, alan tiplerini ve vintage aralığını denetlemek, upstream timeout ve kesilmiş çıktı durumunu ele almak, bir menü taramasının 5 kota birimini tek atomik işlemde tüketmesi, tekrar isteklerini tanımak ve toplam harcama bütçesini izlemek. Şu an 5 birim ayrı çağrılarla tüketiliyor; kota ortasında biterse sonuç üretilmeden kısmi tüketim olur. [Kota döngüsü](/Users/ahmet/Pari/supabase/functions/wine-list-scan/index.ts:122), [çıktı işleme](/Users/ahmet/Pari/supabase/functions/wine-list-scan/index.ts:185).

**10. Sosyal alanlar ve şema bütünlüğü**

İstemcinin tablo/RPC adlarını migration tanımlarıyla taradım: çağrılan RPC adları zincirde bulunuyor; fakat **`blocks` ve `reports` tablolarının CREATE migration'ı yok**. Servisler artık klasörde bulunmayan bir manuel kurulum belgesine yönlendiriyor. `phone_hash` eski monolitik şemada var, migration zincirinde yok. Sıfırdan kurulmuş veritabanı, rehber eşleştirme ve moderasyon özelliklerini eksik bırakabilir. [BlockService](/Users/ahmet/Pari/Pari/Services/BlockService.swift:8), [ReportService](/Users/ahmet/Pari/Pari/Services/ReportService.swift:8), [rehber sorgusu](/Users/ahmet/Pari/Pari/Services/SocialDiscoveryService.swift:150).

Telefon hash'lerini geniş okunabilir `profiles` tablosunda tutmak ayrıca tasarım incelemesi gerektirir. Deterministik telefon hash'i tek başına anonimlik sağlamaz; özel eşleştirme endpoint'i, sınırlı sonuç ve kötüye kullanım sınırları tercih edilmeli. Bildirim/audit üreten SECURITY DEFINER fonksiyonları da `actor`/kullanıcı kimliğini istemci parametresinden almak yerine doğrulanmış oturumdan türetmeli.

Yeni tablolar eklemeden önce şema sözleşmesini tek kaynak yapardım: migration → boş test DB → gerekli tablo/sütun/RPC varlık testi → iki kullanıcıyla yetki testleri. “Bütün tabloların RLS'i açık” kontrolü yeterli değil; bu incelemede RLS açıkken hem erişim ihlali hem de kullanımı engelleyen recursion bulundu.

**11. UI tamamlanması, performans ve sürdürülebilir kod**

- Küratör koleksiyonlarının satırları HStack; içerik ekranına navigasyon yok ve `wines(in:)` çağrılmıyor. Koleksiyonların içinde şarap olsa bile kullanıcı ulaşamıyor. İçerik, neden seçildiği ve şaraba geçiş tamamlanmalı. [Koleksiyon satırı](/Users/ahmet/Pari/Pari/Features/Social/ForYouView.swift:208).
- Kişisel geçmiş varsayılan 100 kayıtla yükleniyor; CellarViewModel devam sayfası istemiyor. Kişisel hafıza ürünü seçilirse eski kayıtların erişilebilirliği temel gereksinim. Sunucu count sorgusu, kararlı cursor ve arama gerekir. [Geçmiş sorgusu](/Users/ahmet/Pari/Pari/Services/TastingService.swift:179).
- Feed oluşturma sonrasında birden fazla zenginleştirme sorgusu yapılıyor. Önce gerçek gecikmeleri ölç; sonra birbirinden bağımsız istekleri paralelleştir veya tek batch cevabında birleştir. Hemen dağıtık cache veya servisler kurmak gerekmiyor.
- Etiketli tab navigasyonu, tarama düğmesinin anlaşılır adı, Dynamic Type ve VoiceOver kontrolü gerekli. Başlıklar semantik font kullanıyor fakat genel `uiFont` sabit punto. Görsel stil korunurken erişilebilirlik iyileştirilebilir. [Tema fontu](/Users/ahmet/Pari/Pari/Themes/PariTheme.swift:262).
- Eski email/password/dev onboarding akışlarıyla yeni OTP/AuthStore akışı birlikte duruyor. Aktif olmayan akışları önce işaretle, sonra çağrı grafiği doğrulamasıyla azalt. Bütün mimariyi dönüştürmek yerine değiştirilecek servislerde küçük protocol sınırları kullan.
- Gerçek verili güvenilir demo için ayrı fixture/staging modu gerekir. Mevcut simülatör login bypass'ı kişisel veri üretmez, yetki isteyen işlevleri çalıştırmaz; dolayısıyla demo kalitesi veya backend testi sayılmaz.

**12. Önerdiğim geliştirme sırası**

Aşağıdaki sıra bir iş planı önerisidir; takvim taahhüdü değildir. Gerçek backend'in migration durumu ilk aşamanın süresini değiştirebilir.

| Aşama | Çıktı | Bittiğini nasıl anlarız? |
|---|---|---|
| 1 — Güvenilir temel | Staging/sentetik veri, görünürlük ve silme davranışı, tablo eksikleri, kayıt/düzenleme sözleşmesi | İki kullanıcıyla erişim sınırları; kayıt/düzenleme/silme sonrası yeniden yükleme; yarıda kalan isteğin güvenli tekrar denemesi |
| 2 — Tek kişinin ilk faydası | Kısa kayıt akışı, geçmiş, kolay geri bildirim, anlaşılır ana ekran | İlk kullanıcı yardım almadan bir şarabı kaydedip tekrar bulabiliyor; ağ kesilince kaydı kaybetmiyor |
| 3 — Gerçek bir seçim anı | Belirli aday liste, bütçe/kadeh tercihi, gerekçeli kısa öneri | Gerçek menüde bulunan şaraplardan seçim; yanlış eşleşmeyi düzeltme; belirsizliği gösterme |
| 4 — Küçük pilot | Yaklaşık 10–15 kişiyle doğal kullanım gözlemi | Sonraki doğal şarap seçim anında hatırlatmasız dönüş, seçimin işe yarayıp yaramadığı ve manuel alternatifle karşılaştırma |

Bu dönemde geniş sosyal ağ, marketplace, uzun özellik listesi, Android'e paralel açılma veya büyük bir AI sohbet asistanını önceliklendirmezdim. Küçük sosyal paylaşım ancak kişisel faydayı taşıdığı yerde eklenir: bir listeyi paylaşmak veya masada birkaç tercihi birlikte değerlendirmek gibi.

Pilot için önerdiğim ölçüler: ilk başarılı kayda ulaşma süresi, katalog eşleşmesini kullanıcıların ne sıklıkta düzelttiği, veri azlığında görev tamamlama, sonraki doğal kullanım fırsatında geri dönüş ve tavsiyenin sonradan yararlı bulunması. Bunlar henüz ölçülmüş sonuçlar değil. Çok içmeyi veya günlük uygulama açmayı başarı metriği seçmezdim.

Gelir modeli için de önce tekrar eden faydayı doğrulardım. İleride senkronize kişisel arşiv, dışa aktarma, gerçek envanter veya ortak seçim için ödeme isteği sınanabilir. Fiyat ve abonelik modelini şu aşamada varsaymak, ürün kararını kanıttan önce kilitler.

Başlangıç hedefim “Vivino'ya kaç özellik yaklaştık?” değil, **“Birkaç kişi gerçek bir şarap seçiminde Pari'yi kendi isteğiyle yeniden açtı mı?”** olurdu. Bu hedef, mevcut kodla ilerlenebilecek kadar somut; iyi çıkmazsa da hangi ürün varsayımını değiştirmek gerektiğini gösterecek kadar ölçülebilir.
