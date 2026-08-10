# Gizlilik Politikası — Sınav Odak

**Son güncelleme:** 10 Ağustos 2026
**Uygulama:** Sınav Odak (Android)
**Veri sorumlusu:** Sınav Odak geliştiricisi
**İletişim:** harunsezen014701@gmail.com

Bu politika, KVKK (6698 sayılı Kişisel Verilerin Korunması Kanunu) ve GDPR
kapsamındaki aydınlatma yükümlülüğünü karşılamak üzere hazırlanmıştır.

---

## 1. Özet

Sınav Odak bir çalışma sayacı ve istatistik uygulamasıdır.

- **Hesap yok.** Kayıt olmuyorsunuz, e-posta/telefon istemiyoruz.
- **Sunucumuz yok.** Çalışma verileriniz yalnızca **cihazınızda** saklanır.
- **Verilerinizi biz okumuyoruz.** Bize hiçbir çalışma verisi gönderilmez.
- Uygulama ücretsizdir ve **reklamla** desteklenir. Reklam gösterilmesi
  için **açık rızanız** gerekir; rıza vermezseniz uygulamanın **hiçbir
  özelliği kapanmaz**.

---

## 2. Cihazınızda İşlenen Veriler

Aşağıdaki veriler cihazınızdaki yerel bir SQLite veritabanında tutulur ve
**cihazdan dışarı çıkmaz**:

| Veri | Amaç |
| --- | --- |
| Çalışma oturumları (ders, konu, süre, mola, başlangıç/bitiş anı) | Sayaç ve istatistikler |
| Odak puanı ve günlük/haftalık özetler | İlerleme takibi |
| Seri (streak) ve hedefler | Motivasyon göstergeleri |
| Yanlış defteri kayıtları (ders, konu, soru notu, tekrar sayısı) | Tekrar planlama |
| Ders ve konu listeleri | Oturum kurulumu |
| Uygulama ayarları (tema, reklam tercihleri, onboarding durumu) | Uygulama davranışı |

Bu verileri **silmek** için: uygulama içinden ilgili kaydı silebilir veya
cihaz ayarlarından uygulamayı kaldırabilirsiniz. Uygulamayı kaldırmak yerel
veritabanını da siler ve bu işlem **geri alınamaz**.

**Yedekleme:** Uygulama kendi sunucusuna yedek almaz. Android'in sistem
yedekleme özelliği açıksa, cihaz yedeğiniz Google hesabınıza alınabilir; bu
Google'ın kendi politikasına tabidir.

---

## 3. Reklamlar (Google AdMob)

Uygulama, Google AdMob üzerinden reklam gösterir. Reklamlar
**yalnızca** aşağıdaki yerlerde çıkar:

- Ana panel ve istatistik ekranlarında ince banner
- Mola ekranında (mola süresi yeterliyse) kart reklam
- Oturum bitişinde tebrik ekranından ana panele dönerken ara reklam
- Ayarlar'daki **"Destek ol"** düğmesine kendiniz bastığınızda ödüllü reklam

**Reklam gösterilmeyen yerler:** çalışma bloğu sırasında tam ekran reklam
**asla** gösterilmez; oturum akışı reklam yüzünden bekletilmez. Reklam
yüklenemezse akış aynen devam eder.

### 3.1 Reklam ortağının işlediği veriler

Reklam gösterildiğinde Google AdMob, reklamı sunmak ve ölçmek için şu
verileri işleyebilir:

- Cihaz reklam kimliği (Android Advertising ID)
- IP adresi ve buradan çıkarılan yaklaşık konum (ülke/şehir düzeyi)
- Cihaz ve uygulama bilgisi (model, işletim sistemi sürümü, uygulama
  sürümü, dil)
- Reklam etkileşimi (gösterim, tıklama, izlenen ödüllü reklam)

Bu veriler **Google'a** aktarılır; geliştirici olarak bu verilere kimlik
düzeyinde erişimimiz yoktur, yalnızca toplulaştırılmış performans raporları
görürüz. Google'ın işleme esasları:
<https://business.safety.google/privacy/> ve
<https://policies.google.com/technologies/ads>.

### 3.2 Rıza (KVKK/GDPR)

- Reklam tercihiniz uygulamayı ilk açtığınızda **onboarding** akışında
  sorulur. **Varsayılan kapalıdır** — hiçbir şey seçmezseniz reklam
  gösterilmez.
- Avrupa Ekonomik Alanı, Birleşik Krallık ve İsviçre'de ayrıca Google'ın
  resmi rıza formu (**UMP — User Messaging Platform**) gösterilir. Bu form
  **ilk reklam isteğinden önce** açılır.
- **İki kapı da açık olmalı.** Uygulama içi tercihiniz açık olsa bile UMP
  "reklam isteği yapılamaz" diyorsa reklam gösterilmez. Tersi de geçerlidir:
  UMP izin verse bile uygulama içi tercihiniz kapalıysa reklam çıkmaz.
- Rıza formu yüklenemezse, ağ yoksa veya bir hata olursa uygulama
  **reklamsız** çalışmaya devam eder. Hata durumunda asla "izin var"
  varsayılmaz.
- **Rızanızı her zaman geri alabilirsiniz:** Ayarlar → *Gizlilik
  tercihleri*. (Bu bölüm, UMP formunun gerekli olduğu bölgelerde görünür.)

### 3.3 Kişiselleştirilmemiş reklam

Rıza vermezseniz veya rızanızı geri alırsanız, uygulama reklam **istemez**.
Bu durumda uygulama tüm özellikleriyle ücretsiz çalışmaya devam eder.

---

## 4. Bildirimler ve İzinler

Uygulamanın istediği izinler ve gerekçeleri:

| İzin | Neden gerekli |
| --- | --- |
| `POST_NOTIFICATIONS` | Mola bitti / oturum bitti bildirimleri |
| `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` | Bildirimin tam zamanında düşmesi (mola sonu saniye hassasiyetiyle önemli) |
| `RECEIVE_BOOT_COMPLETED` | Cihaz yeniden başladığında planlanmış bildirimlerin kaybolmaması |
| `WAKE_LOCK`, `VIBRATE` | Bildirimin ekran kapalıyken de düşmesi ve titreşim |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Yalnızca reklam yüklemek için |

Uygulama **konum, kamera, mikrofon, rehber, dosya veya SMS** izni istemez.

---

## 5. Çocukların Gizliliği

Uygulama sınava hazırlanan öğrenciler içindir ve 13 yaş altı çocuklara
yönelik değildir. 13 yaş altı bir kullanıcıya ait veri işlendiğini
öğrenirsek gereken silme işlemini yaparız.

---

## 6. Analitik ve Üçüncü Taraflar

- **Analitik/izleme SDK'sı yoktur.** Firebase Analytics, Crashlytics veya
  benzeri bir ölçüm aracı kullanılmaz.
- Uygulamanın kullandığı tek üçüncü taraf SDK'sı **Google Mobile Ads
  (AdMob + UMP)**'dir.
- Verileriniz satılmaz, kiralanmaz, pazarlama amacıyla paylaşılmaz.

---

## 7. Veri Saklama Süresi

- Çalışma verileriniz siz silene veya uygulamayı kaldırana kadar cihazınızda
  kalır.
- Reklam gösterim kayıtları (reklam sıklığını sınırlamak için tutulan yerel
  log) **7 günden eski** olduğunda otomatik silinir.
- Geliştirici tarafında saklanan hiçbir kişisel veri yoktur.

---

## 8. KVKK Kapsamındaki Haklarınız

KVKK m.11 ve GDPR m.15–22 uyarınca; kişisel verilerinizin işlenip
işlenmediğini öğrenme, düzeltme, silme, işlemeye itiraz etme ve rızanızı geri
alma haklarına sahipsiniz.

Çalışma verileriniz yalnızca cihazınızda olduğu için bu hakların çoğunu
**doğrudan uygulama içinden** kullanabilirsiniz (kaydı silme, uygulamayı
kaldırma, Ayarlar'dan reklam rızasını geri alma).

Reklam verileri bakımından talepleriniz için Google'a başvurmanız gerekir:
<https://support.google.com/policies/troubleshooter/7575787>.

Diğer talepleriniz için: **harunsezen014701@gmail.com**. Başvurular en geç
30 gün içinde yanıtlanır.

---

## 9. Politikadaki Değişiklikler

Bu politika değişirse "Son güncelleme" tarihi güncellenir. Reklam rızasının
kapsamını genişleten bir değişiklik olursa rızanız **yeniden** sorulur.

---

## 10. Google Play Veri Güvenliği Beyanı (özet)

Play Console'daki *Data safety* formu bu tabloya göre doldurulmalıdır:

| Soru | Cevap |
| --- | --- |
| Veri toplanıyor mu? | **Evet** — yalnızca reklam SDK'sı aracılığıyla |
| Toplanan tür | Cihaz veya diğer kimlikler (reklam kimliği); yaklaşık konum (IP kaynaklı) |
| Amaç | Reklam veya pazarlama |
| Veri paylaşılıyor mu? | **Evet** — Google AdMob'a |
| Aktarımda şifreleniyor mu? | **Evet** (HTTPS) |
| Kullanıcı silme talep edebilir mi? | **Evet** — rızayı geri çekme + uygulamayı kaldırma |
| Uygulama verileri (oturum, istatistik, yanlış defteri) toplanıyor mu? | **Hayır** — cihazdan çıkmaz |
