# Fase 3: Spesifikasi tampilan (untuk AI pelaksana)

Sumber kebenaran tampilan = berkas HTML di `docs/mockup/*.dc.html` (baca sebagai teks; CSS-nya memuat ukuran persis). Dokumen ini merangkum angkanya dan memetakan ke layar Flutter. Bila HTML dan dokumen ini berbeda, HTML yang berlaku, lalu laporkan perbedaannya.

Lebar acuan 390 dp. Semua ukuran dalam dp. Font Poppins (sudah dibundel). Tanpa gradient. Semua warna lewat `AppTokens` (jangan tulis angka warna di layar).

## 1. Token warna (Plum Klasik = bawaan)

Lihat tabel di `desain.md` bagian 3.1 (terang dan gelap) dan 3.2 (Teal). Pemetaan nama mockup ke `AppTokens`: `hd`=header, `pg`=latar halaman, `card`, `bd`=garis, `tx`, `mu`=teks sekunder, `inc`, `exp`, `ac`=aksen, `onac`, `soft`, `chip`, `nav`, persik `#F4C99A` (kartu saldo).
Tema: Plum Klasik (default) dan Teal, masing-masing terang dan gelap. Pilihan tema tersimpan dan dipulihkan.

## 2. Komponen bersama (buat sekali, pakai di semua layar)

| Komponen | Ukuran |
|---|---|
| Header | latar `hd`, sudut bawah radius 32, padding atas 18 kiri-kanan 16 bawah 24 (Home: tinggi 172 dengan kartu saldo menimpa) |
| Tombol header | 40 tinggi, radius 14, latar `chip`, border 1 putih 25%, teks 12/600. Tombol palet 40x40 (ikon palet 20). Tombol mode: ikon panah 16 + nama aplikasi tujuan, padding horizontal 12, jarak 6 |
| Judul header | 24/600 putih. Baris atas 12 warna `#E7CFE0` (sapaan atau chip grup) |
| Chip grup | tinggi 24, radius 12, padding 0 10, latar `chip`, teks 11/600, titik 7 persik |
| Kartu | latar `card`, border 1 `bd`, radius 24, padding 16 |
| Tile | radius 20, padding 12, border 1 `bd` |
| Baris daftar | padding vertikal 12, pemisah 1 `bd`, ikon kotak 42x42 radius 14 (latar `soft`), judul 13/500, keterangan 12 `mu`, nominal 600 |
| Lencana status | pil, teks 11/600, padding 4x10. Lunas `#D5F1E4`/`#065F46`, Telat `#FBDADF`/`#8F1D2C`, Cicil `#FBE8C4`/`#7A4A05` |
| Navbar | tinggi 76, latar `nav` (putih terang), border atas 1 `bd`, sudut atas radius 24; item: ikon 22 + label 11/500; aktif: teks `ac`, latar `soft`, indikator atas 3x28 radius 2 |
| FAB | kanan 16, bawah 92, tinggi 52, padding horizontal 22, radius 26, latar `ac`, teks `onac` 14/600, ikon + 18 |
| Tombol utama | tinggi 50 sampai 52, radius 25 sampai 26 (pil), latar `ac`, teks 14/600 |
| Toggle segmen | latar `soft`, radius 999, padding 3; item padding vertikal 9, teks 12/600; aktif latar `ac` teks `onac` |
| Lembar bawah | radius atas 28, padding 12/20/24, handle 40x4 radius 2 warna `#DCCBD6`, kolom isian tinggi 52 radius 16 latar `pg` border `bd`, latar belakang diredam |

## 3. Kartu saldo bertakik (NotchedCard)

Lebar kartu 358 (lebar layar minus 32), tinggi 214, tepat di bawah header (atas 96). Takik di kanan atas: lebar 108 (sekitar 30% dari lebar, buat responsif), tinggi 44, radius 16 di sudut dalam takik, 24 di sudut luar. Path SVG acuan ada di `desain.md` bagian 4. Chip bulan di dalam takik (kanan 10, atas 6, tinggi 32, latar `chip`, teks 12/600). Isi: label 12/500 opacity .8, angka saldo 32/600, dua kotak kecil (latar teks 8%, radius 16, padding 10x12, label 11/500, angka 14/600), garis pemisah, baris ringkasan 12.
Sudah ada `notched_card_test.dart`; pertahankan dan sesuaikan.

## 4. Peta layar mockup ke layar Flutter

| Berkas mockup | Layar app | Catatan |
|---|---|---|
| Main.dc.html, Dashboard-gelap.dc.html, Dashboard-kosong.dc.html | `dashboard_screen.dart` | Home TakaraNoto: header, kartu notch, 3 tile dompet, "Transaksi terbaru", FAB, empty state. TANPA statistik |
| ZN-Grup.dc.html | pemilih grup | |
| ZN-Beranda.dc.html | tab Kas (shell Zain) | 4 tile persegi (Anggota, Setor kas, Pengeluaran, Pengaturan), progres iuran, tunggakan, aktivitas |
| ZN-Iuran.dc.html, ZN-Matriks.dc.html | tab Iuran Kas | toggle Checklist/Matriks; checklist lingkaran 28; matriks sel 30x30 radius 10, kolom anggota 72 lalu 4 kolom sama lebar, tinggi baris 48 |
| ZN-Transaksi.dc.html | tab Riwayat Zain | garis waktu: padding kiri 34, garis vertikal x=11 lebar 2 `#E6D6C6`, titik 24 (border 2); pencarian tinggi 46 radius 23; chip filter tinggi 34 |
| ZN-Statistik.dc.html | tab Statistik Zain | batang 20 lebar (radius atas 6, datar), bar bertumpuk tinggi 22 radius 11 |
| ZN-Anggota.dc.html | layar Anggota (dibuka dari tile) | grid 2 kolom jarak 12, kartu radius 24 padding 16x14, avatar 56 radius 20 |
| ZN-Detail.dc.html | detail anggota | |
| ZN-Bayar.dc.html, ZN-KasKeluar.dc.html | lembar bawah | |
| ZN-Pengaturan.dc.html | pengaturan grup | baris tinggi 58; baris "Tema warna" |

Navigasi: TakaraNoto = Home, Riwayat, Anggaran, Tabungan, Laporan (hanya Home yang berubah tampilannya, yang lain ikut tema, header, navbar baru). ZainNoto = Kas, Iuran kas, Statistik, Riwayat (Anggota BUKAN tab).
Pembeda wajib: Anggota (direktori kotak), Riwayat (garis waktu), Statistik (grafik) harus terlihat berbeda.

## 5. Yang belum ada mockupnya (JANGAN dikerjakan sebelum mockup datang)

Pemilih tema (sheet dari ikon palet), mode gelap layar Zain, tema Teal gelap, dialog hapus kategori dengan pindahkan, dialog konfirmasi hapus + Batal, ikon info penjelasan dua saldo, Riwayat/Anggaran/Tabungan/Laporan versi baru. Untuk ini: pakai komponen bersama dan token, tampilan minimal, tandai di laporan.

## 6. Cara memverifikasi tanpa gambar

AI pelaksana tidak bisa membaca gambar. Gunakan:
- Widget test yang mengukur: `tester.getSize` (tinggi navbar 76, header radius, tile 40x40, FAB tinggi 52), `find.byKey`, warna dari `AppTokens` (bukan hex di layar), tidak ada `RenderFlex overflow` pada 320 dp dan textScale 1,3, label <= 2 baris.
- Tes kontras: teks vs latar >= 4,5 untuk pasangan token (terang dan gelap, tiap tema).
- Gerbang 3 (tangkapan layar dibandingkan dengan mockup) dilakukan PEMILIK, bukan AI.
