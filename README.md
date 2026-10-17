# TakaraNoto (finflow_flutter)

Aplikasi pencatatan keuangan pribadi berbasis Flutter: dompet utama + dompet
E-Wallet, anggaran, tabungan, statistik, dan riwayat transaksi.

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

- `lib/services/database_helper.dart` — sqflite (versi 6) + fallback in-memory
  untuk web. Migrasi v6 menambahkan kolom `is_transfer` / `transfer_group`
  dan mengubah baris "Top Up" lama menjadi pasangan transfer.
- `lib/providers/finance_provider.dart` — state utama aplikasi.
- `lib/utils/finance_calc.dart` — perhitungan agregat (income, expense, net,
  batas anggaran) yang dipakai lintas layar.
- `lib/screens/` — dashboard, riwayat, anggaran, statistik, e-wallet, tabungan.
- `lib/widgets/` — modal transaksi/anggaran, donut chart.

## Keterbatasan Diketahui

- **Web**: data hanya tersimpan in-memory (hilang saat refresh). Persistence
  web (mis. `sqflite_common_ffi_web` / IndexedDB) belum diimplementasikan.

## Pengembangan

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
