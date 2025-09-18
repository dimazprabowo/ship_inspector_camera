# Ship Inspector App

Aplikasi inspeksi kapal offline yang memungkinkan inspektor untuk mengambil foto dan menyimpannya secara lokal dengan sistem penamaan otomatis.

## Fitur Utama

- **Offline First**: Aplikasi dapat berfungsi sepenuhnya tanpa koneksi internet
- **Manajemen Perusahaan**: Pilih perusahaan pemilik kapal
- **Jenis Kapal**: Pilih jenis kapal yang akan diinspeksi
- **Daftar Inspeksi**: List item yang harus difoto untuk setiap jenis kapal
- **Pengambilan Foto**: Ambil foto menggunakan kamera atau pilih dari galeri
- **Penamaan Otomatis**: File foto otomatis diberi nama sesuai dengan item inspeksi
- **Preview Foto**: Lihat foto yang telah diambil dengan preview grid
- **CRUD Operations**: Tambah, edit, dan hapus item inspeksi

## Struktur Aplikasi

### Flow Aplikasi
1. **Pilih Perusahaan** → Tampilkan daftar perusahaan yang tersedia
2. **Pilih Jenis Kapal** → Tampilkan jenis kapal berdasarkan perusahaan
3. **Inspeksi** → Tampilkan daftar item yang harus difoto

### Contoh Data Default
- **Perusahaan A**
  - **Tugboat**: Lambung Depan, Lambung Kanan, Lambung Kiri
  - **Cargo Ship**: Ruang Kargo, Crane Loading
- **Perusahaan B**
  - **Tanker**: Tangki Utama, Sistem Pompa

## Teknologi yang Digunakan

- **Flutter**: Framework utama
- **SQLite**: Database lokal untuk penyimpanan offline
- **Camera Plugin**: Untuk mengambil foto
- **Image Picker**: Untuk memilih foto dari galeri
- **Path Provider**: Untuk manajemen file lokal

## Instalasi dan Menjalankan

### Prasyarat
- Flutter SDK (versi 3.9.2 atau lebih baru)
- Android Studio / VS Code
- Android SDK untuk testing Android
- Xcode untuk testing iOS (khusus macOS)

### Langkah Instalasi
1. Clone atau download project ini
2. Buka terminal di folder project
3. Jalankan perintah:
   ```bash
   flutter pub get
   ```
4. Untuk menjalankan di Android:
   ```bash
   flutter run
   ```
5. Untuk menjalankan di iOS:
   ```bash
   flutter run -d ios
   ```

## Struktur File

```
lib/
├── main.dart                 # Entry point aplikasi
├── models/                   # Data models
│   ├── company.dart
│   ├── ship_type.dart
│   ├── inspection_item.dart
│   └── inspection_photo.dart
├── services/                 # Business logic
│   ├── database_helper.dart
│   └── camera_service.dart
├── screens/                  # UI Screens
│   ├── company_selection_screen.dart
│   ├── ship_type_selection_screen.dart
│   └── inspection_screen.dart
└── widgets/                  # Reusable widgets
    ├── photo_grid_widget.dart
    └── add_inspection_item_dialog.dart
```

## Fitur Penamaan File

File foto akan otomatis diberi nama dengan format:
- `{judul_item}_{timestamp}.jpg` untuk foto pertama
- `{judul_item}_{nomor}_{timestamp}.jpg` untuk foto selanjutnya

Contoh:
- `lambung_depan_1694847600000.jpg`
- `lambung_depan_2_1694847700000.jpg`

## Penyimpanan Data

- **Database**: SQLite untuk metadata (perusahaan, jenis kapal, item inspeksi, referensi foto)
- **File Foto**: Disimpan di direktori aplikasi dengan path yang aman
- **Lokasi**: `{app_documents_directory}/ship_inspector_photos/`

## Permissions

### Android
- `CAMERA`: Untuk mengakses kamera
- `WRITE_EXTERNAL_STORAGE`: Untuk menyimpan foto
- `READ_EXTERNAL_STORAGE`: Untuk membaca foto

### iOS
- `NSCameraUsageDescription`: Akses kamera
- `NSPhotoLibraryUsageDescription`: Akses galeri foto

## Pengembangan Lebih Lanjut

Fitur yang bisa ditambahkan:
- Export data ke format Excel/PDF
- Sinkronisasi dengan server
- Backup dan restore data
- Kompres foto otomatis
- Watermark pada foto
- Geolocation tagging

## Troubleshooting

### Masalah Umum
1. **Foto tidak muncul**: Pastikan permissions sudah diberikan
2. **Database error**: Hapus dan install ulang aplikasi
3. **Camera tidak berfungsi**: Pastikan device memiliki kamera dan permissions sudah diberikan

### Debug Mode
Untuk melihat log error, jalankan:
```bash
flutter run --debug
```
