# TakaraNoto dan ZainNoto: Desain dan Master Prompt

Dokumen ini merangkum semua yang sudah diputuskan dan dibuat sampai 20 Oktober 2026, lalu menutup dengan master prompt untuk AI pelaksana (tampilan dan logika yang belum dikerjakan).

Sumber: repo `aden-fahri/TakaraNoto` (commit `a47d063`, akses baca), rencana perbaikan "Rencana Perbaikan TakaraNoto: Logika dan Tampilan", dan kanvas mockup "Mockup TakaraNoto dan ZainNoto" (14 layar).

Catatan kejujuran: mockup belum pernah saya lihat sebagai gambar, hanya ditulis sebagai kode. Logika dibaca dari kode, belum dijalankan, karena Flutter tidak bisa dipasang di lingkungan saya.

---

## 1. Gambaran produk

Satu aplikasi Flutter (paket `finflow_flutter`), satu database `finflow.db`, dua mode:

| | TakaraNoto | ZainNoto |
|---|---|---|
| Mode | Pribadi | Kelompok (kas bersama) |
| Untuk | Uang pribadi: dompet, anggaran, tabungan | Kas RT, arisan, panitia: iuran anggota |
| Pindah mode | Tombol "ZainNoto" di header | Tombol "TakaraNoto" di header |

Keputusan produk yang berlaku:

- **Satu database.** Data lama `zainnoto.db` dibuang (keputusan pemilik), tanpa importer. Cukup dicatat di catatan rilis.
- **Tanpa gradient** di seluruh aplikasi. Semua warna datar.
- **Home TakaraNoto tanpa statistik.** Statistik ada di menu Laporan.
- **Warna bawaan: Plum Klasik.** Teal adalah tema alternatif.
- **Navbar putih** di semua halaman (terang).
- Belanja lewat E-Wallet masuk statistik dan anggaran. Setor dan tarik tabungan dipisah dari pemasukan dan pengeluaran lewat flag `is_savings`. Transfer antar dompet bukan pengeluaran.
- Anggota baru ditagih mulai periode bergabung (`joined_at`), bukan semua periode lama.

## 2. Navigasi

**TakaraNoto** (5 menu, hanya Home yang didesain ulang):

`Home` · `Riwayat` · `Anggaran` · `Tabungan` · `Laporan`

**ZainNoto** (4 menu):

`Kas` · `Iuran kas` · `Statistik` · `Riwayat`

Anggota tidak punya tab. Ia dibuka dari tile persegi di dashboard Kas, bersama tile Setor kas, Pengeluaran, dan Pengaturan. Alasan: navbar sudah penuh dengan 4 menu, dan tile menjaga aksi kelompok tetap satu ketukan. Burger menu dipertimbangkan dan ditolak karena menyembunyikan fitur.

## 3. Token desain

### 3.1 Warna, tema Plum Klasik (bawaan)

| Token | Terang | Gelap |
|---|---|---|
| `hd` header | `#381932` | `#2B1530` |
| `pg` latar halaman | `#FFF3E6` (krem) | `#1D1020` |
| `card` | `#FFFFFF` | `#2A1A2E` |
| `bd` garis | `#F0E4D6` | `#4A3050` |
| `tx` teks | `#2A1426` | `#F6EEF4` |
| `mu` teks sekunder | `#6B5A68` | `#B7A3B5` |
| `inc` pemasukan | `#047857` | `#5EE0A8` |
| `exp` pengeluaran | `#BE123C` | `#FF8FA3` |
| `ac` aksen (tombol, nav aktif) | `#381932` | `#F4C99A` |
| `onac` teks di atas aksen | `#FFFFFF` | `#2A1426` |
| `soft` latar lembut | `#F4ECEF` | `#382340` |
| `chip` chip dan tombol header | `#52294A` | `#4A2A50` |
| `nav` | `#FFFFFF` | `#2A1A2E` |
| persik (kartu saldo) | `#F4C99A` | `#F4C99A` |
| transfer | `#3F51B5` | `#3F51B5` |

Lencana status (sama di terang dan gelap sebagai pasangan latar/teks):

| Status | Latar | Teks |
|---|---|---|
| Lunas | `#D5F1E4` | `#065F46` |
| Telat | `#FBDADF` | `#8F1D2C` |
| Cicil | `#FBE8C4` | `#7A4A05` |

### 3.2 Tema alternatif: Teal

Nilai dari mockup teal v3 (pemilik menilai "udah bagus", tidak jadi bawaan): header `#0F3D3A`, halaman `#F3F1EB`, kartu `#FBFAF7`, garis `#E3DFD3`, teks `#0B2B2A`, sekunder `#5E6F6C`, kartu saldo pasir `#F2D3A0`, aksen `#10B981`, lembut `#E8EFEC`, chip `#1C5A55`.
Aturan navbar putih tetap berlaku di Teal (usulan saya, belum dikonfirmasi pemilik). Token gelap Teal belum didefinisikan.

### 3.3 Tipografi dan bentuk

- Font **Poppins** (400, 500, 600). Judul header 24, judul halaman 18, judul kartu 15, isi 13, keterangan 12, lencana 11.
- Radius: kartu 24, tile 20, tombol header 14, chip dan tombol penuh 999 (pil), lembar bawah 28 di sudut atas.
- Ikon garis 2px, ujung bulat, tanpa emoji.
- Tinggi navbar 76. Header: sudut bawah membulat 32.

Semua layar harus memakai `AppTokens` dan `AppText` yang sudah ada di kode, tanpa angka warna atau ukuran baru langsung di layar.

## 4. Komponen

**Header.** Dua baris di kiri: sapaan (Pribadi: ikon matahari + "Selamat pagi") atau chip grup (Kelompok: "● Kas RT 05 ⌄"), lalu judul aplikasi 24px. Di kanan: **tombol palet** 40×40 (membuka pilihan tema) dan **tombol mode** yang menyebut aplikasi tujuan ("⇄ ZainNoto" atau "⇄ TakaraNoto"). Halaman dalam (Anggota, Detail, Pengaturan) memakai tombol kembali 40×40 di kiri.

**Kartu saldo bertakik (notch).** Dibuat sebagai bentuk path SVG, bukan CSS (untuk Flutter: `CustomPainter` atau `ClipPath`). Ukuran contoh 358×214, takik kanan atas lebar 108 (sekitar 30%, harus responsif) dan tinggi 44, radius 16 di takik dan 24 di sudut luar. Path acuan:

```
M24 0H234A16 16 0 0 1 250 16V28A16 16 0 0 0 266 44H334A24 24 0 0 1 358 68V190A24 24 0 0 1 334 214H24A24 24 0 0 1 0 190V24A24 24 0 0 1 24 0Z
```

Isi: chip bulan di dalam takik (kanan 10, atas 6, tinggi 32), label dan angka saldo 32px, dua kotak kecil (Pemasukan, Pengeluaran), garis pemisah, baris ringkasan bawah.

**Tile.** Kotak putih, radius 20. Tile dompet (3 kolom) di TakaraNoto. Tile persegi aksi (ikon di atas, label di bawah) di dashboard Kas ZainNoto.

**Baris daftar.** Ikon dalam kotak 42×42 radius 14, judul 13/500, keterangan 12 abu, nominal di kanan 600, berwarna `inc` atau `exp`. Pemisah garis `bd`.

**Navbar.** Putih, garis atas, radius atas 24. Item aktif: teks `ac`, latar `soft`, indikator 3px di atas.

**FAB.** Hanya di Home TakaraNoto: "Tambah Transaksi", pil 52px, `ac`. Satu aksi utama per layar.

**Lembar bawah (sheet).** Untuk Bayar iuran dan Catat kas. Latar luar diredam, handle 40×4, kolom isian tinggi 52 radius 16, tombol utama 52 pil.

## 5. Layar TakaraNoto (Pribadi)

| # | Layar | Isi |
|---|---|---|
| 1 | Home (terang) | Header, kartu notch "Saldo keuangan Rp 477.000", Pemasukan Rp 364rb, Pengeluaran Rp 137rb, "Arus kas bulan ini + Rp 227.000", tile dompet (Dompet utama, E-Wallet, Tabungan), "Transaksi terbaru" 4 baris, FAB |
| 2 | Home (gelap) | Sama, token gelap, FAB persik |
| 3 | Home (belum ada data) | Semua Rp 0, empty state dengan satu tombol "Tambah transaksi pertama" |

Layar Riwayat, Anggaran, Tabungan, Laporan tidak diubah, hanya mengikuti tema plum, navbar putih, dan header baru.

## 6. Layar ZainNoto (Kelompok)

Data contoh seragam: grup **Kas RT 05**, 8 anggota (Budi, Sari, Andi, Dewi, Rudi, Maya, Joko, Lina), iuran Rp 50.000 per bulan, jatuh tempo tanggal 10, mulai 1 Jul 2026. Status Okt 2026: Budi, Sari, Andi, Rudi, Lina lunas; Maya cicil Rp 25.000; Dewi telat 2 periode (Rp 100.000); Joko telat (Rp 50.000). Saldo kas Rp 2.350.000.

| # | Layar | Isi dan ciri khas |
|---|---|---|
| 4 | Pilih grup | Daftar grup (Kas RT 05, Arisan Keluarga, Panitia Reuni), Buat grup baru, Gabung dengan kode |
| 5 | Kas (dashboard) | Kartu notch "Saldo kas bersama", Masuk/Keluar, 4 tile persegi (Anggota, Setor kas, Pengeluaran, Pengaturan), progres iuran, Tunggakan, aktivitas kas terbaru |
| 6 | Iuran kas, Checklist | Toggle Checklist/Matriks, pemilih periode, lingkaran centang per anggota, lencana status |
| 7 | Iuran kas, Matriks | Grid anggota × bulan (Jul sampai Okt) dengan kotak OK, !, ½, -, dan legenda |
| 8 | Riwayat | **Garis waktu**: pencarian, chip filter, dikelompokkan per tanggal dengan garis vertikal dan titik, tanpa kartu |
| 9 | Statistik | **Grafik**: batang masuk vs keluar per bulan, bar bertumpuk asal pemasukan, peringkat kontributor, dua angka ringkas |
| 10 | Anggota | **Direktori**: kotak 2 kolom dengan avatar inisial, peran, status; tombol Tambah anggota. Dibuka dari tile |
| 11 | Detail anggota | Header dengan avatar, kartu persik "Belum dibayar Rp 100.000", tombol Bebaskan dan Bayar sekarang, daftar tagihan, data anggota |
| 12 | Bayar iuran | Lembar bawah: jumlah, Lunasi semua / nominal / Cicil, tanggal, catatan, penjelasan kredit |
| 13 | Setor atau pengeluaran | Lembar bawah dengan toggle Setor kas / Pengeluaran, jumlah, keperluan, tanggal, pencatat |
| 14 | Pengaturan | Iuran (nominal, jatuh tempo, mulai berlaku, kredit otomatis), Tampilan (Tema warna: Plum Klasik, mode gelap), Grup (kode undangan, bendahara, keluar) |

**Tiga layar yang sengaja dibedakan** (permintaan pemilik): Anggota = direktori kotak, Riwayat = garis waktu, Statistik = grafik. Ketiganya tidak boleh terlihat seperti daftar yang sama.

## 7. Aturan UI lintas layar

1. Satu aksi utama per layar. Tidak ada tombol tambah ganda.
2. Label satu baris dengan `maxLines: 1` dan ellipsis. Tidak ada label yang membungkus lebih dari dua baris pada lebar 320 dp dengan `textScaleFactor` 1,3.
3. Kontras teks minimal 4,5. Warna aktif di mode gelap memakai `ac` terang (`#F4C99A`), bukan plum di atas kartu gelap.
4. Statistik ZainNoto menampilkan "Belum ada data" saat belum ada periode, bukan "100% Tertib".
5. Empty state punya ilustrasi kecil dan satu tombol aksi.
6. Ikon dan status tidak hanya mengandalkan warna: lencana selalu punya teks, sel matriks punya simbol.
7. Ikon palet selalu terlihat di header, tidak disembunyikan di pengaturan.

## 8. Status

Selesai:

- Rencana perbaikan (lima fase) di Claude Docs.
- 14 layar mockup di kanvas (plum default, terang; gelap hanya untuk Home).
- B1 sampai B5 sudah benar di commit `a47d063`: ganti frekuensi iuran (`_replaceUnpaidPeriods`), idempotensi `client_ref`, ringkasan tunggakan menyaring anggota terhapus, hapus transaksi ikut menghapus alokasi dan kredit.
- Satu database `finflow.db` di repo.

Belum dikerjakan (isi master prompt di bawah):

- CI GitHub, data contoh debug, tes invarian, tes layar sempit (Fase 0).
- Penjelasan dua angka saldo, hapus kategori yang aman, satu sumber kebenaran saldo (Fase 1).
- Pembuktian tiga dugaan ZainNoto: kredit menganggur, hapus pembayaran yang kreditnya terpakai, `due_day` mingguan (Fase 2).
- Implementasi semua layar mockup, sistem tema, mode gelap Zain dan layar lain (Fase 3b).
- Kode mati, font lokal, branding iOS, backup (Fase 4).

Belum dimockup: mode gelap untuk 11 layar ZainNoto, pemilih tema (sheet yang dibuka ikon palet), tema Teal, dialog hapus kategori, dialog konfirmasi, dan layar Riwayat/Anggaran/Tabungan/Laporan versi plum. Ini perlu mockup sebelum diimplementasi.

---

## 9. Master prompt

Salin semua di bawah ini ke AI pelaksana (misalnya Claude Code di dalam repo).

````
PERAN
Kamu adalah engineer Flutter yang memperbaiki aplikasi TakaraNoto (paket finflow_flutter) di repo ini. Bahasa antarmuka: Indonesia. Kerjakan fase demi fase. Jangan lompat fase. Tiap fase berakhir di sebuah GERBANG. Berhenti dan laporkan bukti sebelum lanjut.

KONTEKS PRODUK
- Satu aplikasi, satu database finflow.db, dua mode: TakaraNoto (Pribadi) dan ZainNoto (Kelompok, kas bersama dengan iuran anggota).
- Data lama zainnoto.db DIBUANG. Jangan membuat importer. Cukup catat di catatan rilis.
- DILARANG memakai gradient di mana pun. Semua warna datar.
- Home TakaraNoto TIDAK memuat statistik.
- Aturan akuntansi yang harus dipertahankan: transfer antar dompet bukan pemasukan atau pengeluaran; setor dan tarik tabungan dipisah lewat flag is_savings; belanja E-Wallet masuk statistik dan anggaran; anggota baru ditagih mulai periode joined_at.
- B1 sampai B5 (ganti frekuensi iuran, idempotensi client_ref, ringkasan tunggakan, hapus transaksi menghapus alokasi dan kredit) sudah benar di commit a47d063. Jangan dikerjakan ulang. Cukup pertahankan dan lindungi dengan tes.

ATURAN KERJA
1. Tulis tes DULU, lalu perbaikan. Tes yang gagal pada kode sekarang itu wajar; itu daftar kerjamu.
2. Perubahan kecil per butir. Jalankan flutter analyze dan flutter test sebelum menyatakan selesai. Jangan klaim "sudah benar" tanpa output perintah itu.
3. Jangan mengubah skema database tanpa migrasi bernomor dan tes migrasi (pola v6 ke v7 dan v7 ke v8). Buat cadangan sebelum migrasi.
4. Semua warna dan ukuran lewat AppTokens dan AppText. Dilarang angka warna atau ukuran baru langsung di layar.
5. Jangan ubah perilaku di luar butir yang diminta. Bila menemukan hal lain, catat di daftar temuan, jangan diperbaiki diam-diam.
6. Bila sesuatu tidak bisa kamu verifikasi (misalnya tampilan di perangkat), katakan terus terang. Jangan menebak.

======== FASE 0: PENGAMAN ========
a) Tambah .github/workflows/ci.yml: on push dan pull_request; checkout, subosito/flutter-action (stable, cache), apt install libsqlite3-dev, flutter pub get, flutter analyze, flutter test.
b) Tombol "Isi data contoh" di pengaturan, tampil HANYA saat kDebugMode. Isi: transaksi 3 bulan, 1 transfer, 1 tujuan tabungan, anggaran, 1 grup "Kas RT 05" dengan 8 anggota (Budi, Sari, Andi, Dewi, Rudi, Maya, Joko, Lina), iuran Rp 50.000 per bulan jatuh tempo tanggal 10 mulai 1 Jul 2026, campuran status lunas / cicil / telat (Maya cicil Rp 25.000, Dewi telat 2 periode, Joko telat 1 periode).
c) Tes invarian (harus gagal bila angka tidak cocok):
   - TakaraNoto: saldo utama + E-Wallet + tabungan = pemasukan bersih kumulatif (tanpa transfer dan tabungan).
   - Dua sisi transfer sama nilainya per transfer_group.
   - Jumlah kategori di donat = total pengeluaran.
   - Menghapus tujuan tabungan tidak mengubah total bulanan.
   - ZainNoto: alokasi per tagihan <= amount_due; alokasi + kredit = nominal transaksi.
   - Satu tagihan per anggota per periode.
   - Total tunggakan = jumlah daftar tunggakan.
   - Tidak ada periode tumpang tindih setelah frekuensi diganti.
   Jalankan invarian pada data contoh DAN data acak (seed tetap, dicatat di log tes).
d) Tes layar sempit: widget test lebar 320 dp, textScaleFactor 1,3 untuk dashboard, dashboard Kas Zain, Iuran kas, Statistik. Gagal bila ada RenderFlex overflow atau label membungkus lebih dari dua baris.
GERBANG 0: CI hijau di main dan semua tes invarian ada. Laporkan daftar tes yang gagal.

======== FASE 1: LOGIKA TAKARANOTO ========
1. Dua angka saldo. "Saldo bulan ini" diganti label "Selisih bulan ini"; "Uang riil" menjadi "Total uang di dompet utama". Tambah ikon info yang menjelaskan beda keduanya. Pakai satu rumus bersama di finance_provider.dart.
2. Hapus kategori. Ganti cascade permanen dengan hapus lembut (kolom deleted_at, migrasi v8 ke v9) ATAU pilihan "pindahkan transaksi ke kategori lain". Dialog wajib menampilkan jumlah transaksi dan anggaran yang terdampak. File: database_helper.dart, manage_categories_modal.dart.
3. Sumber kebenaran saldo. refreshMonthlyDetails memuat saldo, total, dan donat lewat query terpisah dan catch yang hanya mencatat log. Ganti dengan SATU hasil ringkasan per bulan, dimuat bersama dan state diganti sekaligus. Bila gagal, tampilkan error di layar, jangan diam.
4. Semua tes invarian TakaraNoto hijau pada data contoh dan data acak.
GERBANG 1: invarian hijau; hitung manual tiga bulan data contoh dan cocokkan dengan dashboard, statistik, dan anggaran. Sertakan tabel hitungannya di laporan.

======== FASE 2: LOGIKA ZAINNOTO ========
Tiga dugaan. Tiap dugaan ditulis sebagai tes DULU. Perbaiki hanya bila tes gagal; bila lulus, tes tetap sebagai pelindung permanen.
1. Kredit menganggur: anggota bayar lebih, tagihan dibebaskan lalu dibatalkan. Kredit harus terpakai atau tetap tercatat, tidak hilang. Periksa _consumeCredits yang kini hanya dipanggil saat periode baru dibuat; pertimbangkan memanggilnya juga saat tagihan dibatalkan bebas dan saat anggota baru ditambahkan.
2. Hapus pembayaran yang kreditnya sudah terpakai: setelah sumber dihapus, total saldo kas dan status tagihan harus tetap konsisten (tidak ada tagihan lunas tanpa dana).
3. due_day mingguan: tetapkan 1 = Senin. Tes tanggal jatuh tempo lintas bulan dan lintas tahun.
Lalu jalankan semua invarian ZainNoto pada data acak: anggota keluar-masuk, ganti nominal dan frekuensi, bayar lebih, hapus, bebaskan.
GERBANG 2: semua tes ZainNoto hijau; alur lengkap di data contoh (tambah anggota, bayar, bayar lebih, hapus, ganti frekuensi) berjalan tanpa layar memuat tersangkut.

======== FASE 3: TAMPILAN ========
Prasyarat: mockup yang disetujui pemilik (kanvas "Mockup TakaraNoto dan ZainNoto"). Bila ada layar yang belum dimockup (lihat daftar di bawah), BERHENTI dan minta mockupnya dulu.

A. Sistem tema
- Dua palet: Plum Klasik (BAWAAN) dan Teal. Tiap palet punya set terang dan gelap. Nilai warna ada di docs/desain.md bagian 3. Teal gelap belum ada: minta pemilik atau usulkan dan minta persetujuan.
- Ikon palet SELALU terlihat di header (40x40, radius 14, latar chip) dan membuka lembar pilihan tema. Pengaturan juga punya baris "Tema warna".
- Navbar putih (terang) di semua tema. Mode gelap memakai token nav gelap.
- Tema tersimpan dan dipulihkan saat aplikasi dibuka.

B. Header (semua layar utama)
- Kiri: sapaan atau chip grup, lalu judul 24px. Kanan: tombol palet dan tombol mode yang menyebut aplikasi tujuan ("ZainNoto" di Pribadi, "TakaraNoto" di Kelompok). Teks satu baris, ellipsis.

C. TakaraNoto
- Home: kartu notch (CustomPainter atau ClipPath, takik ~30% lebar, responsif), chip bulan di dalam takik, tile dompet 3 kolom, "Transaksi terbaru", satu FAB "Tambah Transaksi". Tanpa statistik. Empty state: ilustrasi kecil + satu tombol "Tambah transaksi pertama".
- Navbar: Home, Riwayat, Anggaran, Tabungan, Laporan. Layar selain Home hanya ikut tema, header, dan navbar baru.

D. ZainNoto
- Navbar: Kas, Iuran kas, Statistik, Riwayat.
- Kas: kartu notch "Saldo kas bersama", 4 tile persegi (Anggota, Setor kas, Pengeluaran, Pengaturan), progres iuran, Tunggakan, aktivitas kas.
- Iuran kas: toggle Checklist | Matriks (checklist: lingkaran centang + lencana; matriks: grid anggota x bulan dengan OK, !, 1/2, -, lebar kolom anggota tetap, header sejajar).
- Statistik: grafik (batang masuk vs keluar, bar bertumpuk asal pemasukan, peringkat kontributor). "Belum ada data" bila periode nol.
- Riwayat: garis waktu per tanggal dengan pencarian dan chip filter.
- Anggota (dari tile): direktori kotak 2 kolom. Detail anggota: kartu "Belum dibayar", Bebaskan, Bayar sekarang, daftar tagihan.
- Anggota, Riwayat, dan Statistik HARUS terlihat berbeda satu sama lain (kotak, garis waktu, grafik).
- Sheet Bayar iuran dan Catat kas (toggle Setor kas | Pengeluaran). Pilih grup. Pengaturan (iuran, tampilan, grup).

E. Aturan umum
- Satu aksi utama per layar. Lingkaran dekoratif di belakang konten dan diredam. Teks sekunder di atas plum memakai token turunan dengan kontras >= 4,5.
- Mode gelap: aksen nav, chip, dan tombol memakai token terang #F4C99A, bukan plum.

GERBANG 3: tangkapan layar data contoh, terang dan gelap, lebar 320 dan 411 dp, dicocokkan satu per satu dengan mockup; tes layar sempit hijau.

======== FASE 4: RAPIKAN DAN SIAP RILIS ========
- Hapus lib/screens/zainnoto/tabs/lainnya_tab.dart (1.183 baris, tidak diimpor di mana pun). Jalankan flutter analyze untuk memastikan tidak ada referensi tersisa.
- Sertakan font Poppins sebagai aset (sekarang diunduh lewat google_fonts).
- iOS dan branding: nama aplikasi, bundle id, dan ikon disamakan dengan TakaraNoto.
- Backup: pengingat cadangan berkala; uji ekspor lalu impor di web dan Android, karena satu finflow.db memuat dua mode.
- Catatan rilis: sebutkan data zainnoto.db lama tidak dibawa.
GERBANG 4: CI hijau, build rilis Android berhasil, ekspor lalu impor cadangan mengembalikan angka yang sama.

FORMAT LAPORAN TIAP FASE
1. Ringkasan: apa yang berubah (daftar file).
2. Bukti: output flutter analyze dan flutter test (tempel ringkasannya).
3. Tes baru dan apakah gagal dulu sebelum diperbaiki.
4. Temuan di luar lingkup (tidak diperbaiki).
5. Yang tidak bisa kamu verifikasi.
Tunggu persetujuan pemilik sebelum fase berikutnya.
````

## 10. Layar yang perlu dimockup sebelum Fase 3

1. Lembar pemilih tema (dibuka ikon palet): Plum Klasik, Teal, pratinjau, terang/gelap.
2. Mode gelap 11 layar ZainNoto, dan Teal (terang dan gelap) untuk Home dan Kas.
3. Dialog hapus kategori dengan jumlah transaksi terdampak.
4. Dialog konfirmasi hapus transaksi dan snackbar Batal.
5. Penjelasan dua angka saldo (ikon info) di Home.
6. Riwayat, Anggaran, Tabungan, Laporan TakaraNoto dalam header dan navbar baru.
