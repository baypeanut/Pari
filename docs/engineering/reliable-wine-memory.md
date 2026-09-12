# Pari — baş mühendis çalışma talimatı

Pari'nin ilk vaadini güvenilir hale getir: “İçtiğim şarabı hatırlarım; notlarım,
damak tarifim ve paylaşım tercihim kaybolmaz.” Ürün yönü, kişinin kendi şarap
hafızasını ve bir sonraki seçimini iyileştirmek. Vivino ile özellik sayısı yarışına
girmek bu çalışmanın başarı ölçütü değildir.

## Bu teslimatın kapsamı

1. Arama ve tarama akışlarında tadım ile feed kaydını tek veritabanı işlemiyle
   oluştur. Aynı kayıt girişiminin tekrarı ikinci tadım oluşturmasın.
2. Düzenlemede puan, notlar, yorum, rekolte, görünürlük ve altı damak alanını
   sakla; silinen isteğe bağlı alanları gerçekten NULL yap. Yeniden okuma aynı
   değerleri döndürsün. Silme yalnızca bağlı feed kaydını silsin.
3. Profil ve tadım görünürlüğünü birlikte uygula. Doğrudan tablo, feed RPC ve
   fotoğraf erişiminde arkadaşlık şartını atlama. Kimliği istemciden kabul etme.
4. Oturumlar arasında eski feed verisini gösterme. Gizlilik değiştikten sonra
   diskteki eski bir kopyayı yeniden gösterme; bu teslimatta feed disk önbelleğini
   kaldır. Kişisel öneri önbelleğini değişiklikten sonra geçersiz kıl.
5. Gerçek migration SQL'ini izole PostgreSQL üzerinde olumlu ve olumsuz
   senaryolarla çalıştır. Swift sözleşme testlerini ve mevcut testleri çalıştır;
   uygulamayı simülatörde aç.

## Sınırlar ve teslimat

SwiftUI ve Supabase korunacak. Eski migration'lar değiştirilmeyecek. Yeni SQL,
istemci değişiklikleri, tekrar çalıştırılabilir testler ve dağıtım notu aynı dalda
incelenebilir olacak. Canlı veritabanı şeması ve Storage servisi bu yerel ortamda
doğrulanmadığından canlıya migration uygulanmayacak; staging üzerinde API ve
Storage kontrolü, yeni istemcinin dağıtımından önce gereklidir.

Hesap silme, grup oturumları, fiziksel şişe envanteri, öneri değerlendirmesi ve
katalog yazma yetkileri ayrı takip işleridir. Bu teslimat bunların çözülmüş
olduğunu veya tüm uygulamanın yayına hazır olduğunu iddia etmeyecek.
