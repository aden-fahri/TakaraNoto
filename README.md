# TakaraNoto (finflow_flutter)

Aplikasi pencatatan keuangan berbasis Flutter dengan **dua mode**: keuangan
pribadi (**TakaraNoto**: dompet utama + dompet E-Wallet, anggaran, tabungan,
statistik, riwayat) dan kas kelompok (**ZainNoto**: iuran anggota, tunggakan,
rekap).

📚 Dokumentasi lengkap: [`DOKUMENTASI.md`](DOKUMENTASI.md) — arsitektur, stack,
logic, tampilan, dan catatan penting.
📚 Khusus mode kas kelompok: [`ZAINNOTO.md`](ZAINNOTO.md).

## Fitur

- **Transaksi** — pemasukan/pengeluaran dengan kategori, catatan, tanggal.
- **Dompet E-Wallet** — saldo terpisah dengan transfer antar dompet
  ("Isi Saldo" / "Tarik"). Transfer dicatat sebagai sepasang transaksi
  (`is_transfer = 1`, `transfer_group` sama) dan **tidak dihitung** sebagai
  pemasukan/pengeluaran di statistik, anggaran, maupun riwayat.
- **Anggaran** — batas per kategori, mendukung **bulanan** (`goal`) dan
  **harian** (`daily_limit`, dikalikan jumlah hari pada bulan berjalan).
  Modal anggaran menyalin batas dari bulan lalu jika belum diatur.
- **Tabungan** — target tabungan dengan setor/tarik; kategori internal
  `Tabungan` / `Tarik Tabungan` tidak dapat dihapus.
- **Statistik** — donut pengeluaran/pemasukan per kategori, arus pengeluaran
  mingguan, ringkasan bulan (rata-rata harian, sisa anggaran), dan pemantauan
  pos anggaran (slider batas & realisasi). Navigasi bulan + ekspor CSV.
- **Riwayat** — filter tipe, filter kategori, pencarian catatan/kategori/
  nominal, hapus dengan undo (transfer memakai konfirmasi karena menghapus
  kedua sisi).

## Struktur Singkat

- `lib/services/database_helper.dart` — sqflite (versi 6) untuk `finflow.db`;
  di web memakai factory sqlite3 wasm + IndexedDB (di-set di `main.dart`)
  sehingga data tetap persisten di browser.
- `lib/providers/finance_provider.dart` — state utama aplikasi.
- `lib/utils/finance_calc.dart` — perhitungan agregat (income, expense, net,
  batas anggaran) yang dipakai lintas layar.
- `lib/screens/` — dashboard, riwayat, anggaran, statistik, e-wallet, tabungan.
- `lib/widgets/` — modal transaksi/anggaran, donut chart.
- `lib/zainnoto/` — logika mode kas kelompok (ZainNoto).

## Pengembangan

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
