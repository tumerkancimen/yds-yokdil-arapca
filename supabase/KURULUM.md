# Hesap, eşleşme ve liderlik tablosunu açma

> **Durum (15 Kasım 2026): kurulum tamamlandı, sistem çalışıyor.**
> Supabase projesi kurulu, SQL çalıştırıldı, adres ayarları yapıldı, anahtar `index.html`'e yazıldı.
> E-posta gönderimi **Brevo** üzerinden: sunucu `smtp-relay.brevo.com`, port 587, kullanıcı adı
> `c354be001@smtp-brevo.com`, gönderen `tcimen.jo@gmail.com` (Brevo'da doğrulanmış).
> Ücretsiz plan: günde 300 e-posta. Uçtan uca test edildi (kayıt → onay postası → giriş → eşleşme → hesap silme).
> Gmail SMTP denendi ve olmadı (`535 BadCredentials`); Brevo ile değiştirildi.
> Aşağısı, ileride yeniden kurman ya da başka bir projeye taşıman gerekirse diye duruyor.

Site bu adımlar yapılmadan da çalışır. `index.html` içindeki `LB` satırı boşken hesap ve liderlik kartları hiç görünmez.

## 1. Proje aç
1. supabase.com adresinde **New project** de. Ad: `yds-arapca`. Güçlü bir veritabanı şifresi belirle ve kaydet. Bölge olarak Avrupa'dan birini seç. Plan: **Free**.
2. Proje hazır olana kadar bir iki dakika bekle.

## 2. Tabloları oluştur
1. Sol menüde **SQL Editor > New query**'yi aç.
2. Bu klasördeki `supabase.sql` dosyasının tamamını yapıştırıp **Run**'a bas. "Success" görmelisin.

## 3. Adres ayarları (e-posta bağlantıları ve Google için şart)
**Authentication > URL Configuration**:
- **Site URL:** `https://tumerkancimen.github.io/yds-yokdil-arapca/`
- **Redirect URLs** listesine aynı adresi ekle: `https://tumerkancimen.github.io/yds-yokdil-arapca/`

## 4. Giriş yöntemleri
**Authentication > Sign In / Providers**:
- **Email:** açık olsun. "Confirm email" açık kalsın (önerilir): kayıt olan kişi e-postasını onaylamadan giriş yapamaz.
- **Allow anonymous sign-ins:** hesapsız takma adla liderlik tablosuna katılmaya izin vermek istiyorsan aç. Kapalıysa liderlik tablosuna yalnızca hesabıyla giren katılır, bu da sorun değil.
- **Google (isteğe bağlı):** Supabase'in Google rehberini izleyip Google Cloud'da bir OAuth istemcisi oluştur, istemci kimliği ve gizli anahtarı buraya yaz. Sonra `index.html`'de `google:false` değerini `google:true` yap. Yapmazsan Google düğmesi sitede görünmez.

## 5. E-posta gönderimi (yapıldı: Brevo)
Supabase'in dahili e-posta servisi saatte yalnızca birkaç e-posta gönderir ve yalnızca deneme içindir.
Bu yüzden **Authentication > Emails > SMTP Settings** bölümüne Brevo bağlandı:

| Alan | Değer |
| --- | --- |
| Sender email | `tcimen.jo@gmail.com` (Brevo'da doğrulanmış gönderen) |
| Sender name | YDS Arapça Çalışma Kütüphanesi |
| Host | `smtp-relay.brevo.com` |
| Port | 587 |
| Username | `c354be001@smtp-brevo.com` |
| Password | Brevo'daki SMTP anahtarı (Brevo > SMTP & API > Generate SMTP key) |

Brevo'nun kendi bilgileri: **app.brevo.com > Settings > SMTP & API**. Anahtar bir kez gösterilir; kaybedersen yenisini üret ve Supabase'deki Password alanını güncelle.

Notlar:
- Ücretsiz plan günde 300 e-posta. Supabase tarafındaki sınır da özel SMTP ile saatte 30'a çıktı, **Authentication > Rate Limits**'ten artırılabilir.
- Gönderen adresi bir Gmail adresi olduğu için Brevo mesajları kendi alan adından (`...@...brevosend.com`) gönderiyor ve "freemail" uyarısı veriyor. Çalışıyor, ama bazı alıcılarda gereksiz klasörüne düşebilir. Kalıcı çözüm kendi alan adını alıp Brevo'da doğrulamak.
- Gmail SMTP de denendi, Google uygulama şifresini kabul etmedi (`535 BadCredentials`). Brevo'ya geçildi.

## 6. İki bilgiyi siteye yaz
**Project Settings > API** bölümünde:
- **Project URL** (`https://....supabase.co`)
- **anon / publishable key**: herkese açık anahtar, siteye yazılması güvenlidir.

**`service_role` ya da `secret` yazan anahtarı asla siteye koyma ve paylaşma.**

`index.html` içinde şu satırı bul:

    const LB={url:'',key:'',google:false};

Bilgileri yaz, kaydet ve GitHub'a yükle:

    const LB={url:'https://....supabase.co',key:'...',google:false};

Plan & Takip sayfasında "Hesap ve eşleşme" ve "Liderlik tablosu" kartları çıkar.

## Eşleşme nasıl çalışır?
- Giriş yapan cihazda ilerleme birkaç saniye içinde buluta gider ve diğer cihazlar açılınca ya da öne gelince aynısını alır.
- Bir cihaz bir hesapla ilk kez eşleşirken buluttaki ve cihazdaki yanlış defteri, bilinen kelimeler, denemeler birleştirilir; hiçbiri kaybolmaz.
- Sonraki eşleşmelerde, iki cihaz aynı alanı değiştirdiyse en yenisi kazanır. Çözülen sorular, rozetler ve günlük sayılar her zaman birleşir (hiçbir zaman azalmaz).
- iPhone'da ana ekrana eklenen uygulama ile Safari ayrı depolama kullanır. Her ikisinde de aynı hesapla giriş yaparsan ilerleme eşleşir. Google ile girişte iPhone ana ekran uygulaması tarayıcıya geçebilir, orada e-posta ve şifre ile girmek daha sorunsuzdur.

## Bilmen gerekenler
- Ücretsiz projeler bir hafta hiç kullanılmazsa duraklatılır. Panelden tek tıkla yeniden başlar. O sürede hesap ve sıralama çalışmaz, site yerel olarak çalışmaya devam eder.
- Puanı tarayıcı gönderir. Sunucu artışı süreye göre sınırlar (hileyi zorlaştırır, tamamen engellemez). Arkadaş arası yarışma için yeterlidir.
- Uygunsuz bir takma ad görürsen **Table Editor > scores** tablosundan o satırı sil.
- Hesabı olan biri silinmek isterse kendisi kartından silebilir; sen de **Authentication > Users** bölümünden silebilirsin (bağlı veriler birlikte gider).
- Gizlilik politikası siteye eklidir (`#gizlilik`). Mağazaya çıkarsan bu adresi mağaza sayfasındaki gizlilik politikası alanına yaz.
