# Güvenilir şarap hafızası — ilk mühendislik teslimatı

Çalışma dalı: `codex/reliable-wine-memory`.
Talimat: [Çalışma prompt'u](reliable-wine-memory.md).

## Uygulanan davranış

- Arama ve etiket taramasından kaydetme, `create_tasting` RPC'sini çağırır.
  Sunucu tadımı ve feed gönderisini tek transaction içinde oluşturur. İlk
  başarılı yazım esas alınır; aynı UUID ile tekrar deneme aynı kaydı döndürür.
- Cevabı doğrulanmayan kayıt ekranında özgün taslak ve UUID korunur. Alanlar
  kilitlenir, “Retry Save” aynı girişimi tekrar gönderir. Fotoğraf yüklemesi
  başarısızsa hata gösterilir; fotoğraf sessizce atlanarak tadım kaydedilmez.
- Düzenleme puan, notlar, yorum, görünürlük, rekolte ve altı damak alanını
  birlikte saklar. Temizlenen alanlar NULL olur. Veri okunurken görünürlük
  zorunludur; eksik değer sessizce Public'e çevrilmez.
- Tadım silme, `tasting_id` ilişkisiyle bağlı feed kaydını kaldırır. Yakın
  zamanda içilmiş başka bir şarabı veya aynı şarabın başka kaydını saat tahminiyle silmez.
- Profil ve tadım görünürlüğü birlikte uygulanır. Doğrudan tablo, feed view,
  Global/Following RPC'leri ve etkileşimler RLS denetiminden geçer. Kullanıcı
  kimliği sunucudaki oturumdan gelir. İç damak profili fonksiyonunun doğrudan
  istemciden çağrılması kapatılır; yetkili sunucu wrapper'ları çalışmaya devam eder.
- Moment fotoğrafları özel bucket'tan kimliği doğrulanmış istekle indirilir.
  Eski public URL'ler yalnızca obje anahtarına çevrilir. Arkadaşlık kalkınca yeni
  okumalarda erişim kalkar. Zaten görülmüş/kopyalanmış bir fotoğraf geri alınamaz.
- Feed disk önbelleği kaldırılır, eski feed JSON'ları temizlenir. Supabase için
  disk HTTP önbelleği kullanılmaz. Hesap değişiminde profil temizlenir; eski
  oturumdan geciken feed/profil/fotoğraf yanıtları yeni oturuma uygulanmaz.
- Oluşturma, düzenleme ve silme sonrası damak önbelleği, yenileme bildirimi
  gönderilmeden önce geçersiz kılınır. Profil sayacı sunucunun tam sayımıyla
  yenilenir; tekrar kayıt denemesi sayacı iki kez artırmaz.

## Doğrulama ve pratik sınırlar

Swift testleri: mevcut 42 teste 9 regresyon testi eklendi; **51/51 geçti**.
Veritabanında **16 senaryo geçti** (Node parent dahil 17 test). Ayrıntılar ve tekrar çalıştırma
komutu [SQL testleri README'sinde](../../supabase/tests/README.md).

Bu çalışma canlı Supabase'e migration uygulamadı. Yeni istemcinin oluşturma ve
düzenleme işlemleri yeni RPC'leri gerektirir; backend güncellenmeden bu binary
dağıtılmamalı. Simülatörde açılması, kimliği doğrulanmış uçtan uca canlı kayıt
testinin yerine geçmez. Yerel login bypass yalnızca Debug simülatörün
`--bypass-login` argümanında geçerlidir ve sunucu yetkisi vermez.

Taslak/UUID ekran açıkken bellekte tutulur. Uygulama kapanınca devam eden kaydı
kurtaran kalıcı taslak kuyruğu bu teslimatın kapsamına dahil değildir. Upload
sonrası kullanıcı vazgeçerse kalan sahipsiz fotoğraflar için temizlik işi gerekir.
Belirsiz legacy feed/tadım eşleşmeleri veri silinmeden sahibine görünür bırakılır;
başkalarına tahmine dayanarak açılmaz.

## Dağıtım sırası

1. Staging'de mevcut migration geçmişini ve özel RLS/Storage politikalarını
   karşılaştır. Önce yedek ve temiz bir migration replay sonucu al.
2. Sırayla `20260911000000_atomic_tasting_writes.sql`,
   `20260911000001_tasting_visibility.sql` ve
   `20260911000002_private_moment_images.sql` dosyalarını uygula.
3. Yeni istemciyle iki gerçek kullanıcı ve bir üçüncü hesap üzerinde arama →
   kayıt → düzenleme → yeniden açma → silme akışını doğrula. Aynı kayıt UUID'sini
   paralel POST'larla ve yanıtı kesilmiş isteklerle tekrar dene.
4. Friends Only, tek taraflı takip, karşılıklı arkadaşlık ve arkadaşlıktan çıkma
   senaryolarını REST, iki feed RPC'si ve gerçek Storage dosya indirmesinde dene.
   Eski public fotoğraf URL'sinin artık anonim erişim vermediğini doğrula.
5. Embedding trigger'ları, `get_my_taste_profile` ve grup öneri wrapper'larının
   canlıdaki şemayla çalıştığını kontrol et. PGlite bu pgvector yollarını sınamaz.
6. Migration'lar ve uyumlu istemci birlikte yayınlanmalı. Eski istemcilerin public
   fotoğraf bağlantıları kapanır; minimum desteklenen sürüm buna göre belirlenmeli.
   Sorun çıkarsa fotoğraf yüzeyi geçici kapatılabilir; bucket'ı tekrar public yapma.

## Sonraki ürün adımı

Bu temel staging'de doğrulandıktan sonra 10–15 kişilik pilotta tek döngüyü ölç:
ilk şarabını kaydetme → başka gün kaydına dönme → bir sonraki şarap seçimine
yardım alma. Yeni sosyal özelliklerden önce “kaydettiğim bilgi gerçekten işime
yaradı mı?” sorusunu çöz. Hesap silme, katalog yazma izinleri, grup politikaları,
fiziksel şişe sayımı ve öneri değerlendirmesi önceki incelemedeki açık işlerdir.
