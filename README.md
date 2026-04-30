# AKSA – Health & Fitness App

Flutter + FastAPI tabanlı sağlık ve fitness uygulaması.

---

## 🚀 Kurulum Rehberi (Yeni Geliştirici)

### Ön Gereksinimler
- Flutter SDK (3.x+)
- Python 3.10+
- PostgreSQL (yerel kurulum)
- Git

---

### 1. Repoyu Klonla

```bash
git clone https://github.com/yavuzzselimm/aksa.git
cd aksa
```

---

### 2. Backend Kurulumu

#### 2a. Python sanal ortamı oluştur ve aktif et

```bash
cd backend
python3 -m venv venv
source venv/bin/activate        # macOS/Linux
# venv\Scripts\activate         # Windows
```

#### 2b. Bağımlılıkları yükle

```bash
pip install -r requirements.txt
```

#### 2c. `.env` dosyasını oluştur

```bash
cp .env.example .env
```

Ardından `.env` dosyasını aç ve şu alanları doldur:
- `DATABASE_URL` → kendi PostgreSQL kullanıcı adınla güncelle (örn. `postgresql://SENIN_ADIN@localhost:5432/aksa`)
- `GOOGLE_CLIENT_ID` → Yavuz'dan al
- `SMTP_EMAIL` / `SMTP_PASSWORD` → Yavuz'dan al

#### 2d. PostgreSQL veritabanını oluştur

```bash
createdb aksa
```

Sonra database şemasını uygula:

```bash
psql -d aksa -f ../database/schema.sql
```

#### 2e. (Opsiyonel) ML Model dosyasını al

`backend/ml_models/combined_best.pth` dosyası Git'te yok (72MB, çok büyük).  
Yavuz'dan bu dosyayı alıp `backend/ml_models/` klasörüne koymanız gerekiyor.

> **Not:** Bu dosya olmadan AI özelliği çalışmaz ama diğer özellikler sorunsuz çalışır.

#### 2f. Backend'i başlat

```bash
cd backend
source venv/bin/activate
python main.py
```

Backend `http://localhost:8000` adresinde çalışmaya başlar.

---

### 3. Flutter (Frontend) Kurulumu

#### 3a. Root `.env` dosyasını oluştur

Projenin ana klasöründe:

```bash
cp .env.example .env
```

Yavuz'dan aşağıdaki değerleri alıp `.env` dosyasına yaz:
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_IOS_CLIENT_ID`
- `SMTP_EMAIL` / `SMTP_PASSWORD`

#### 3b. Flutter bağımlılıklarını yükle

```bash
flutter pub get
```

#### 3c. Uygulamayı çalıştır

```bash
flutter run
```

---

### 4. Firebase Dosyaları (Gerekirse)

Eğer Google Sign-In kullanıyorsan şu dosyalar gerekebilir:
- Android → `android/app/google-services.json`
- iOS → `ios/Runner/GoogleService-Info.plist`

Bu dosyaları Yavuz'dan alıp ilgili klasörlere koyun.

---

## 📁 Proje Yapısı

```
aksa/
├── backend/              # FastAPI backend
│   ├── app/              # API routes, services, models
│   ├── ml_models/        # AI model dosyaları (Git'te yok!)
│   ├── requirements.txt  # Python bağımlılıkları
│   ├── .env.example      # Ortam değişkenleri şablonu
│   └── main.py           # Backend giriş noktası
├── database/
│   └── schema.sql        # PostgreSQL şeması
├── lib/                  # Flutter uygulama kodu
├── .env.example          # Root ortam değişkenleri şablonu
└── pubspec.yaml          # Flutter bağımlılıkları
```

---

## ⚠️ Git'e Gönderilmeyen Dosyalar

Bu dosyalar güvenlik/boyut nedeniyle `.gitignore`'da:

| Dosya | Neden Eksik | Nereden Alınır |
|-------|-------------|----------------|
| `backend/.env` | Şifreler/API anahtarları | `.env.example`'dan oluştur + Yavuz'dan değerleri al |
| `.env` (root) | Şifreler/API anahtarları | `.env.example`'dan oluştur + Yavuz'dan değerleri al |
| `backend/venv/` | Yerel Python ortamı | `pip install -r requirements.txt` ile oluştur |
| `backend/ml_models/*.pth` | 72MB model dosyası | Yavuz'dan al |
| `google-services.json` | Firebase gizli anahtarı | Yavuz'dan al |
| `GoogleService-Info.plist` | Firebase gizli anahtarı | Yavuz'dan al |
