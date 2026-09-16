# Canlı backend onarımı — 16 Eylül 2026

Profilde “4 Rated” görünmesine rağmen geçmişin hata vermesinin nedeni, uygulama
ile canlı veritabanının farklı sürümlerde olmasıydı. Sayaç yalnızca kayıt
kimliklerini okuyabiliyordu; geçmiş sorgusundaki `tastings.vintage` ve yapılandırılmış
tadım alanları canlıda yoktu. Akışın cursor RPC'leri, şişe envanteri ve grup
masaları için gereken güncellemeler de dağıtılmamıştı.

## Uygulanan onarım

- Canlı şema ve mevcut satırlar yedeklendi. Gerçek şema ve 100.523 şarap içeren
  kopya, izole PostgreSQL 17/pgvector üzerinde doğrulandı.
- Eksik 21 migration canlıya uygulandı: Ağustos 3'teki 15, Eylül 11'deki üç,
  Eylül 12'deki bir ve Eylül 16'daki iki migration. Kullanıcının mevcut dört
  tadımı yeniden görünür hale geldi.
- Profil geçmişi yüklenirken, boşken ve hata verdiğinde farklı durumlar gösterir.
  Hata, “No tastings yet” şeklinde gösterilmez; bölümün Retry düğmesi vardır.
  Başarısız yenileme önceden yüklenmiş kayıtları silmez; eski yanıt yeni sonucu ezmez.
- Grup üyeliği RLS politikasındaki döngü giderildi. Masadan çıkış RPC ile
  doğrulanır; başarısız çıkış ve öneri sorguları artık kullanıcıya bildirilir.
- Eksik engelleme/raporlama tabloları eklendi. Engelleme profil, tadım ve etkinlik
  okumalarına uygulanır. Rapor kuyruğu istemciye açılmaz. Eski anonim profil
  yazma politikaları kaldırıldı; avatar yazma kendi kullanıcı klasörüyle sınırlandı.
- Gerçek Storage testinde, daha önce yetki verilmiş fotoğrafın CDN önbelleğinden
  engelleme sonrasında da dönebildiği görüldü. Yeni yüklemelerde cache süresi sıfır;
  indirmelerde her isteğe özgü URL parametresi mevcut erişim kurallarını tekrar
  değerlendirtir. Daha önce indirilmiş kopyaların geri alınmasını sağlamaz.
- `claude-vision` ve `wine-list-scan` dağıtıldı. Yeni Anthropic anahtarının
  gerektirdiği workspace başlığı için `ANTHROPIC_WORKSPACE_ID` desteği eklendi
  ve canlı secret ayarlandı. Anahtarlar repoya eklenmedi. Sağlayıcı yapılandırma
  hataları 503 olarak ele alınır; manuel şarap arama/ekleme kullanılabilir kalır.
- Embedding migration'ında eski HNSW indeksi toplu güncellemeden önce kaldırılır
  ve sonra yeniden kurulur; silinecek indeksin 100 bin kez güncellenmesi önlenir.

## Doğrulama sonuçları

| Katman | Sonuç |
| --- | --- |
| iOS simulator build | Başarılı |
| XCTest | 63 geçti, sıfır hata |
| PGlite/Node SQL regresyonları | 37 geçti, sıfır hata; parent testler dahil |
| Gerçek PostgreSQL 17 + pgvector | Geçmiş, akış, arama, öneri ve yazma/geri alma kontrolleri geçti |
| Canlı Auth/PostgREST | 17 kontrol geçti |
| Canlı Storage/moderasyon | 4 kontrol geçti |
| Canlı tarama akışı | 4 kontrol geçti |
| Salt okunur backend sözleşmesi | 10 tablo, 19 RPC ve özel fotoğraf bucket'ı doğrulandı |

Canlı HTTP kontrolleri geçici hesaplarla gerçek oturum açma, profil oluşturma,
tadım oluşturma/yeniden gönderme/güncelleme/silme, boş alanları temizleme, özel
görünürlük, iki akış, arama, damak profili, öneriler, koleksiyonlar, şişe
ekleme/açma ve tekrar koruması, reserve listesi ile iki kullanıcı arasında
masa oluşturma/katılma/çıkmayı kapsadı. Fotoğraf erişimi, engelleme/geri alma,
rapor gönderme ve avatar sahipliği gerçek HTTP istekleriyle kontrol edildi.

Tarama testleri sentetik JPEG'leri gerçek sağlayıcıya gönderdi. Etiketin adı,
üreticisi ve 2021 rekoltesi çıkarıldı; katalog kaydı → özel tadım → birleşik
geçmiş okuması tamamlandı. Menüden iki şarap çıkarıldı ve ikisi de katalogdaki
doğru ad/üreticiye 1.0 eşleşme skoru ile bağlandı. İki fonksiyon da anonim
istekleri reddetti. Bu, her fotoğrafta OCR doğruluğu garantisi değildir.

iPhone 17 Pro / iOS 26.2 simülatöründe gerçek oturumla profilin dört tadımı,
Taste ve Reserve List, Global akışı, My Cellar tadımları, şişe arama ve ekleme
formu, For You önerileri, şarap detayı ve bildirim ekranı kontrol edildi.
Yazma testleri kullanıcının kayıtları yerine geçici hesaplarla yapıldı.

Geçici hesaplar, şaraplar, fotoğraflar ve kayıtlar temizlendi. Onarım öncesi
mevcut satırlar eski alanları üzerinden karşılaştırıldı: 5 profil, 33 tadım,
39 etkinlik, 14 cellar kaydı, 5 takip, 22 beğeni, 18 bildirim, 4 özel kullanıcı
kaydı ve 1 destek talebi korundu. Etkinlik-tadım bağlantısının migration ile
tamamlanması ve yeni şema alanları beklenen değişikliklerdir.

Makine tarafından okunabilir sonuçlar:
[backend-repair-2026-09-16-results.json](backend-repair-2026-09-16-results.json).

## Sonraki dağıtımlarda kontrol

Dağıtımdan önce yerel ortamda `SUPABASE_ACCESS_TOKEN` tanımlıyken çalıştır:

```sh
python3 scripts/check_backend_contract.py
```

Script yalnızca şema okur; eksik sözleşmede hata koduyla çıkar. Projeyi yerel,
gitignored `SupabaseConfig.swift` dosyasından veya `SUPABASE_PROJECT_REF`
ortam değişkeninden alır. Secret değerlerini veya kullanıcı satırlarını yazdırmaz.
Fonksiyon dağıtımı, OCR, bütün RLS kuralları ve çalışma zamanı sağlığı için
tek başına yeterli değildir. CI'a bağlanması bu teslimatta yapılmadı.

Canlı migration ledger'ına yalnızca bu onarımda gerçekten uygulanan sürümler
yazıldı. Daha eski, elle kurulmuş şema geçmişi hâlâ ayrı uzlaştırma gerektirir.
Bu nedenle eski migration'ları körlemesine tekrar uygulayan `supabase db push`
kullanılmamalı; önce ledger/şema farkı incelenmelidir. Önceki teslimat raporlarındaki
“canlıya uygulanmadı” notları o tarihler için geçerlidir; bu rapor yeni durumu kaydeder.

## Kontrolün sınırları

Fiziksel cihaz kamerası, SMS/e-posta teslimi, hesap kurtarma, kalıcı hesap silme,
iki cihazdan eşzamanlı stok yarışı ve üretim yük testi çalıştırılmadı.
Öneri ekranının çalışması doğrulandı; öneri kalitesi ve uzun vadeli kullanıcı
memnuniyeti ölçülmedi. Bu sonuçlar bütün ürünün hatasız olduğu iddiası değildir.
