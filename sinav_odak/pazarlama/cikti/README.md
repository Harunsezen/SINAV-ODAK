# ÇIKTILAR — kullanıma hazır dosyalar

Bunlar brief değil, **son dosyalar**. Doğrudan paylaş / bas.

## Sosyal medya (Instagram, TikTok)

| Dosya | Boyut | Nerede |
| --- | --- | --- |
| `post_01_sayac.png` | 1080×1350 | akış — açılış postu |
| `post_02_duraklatilamaz.png` | 1080×1350 | akış — ürünün kuralı |
| `post_03_seri.png` | 1080×1350 | akış — en paylaşılabilir |
| `post_04_kitap_modu.png` | 1080×1350 | akış — v1.3 duyurusu |
| `post_05_karne.png` | 1080×1350 | akış — veli/öğretmen |
| `post_06_story_qr.png` | 1080×1920 | story / reels kapağı, QR gömülü |
| `video_15sn_dikey.mp4` | 1080×1920, 15 sn | TikTok / Reels / Shorts |

Video sessiz. Yükleme sırasında platformun ses kütüphanesinden lo-fi
bir parça seç; 15 saniye tam bir döngüye oturuyor.

## Okul panosu

| Dosya | Ne için |
| --- | --- |
| `afis_a3.pdf` | **matbaaya/yazıcıya bu gider** — A3, kenar boşluksuz |
| `afis_a3_300dpi.png` | 3514×4967, 300 DPI — kopyalama merkezi PDF istemezse |

Yazdırma: A3 · dikey · kenar boşluğu yok · "arka plan grafikleri" açık.

## QR

| Dosya | Ne için |
| --- | --- |
| `qr_sinav_odak.png` | 2280×2280, beyaz zeminli — her yerde çalışır |
| `qr_sinav_odak.svg` | vektör — afişte, tabelada, her boyutta net |
| `qr_sinav_odak_seffaf.png` | zemini şeffaf — koyu tasarımların üstüne |

Hedef: uygulamanın Google Play sayfası.

> **Paket adı afişe BASILMIYOR** — içinde geliştiricinin soyadı geçiyor ve
> panodan okuyan biri onu aratabilir. Yazıyla yedek yol olarak yalnızca
> uygulama adı veriliyor: *Google Play'de "Sınav Odak" ara.*
> Paket adı QR'ın içindeki bağlantıda var (Play bağlantısı başka türlü
> kurulamıyor) ama **okunabilir biçimde hiçbir yerde yazmıyor**.
Hata düzeltme seviyesi **H** (%30) — üstüne logo konabilir, yıpranmış
baskıda da okunur.

> **Basmadan önce QR'ı bir telefonla tara.** Kod doğru üretildi, ama
> uygulama Play'de henüz yayında değilse bağlantı boş sayfa açar.

## Bunlar nasıl üretildi

`pazarlama/poster_a3.html` tek dosyalık kaynak; PNG ve PDF ondan
basıldı. Sosyal görseller ve video da HTML olarak kurulup Chromium ile
kareye alındı — yani hepsi metin dosyasından yeniden üretilebilir,
kaynak dosyaları `pazarlama/` altında.

**Fotoğraf yok.** Bu ortamda görsel üretme modeli yok; onun yerine
markanın kendi paleti ve tipografisiyle grafik tasarım yapıldı.
Fotoğraflı versiyon istersen `gorsel_promptlari.md` içindeki beş
prompt hazır — Midjourney/DALL·E gibi bir araca verilecek.
