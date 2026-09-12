# Şişe envanteri — ikinci mühendislik teslimatı

Çalışma talimatı: evdeki şişeleri ekleme → sayıyı görme → açılan şişeyi düşme
döngüsünü kullanılabilir hale getir. Her stok değişikliğini tek transaction ile
ve tekrar denemeye dayanıklı olarak uygula. Çalışan dilimleri test edip
`codex/reliable-wine-memory` dalına push et; canlı veritabanını ayrı ele al.

## Kullanıcıya gelen değişiklik

My Cellar içinde **Tastings / Bottles** seçimi var. Tastings önceki tadım geçmişini
korur. Bottles evdeki şişeleri, rekoltesini, sayısını ve isteğe bağlı konumunu
gösterir. Kullanıcı katalogdan şarabını seçip şişe ekleyebilir, “Opened one” ile
bir şişeyi stoktan düşebilir ve şarap detayına gidebilir. Stok düşürmek otomatik
tadım/puan kaydı oluşturmaz.

Ekleme formu rekolteyi isteğe bağlı tutar; hatalı rekolteyi sessizce bilinmiyor
olarak kaydetmez. Arama, yükleme, boş sonuç ve hata durumları ayrıdır. Cevabı
doğrulanamayan eklemede ilk gönderilen bilgiler korunur ve Retry aynı istek
kimliğini kullanır. Stok düşürmede de aynı kural geçerlidir.

## Sunucu ve istemci sözleşmesi

`20260912000000_atomic_cellar_inventory.sql` mevcut expression index'i korur.
Çakışma hedefi tam olarak `(user_id,wine_id,COALESCE(vintage,-1))` ile eşleşir.
Aynı şarap/rekolteye eklenen miktar eski sayının üzerine eklenir. Rekolte bilinmiyorsa
aynı satırda birleşir; farklı rekolteler ayrı kalır. Boş konum, var olan konumu
silmez; yeni konum verilirse o şarap/rekolte satırının konumu güncellenir.

`add_cellar_bottles` ve `drink_cellar_bottle`, kullanıcıyı `auth.uid()` ile doğrular
ve aktif profil arar. `cellar_stock_operations` tablosu istek kimliği, işlem ve
sonuç makbuzunu tutar. Aynı istek aynı cevabı döndürür; farklı içerikle aynı kimliği
kullanmak reddedilir. Makbuz ve stok değişikliği birlikte commit/rollback olur.
İstemcilerin tabloya doğrudan INSERT/UPDATE/DELETE yapması kapatılır.

Azaltma tek UPDATE içinde `quantity > 0` şartıyla yapılır; iki ayrı okuma/yazma
arasındaki yarış kaldırılır. Sıfırdaki kayıt tutulur ama aktif envanterde gösterilmez.
İstemci makbuzdaki eski sayıyı nihai güncel stok saymaz: işlemden sonra yeniden
okur. Yenileme başarısızsa yeni düşürme işlemleri, başarılı yenilemeye kadar
kapalı kalır. Oturum değişince gecikmiş yanıt uygulanmaz.

Stok listesi 200 satırlık sayfalarla okunur. Stok değişince For You'daki mevcut
“Open tonight” alanı da yenileme bildirimi alır.

## Doğrulama

- Swift: **60/60 test geçti**; önceki 51 teste 9 envanter testi eklendi.
- PostgreSQL: **29 senaryo geçti**; 16 önceki tadım/gizlilik, 13 yeni stok
  senaryosu. Node iki parent testiyle birlikte 31 passed raporlar.
- Yeni model testleri, sunucuda uygulanıp cevabı kaybolan bir düşürmeyi ve
  işlem başarılıyken ardından gelen yenilemenin başarısız olmasını da kapsar.
- Testlerde gerçek kullanıcı verisi kullanılmadı. PGlite tüm yeni migration'ları
  çalıştırır; gerçek Supabase REST/Storage, pgvector ve çok bağlantılı eşzamanlılık
  testinin yerine geçmez. Komutlar [test README'sinde](../../supabase/tests/README.md).
- Yeni ekranlar gerçek backend oturumuyla görsel olarak uçtan uca doğrulanmadı;
  simülatör derlemesi ve model testleri bu kontrolün yerine geçmez.

## Dağıtım ve kalan sınırlar

Önceki üç migration'dan sonra yeni stok migration'ı staging'e uygulanmalı.
Gerçek oturumla bilinmeyen rekolteye 2+3 şişe ekleme, aynı isteği yeniden gönderme,
iki cihazdan aynı anda düşürme ve son şişeyi tüketme akışları kontrol edilmeli.
Envanter RPC'leri dağıtılmadan yeni stok ekranındaki yazma işlemleri çalışmaz.
**Bu teslimatta GitHub'a kod push edilir; canlı Supabase'e migration uygulanmaz.**

Bekleyen istekler ekranın ömrü boyunca bellekte korunur. Uygulama kapanmasına
dayanıklı kalıcı taslak kuyruğu sonraki iştir. Aynı şarap/rekolteyi birden fazla
konumda ayrı stok olarak tutma, satın alma fiyatı ve fiziksel envanterden atomik
olarak tadım başlatma da kapsam dışıdır. Ürün pilotunda önce bu temel döngünün
güvenilirliği ve tekrar kullanımı ölçülmeli.
