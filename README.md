# Sahira Farm

Company profile peternakan domba dengan CMS, dashboard pemeliharaan, serta fondasi ESP/RFID. React, TypeScript, Vite, dan Supabase.

## Menjalankan aplikasi

Gunakan Node.js 22.12+.

```sh
npm ci
```

Salin `.env.example` menjadi `.env.local`, lalu isi URL proyek Supabase dan publishable key dari proyek Anda. Jangan memakai service-role key di frontend. Konfigurasi lokal yang sudah terhubung tidak ikut repository.

```sh
npm run dev -- --port 5174
npm run build
npm test
```

Buka `http://127.0.0.1:5174`. Aplikasi ini belum dipublikasikan ke hosting web; repository GitHub bukan deployment.

## Halaman & Web Content

- `/`: pembuka satu layar, tentang Sahira Farm, slider Garut/Merino/Texel, dan kontak.
- `/admin/akses`: akses akun pengelola.
- `/admin`: monitoring ternak, identitas, ras, silsilah, pertumbuhan, perlakuan, dan perangkat.
- `/admin/konten`: edit teks, foto, nama/deskripsi setiap slide, urutan section, visibilitas, kontak, serta SEO. Simpan draft, preview, lalu publikasikan.
- `/admin/rfid`: perangkat, tag, pemasangan, pelepasan, dan kotak masuk hasil scan.

Halaman publik tidak menampilkan tautan login. Route admin tetap dilindungi autentikasi dan role; menyembunyikan tautan bukan pengganti pemeriksaan akses.

Konten awal tentang Sahira Farm adalah copy editorial sementara. Ganti dengan informasi faktual peternakan sebelum peluncuran. Foto adalah ilustrasi ras, bukan stok Sahira Farm. Kredit foto ada di `public/image-credits.html` dan `docs/IMAGE-CREDITS.md`.

## Supabase

Proyek yang dikonfigurasi: `kmpmrweumocxtxyfpjko`. Tiga migration awal telah diterapkan, media bucket tersedia, konten Sahira Farm sudah dipublikasikan, dan fungsi `rfid-ingest` telah dideploy. Versi company profile lama diarsipkan, bukan dihapus.

Admin awal yang diizinkan: `sahira.admin@sahirafarm.com`. Pengguna perlu membuat kata sandi sendiri melalui **Aktifkan akun** di `/admin/akses`, lalu mengonfirmasi email. Email harus benar-benar dapat menerima pesan. Supabase Auth perlu mengizinkan URL callback sesuai origin aplikasi melalui Authentication → URL Configuration. Aktivasi email dan login akun nyata belum diuji dari browser.

Untuk proyek Supabase baru:

1. Terapkan berurutan migration pada `supabase/migrations`.
2. Jalankan `supabase/seed.sql` sekali untuk konten awal. Seed tidak menimpa versi publik yang sudah ada.
3. Tambahkan email admin terverifikasi ke `private.admin_allowlist` melalui operator database.
4. Deploy `supabase/functions/rfid-ingest` dengan `verify_jwt=false`; handler melakukan autentikasi token per perangkat. Secret service-role hanya berada di lingkungan Edge Function.
5. Isi `.env.local` frontend dan konfigurasi Auth redirect URL.

Nama tabel internal `sheep` dipertahankan agar relasi lama tetap kompatibel. Data operasional tidak dicampur dengan konten profil publik.

## Preview lokal tanpa database

Untuk QA antarmuka, jalankan Vite dengan `VITE_DEMO_MODE=true` pada environment proses. Mode ini hanya aktif pada development (`import.meta.env.DEV`), menggunakan localStorage, dan tidak mengakses Supabase. Data demo bukan data peternakan nyata. Konten preview redesign memakai namespace `editorial-v2` agar draft desain sebelumnya tetap tersimpan.

## ESP & RFID

Alurnya: buat profil ternak → daftarkan perangkat → pindai tag baru → pilih profil ternak untuk UID tersebut. Scan berikutnya terhubung dengan riwayat pemasangan. Tag tidak otomatis membuat profil ternak baru.

Panduan perangkat, payload HTTPS, penggantian tag, antrean offline, dan pengujian: [docs/RFID-ESP.md](docs/RFID-ESP.md).

Hardware fisik, wiring, dan firmware final masih membutuhkan model ESP, reader, tipe tag, serta sensor yang digunakan. Pembacaan bobot dari perangkat disimpan sebagai sensor reading; belum otomatis menjadi catatan pertumbuhan tervalidasi. Model ML produksi belum tersedia; aplikasi tidak mengarang skor prediksi.

## Validasi

`npm run build` memeriksa TypeScript dan build produksi; `npm test` memeriksa ADG, URL, komposisi ras, serta pemisahan draft/publik. Pengujian keamanan SQL dan handler RFID ada di `supabase/tests` dan `supabase/functions/rfid-ingest/handler_test.ts`.

Desain menggunakan warna solid tanpa gradasi, foto domba, slider manual dengan swipe/keyboard, dan dukungan reduced motion.
