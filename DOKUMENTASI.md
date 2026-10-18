# TakaraNoto — Dokumentasi Keseluruhan (Fitur, Logic, Tampilan & Stack)

Dokumen ini merangkum **seluruh aplikasi TakaraNoto** secara keseluruhan: konsep, stack teknologi, bahasa yang dipakai, arsitektur, logic keuangan pribadi (mode TakaraNoto), logic kas kelompok (mode ZainNoto), tampilan UI, tema, backup, platform, dan test.

- **Nama aplikasi**: TakaraNoto • **Package**: `finflow_flutter` • **Versi**: `1.0.0+1`
- **Dart SDK**: `^3.11.0` (Flutter stable)
- Dokumen pendamping: [`ZAINNOTO.md`](ZAINNOTO.md) — pembahasan mendalam khusus mode kas kelompok.

---

## 1. Ringkasan Aplikasi

TakaraNoto adalah aplikasi pencatatan keuangan berbasis **Flutter** dengan **dua mode** dalam satu aplikasi:

| Mode | Nama shell | Isi | Database |
|---|---|---|---|
| **Pribadi** | TakaraNoto | Keuangan pribadi: transaksi, anggaran, tabungan, E-Wallet, statistik, riwayat | `finflow.db` |
| **Kelompok** | ZainNoto | Kas kelompok: iuran anggota, tunggakan, periode, pembayaran FIFO, kredit, rekap WhatsApp | tabel `zn_*` di `finflow.db` |

- Perpindahan mode lewat tombol `ModeSwitchButton` (menampilkan mode tujuan: `ZainNoto →` / `TakaraNoto →`), diproses `AppModeGate`. Mode **tidak dipersist** — aplikasi selalu terbuka di mode Pribadi.
- Kedua mode memakai provider dan alur datanya masing-masing — state terpisah total, namun sejak **merger Fase 3** keduanya berbagi satu file DB (`finflow.db`) dengan tabel ZainNoto berprefix `zn_`. Jembatan antar-mode utama tetap **Backup & Restore**.

---

## 2. Stack Teknologi

| Lapisan | Teknologi |
|---|---|
| Bahasa & framework | **Dart 3 / Flutter** (Material 3), widget murni tanpa codegen |
| State management | **`provider` ^6.1.5** (`ChangeNotifierProvider` + `context.watch/read`) |
| Database | **SQLite** via **`sqflite` ^2.4.2** — satu file DB (`finflow.db` v8, sejak merger Fase 3) berisi tabel Pribadi + 9 tabel ZainNoto berprefix `zn_` |
| Web | **`sqflite_common_ffi_web` ^1.1.1** (sqlite3 wasm + **IndexedDB**) — set di `main.dart`; aset `web/sqlite3.wasm` + `web/sqflite_sw.js` ikut di-commit |
| Penyimpanan preferensi | **`shared_preferences` ^2.5.0** (warna tema + mode gelap) |
| Lokalisasi & format | **`intl` ^0.20.2** (`initializeDateFormatting('id')`, `NumberFormat` locale `id_ID`) |
| Tipografi | **Poppins** dibundel di `assets/fonts/` (6 weight) via **`google_fonts` ^6.2.1** — runtime fetching dimatikan, tampilan identik saat offline |
| Berbagi & file | **`share_plus` ^13.1.0** (backup & CSV), **`file_picker` ^13.1.0** (pilih file restore) |
| Utilitas | **`uuid` ^4.5.3** (ID ZainNoto), **`path`**, **`path_provider`** |
| Dev/test | `flutter_test`, **`sqflite_common_ffi` ^2.3.4** (DB in-memory untuk test), **`flutter_lints` ^6.0.0** |

---

## 3. Bahasa yang Digunakan

- **Bahasa pemrograman**: Dart (100% Flutter; tanpa Kotlin/Swift/JS kustom selain scaffold platform).
- **Bahasa antarmuka**: **Bahasa Indonesia** di seluruh teks UI ("Saldo Bulan Ini", "Tunggakan", "Bebas Iuran", dst.).
- **Format**: mata uang `Rp 1.234.567` (tanpa desimal, locale `id_ID`); tanggal disimpan `YYYY-MM-DD` sebagai TEXT dan ditampilkan dengan nama bulan Indonesia; timestamp ISO-8601 UTC.
- **Penamaan**: kode & komentar sebagian besar berbahasa Inggris, produk & UI berbahasa Indonesia.

---

## 4. Arsitektur Aplikasi

### Bootstrap (`lib/main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. **`ErrorWidget.builder` diganti** `_BuildErrorView` — kartu error merah berbahasa Indonesia yang terlihat (juga di release), mencegah kegagalan menyamar sebagai layar putih.
3. Jika web → `databaseFactory = databaseFactoryFfiWeb` (sqlite3 wasm + IndexedDB) sehingga **kedua DB persisten di browser**.
4. `initializeDateFormatting('id', null)`; status bar light.
5. `runApp` → `MyApp`: `MultiProvider` berisi:
   - `FinanceProvider` — state keuangan pribadi
   - `ThemeController()..load()` — tema tersimpan
   - `AppModeController` — mode aktif (in-memory)
   - `ZainNotoProvider` — state kas kelompok
6. `MaterialApp` (title `TakaraNoto`, `ThemeMode.light` dipaksa) → `SplashScreen(nextScreen: AppModeGate())`.

### Alur navigasi

```
SplashScreen (animasi ±1,8 dtk + tunggu load provider)
   └─► AppModeGate
         ├─ Pribadi ► MainNavigationScreen  (5 tab: Home, Riwayat, Anggaran, Tabungan, Laporan)
         └─ Kelompok ► ZainNotoShellScreen  (4 tab: Beranda, Iuran, Transaksi, Statistik)
```

Navigasi antar tab memakai `IndexedStack` + `PillNavBar` kustom (badge merah di tab Anggaran bila ada anggaran terpakai > 85%).

### Struktur direktori

```
lib/
├── main.dart                  # bootstrap, provider, mode gate, shell 5 tab
├── models/                    # FinanceTransaction, Category, Budget, SavingsGoal
├── providers/                 # FinanceProvider, AppModeController
├── services/                  # database_helper (finflow.db), backup_service
├── theme/                     # app_tokens, app_theme, theme_controller
├── utils/                     # finance_calc (agregat murni), rupiah_formatter
├── screens/                   # 10 layar mode pribadi + zainnoto/ (shell + 4 tab)
├── widgets/                   # modal & widget kustom bersama
└── zainnoto/                  # logika & data mode kelompok (lihat ZAINNOTO.md)
```

---

## 5. Mode Pribadi — Data & Logic

### 5.1 Skema `finflow.db` (versi 8)

| Tabel | Isi |
|---|---|
| `categories` | `name` UNIQUE, `icon`, `color`, `type CHECK income/expense`, **`is_savings`** (penanda aliran tabungan); **14 kategori awal** (Makanan, Transportasi, Gaji, Tabungan, Tarik Tabungan, Top Up, Transfer Masuk, …) — di-seed ulang bila kosong |
| `transactions` | `category_id` FK CASCADE, `amount REAL`, `type`, `date`, `note`, `savings_goal_id` FK SET NULL, `wallet_type` (`main`/`topup`), `is_transfer`, `transfer_group` |
| `budgets` | `category_id` FK CASCADE, `limit_amount`, `month_year`, `budget_type` (`goal`/`daily_limit`), **`UNIQUE(category_id, month_year)`** |
| `savings_goals` | `title`, `target_amount`, `created_at` |
| `zn_*` (9 tabel) | Tabel mode Kelompok: `zn_groups`, `zn_members`, `zn_dues_plans`, `zn_periods`, `zn_charges`, `zn_transactions`, `zn_allocations`, `zn_member_credits`, `zn_audit_log` — dibuat oleh migrasi **v8** (lihat `ZAINNOTO.md` §3) |

- **Tidak ada tabel dompet** — dompet **virtual** lewat kolom `wallet_type`; saldo selalu dihitung (derived).
- Migrasi v3–v6: recreate tabel, tambah `wallet_type`, lalu v6 menambah `is_transfer`/`transfer_group` dan **mengubah baris "Top Up" lama menjadi pasangan transfer**.
- Migrasi **v7**: tambah `categories.is_savings` (di-set 1 untuk `Tabungan` & `Tarik Tabungan`) dan **bangun ulang `budgets`** dengan UNIQUE komposit `(category_id, month_year)` — sebelumnya `category_id` UNIQUE global sehingga anggaran bulan kedua untuk kategori yang sama selalu gagal (`UNIQUE constraint failed`).
- Migrasi **v8 (merger Fase 3)**: `finflow.db` kini juga memuat seluruh tabel ZainNoto berprefix `zn_` (`createZainNotoSchema`, semua `IF NOT EXISTS`); data lama dari `zainnoto.db` sengaja tidak dimigrasikan (tidak ada data riil) dan file `zainnoto.db` lama menjadi yatim di disk. Format file backup **tidak berubah**: ekspor tetap memakai kunci `zainnoto` dengan nama tabel lama sehingga backup lama tetap bisa direstore ke tabel `zn_*`.
- **Tanpa soft delete** di mode ini; hapus bersifat permanen (kategori → cascade transaksi+anggaran).

### 5.2 Konvensi tanda & aturan hitung (inti logic)

- **Statistik & anggaran menghitung semua dompet**, dengan `is_transfer = 0` dan **kategori `is_savings = 0`**; jadi belanja lewat E-Wallet (setelah di-top-up) tetap masuk laporan, sedangkan transfer antar dompet tidak pernah dihitung dua kali.
- **Transfer** dicatat sebagai **sepasang transaksi** (satu expense + satu income dengan `transfer_group` sama) dan **tidak pernah** menambah pemasukan/pengeluaran di laporan mana pun:
  - Isi Saldo: Dompet Utama (expense, kategori `Top Up`) ↔ E-Wallet (income, `Transfer Masuk`).
  - Tarik: kebalikannya.
  - Menghapus salah satu sisi ⇒ **kedua sisi terhapus** (via `transfer_group`).
- **Tabungan dipisah dari arus kas**: setor (`Tabungan`, expense) dan tarik (`Tarik Tabungan`, income) **tidak** masuk pemasukan/pengeluaran bulanan; keduanya diringkas sebagai **"Ditabung Bersih"** (Σ setor − Σ tarik) di Laporan. Klasifikasi memakai flag kategori `is_savings`, **bukan** tautan `savings_goal_id` — sehingga menghapus target tabungan tidak lagi mengubah laporan.
- **Saldo goal** = Σ setor − Σ tarik (via tautan `savings_goal_id`).
- **Saldo E-Wallet** = Σ income − Σ expense semua baris `wallet_type='topup'` (all-time).
- **Saldo utama**: "Saldo Bulan Ini" = income − expense bulan berjalan (aturan statistik); **"Uang Riil"** = saldo nyata dompet utama all-time — **semua** baris `wallet_type='main'` dihitung (termasuk top-up keluar dan setoran tabungan, karena uang benar-benar keluar dari dompet) sehingga isi saldo E-Wallet tidak lagi membuat total uang tampak bertambah.
- **Agregat murni** ada di `lib/utils/finance_calc.dart`: `daysInMonth`, `monthlyBudgetLimit` (`daily_limit × jumlah hari`, `goal` apa adanya), `sumIncome`, `sumExpense` (keduanya mengecualikan transfer dan kategori `is_savings`), `netBalance`, `budgetUsagePct`.

### 5.3 Anggaran

- Dua tipe: **Bulanan (`goal`)** dan **Harian (`daily_limit`)** — batas harian dikalikan jumlah hari bulan berjalan.
- Modal anggaran **menyalin batas dari bulan sebelumnya** bila belum diatur.
- Ambang warna progres: `> 0,85` merah (expense), `> 0,6` kuning (warning), sisanya hijau.
- Badge nav muncul bila ada anggaran terpakai > 85% (`FinanceProvider.hasBudgetAlert`).

### 5.4 API `FinanceProvider` (ringkas)

| Kelompok | Method |
|---|---|
| Load/refresh | `refreshAll`, `refreshMonthlyDetails`, `changeMonth(monthYear)` |
| Transaksi | `addTx`, `updateTx`, `deleteTx` (transfer ⇒ hapus berpasangan), `makeTransfer(toTopup, …)` |
| Tabungan | `addSavingsGoal`, `updateSavingsGoal`, `deleteSavingsGoal`, `addSavingTransaction` (setor), `withdrawSavingTransaction` (tarik) |
| Anggaran | `addOrUpdateBg` (async, aman double-tap), `deleteBg`, `getPreviousMonthBudget` |
| Kategori | `addCat`, `deleteCat` (diblokir untuk kategori sistem: Tabungan / Tarik Tabungan / Top Up / Transfer Masuk) |
| Saldo | `cumulativeBalance` (Uang Riil, dompet utama), `topupBalance` (E-Wallet), **`netSaved`** (Ditabung Bersih bulan berjalan) |
| Util | `formatCurrency` (locale `id_ID`) |

Setiap mutasi diikuti reload penuh (`refreshAll`/`refreshMonthlyDetails`) — sederhana, konsisten, tanpa cache parsial. Error ditelan ke `debugPrint` (lihat catatan §12).

---

## 6. Mode Pribadi — Tampilan (UI)

### Shell 5 tab (`MainNavigationScreen`)

Home · Riwayat · Anggaran · Tabungan · Laporan — `IndexedStack` + `PillNavBar` (pill geser, dot merah badge).

### Layar

| Layar | Isi utama |
|---|---|
| **Home** (`dashboard_screen.dart`) | Banner berwarna tema (sapaan per jam, `ModeSwitchButton`, tombol palet → Pengaturan Tema, logo), **kartu dompet `NotchedCard`** (Saldo Bulan Ini, tap → Riwayat Saldo; chip "Uang Riil"; ringkas masuk/keluar), kartu E-Wallet, 5 transaksi terbaru, FAB animasi melebar ("Tambah" ⇄ ikon +) |
| **Riwayat** | Navigasi bulan, pencarian (catatan/kategori/**nominal**), filter tipe & kategori (chip horizontal), dikelompokkan per tanggal + net harian, **swipe-to-delete dengan undo**; transfer pakai dialog konfirmasi |
| **Anggaran** | Kartu total (limit, terpakai, sisa) + **DonutChart** per kategori; tile per kategori dengan tombol Atur/Ubah → `BudgetModal` |
| **Tabungan** | Ringkasan total vs target; kartu goal dengan progres & **proyeksi** (laju harian dari umur goal ⇒ perkiraan tanggal tercapai); dialog setor/tarik/edit; FAB "Target Baru" |
| **Laporan** (`stats_screen.dart`) | Donut analitik Keluar/Masuk + legenda %; **arus pengeluaran mingguan** (5 bucket); ringkasan bulan (rata-rata harian, sisa anggaran, **Ditabung Bersih**); **monitor pos anggaran** (slider batas vs realisasi); tombol **Ekspor CSV** (share teks) |
| **Riwayat Saldo** (`monthly_balance_screen.dart`) | Akumulasi saldo bersih + daftar bulan (masuk/keluar/net) |
| **E-Wallet** (`topup_screen.dart`) | Saldo virtual, tombol **Isi Saldo / Tarik / Keluar**, riwayat transaksi E-Wallet, dialog transfer dengan validasi saldo |
| **Pengaturan Tema** (`theme_settings_screen.dart`) | Preset aksen & background + picker kustom (HSV & hex), preview kartu live, **toggle Mode Gelap**; pintasan Backup & Restore |
| **Backup & Restore** | Ekspor/share file JSON, pilih file → validasi → konfirmasi → restore; catatan khusus mode web |
| **Splash** | Animasi blobs, logo bercincin emas, wordmark "Takara"+"Noto" (emas), tunggu provider siap, transisi fade |

### Modal & dialog utama

- **`AddTransactionModal`** — sheet transaksi: toggle animated Keluar/Masuk, format ribuan inline, grid kategori 4 kolom, dropdown goal khusus kategori `Tabungan`, penyaring kategori per konteks (mis. `Transfer Masuk` selalu disembunyikan), edit transfer = **read-only** (hapus = kedua sisi), tombol Kelola Kategori.
- **`BudgetModal`** — atur batas bulanan/harian per kategori, prefill bulan lalu, hapus anggaran.
- **`ManageCategoriesModal`** — daftar + form kategori (pilihan ikon & warna), kategori sistem terkunci.
- Dialog tabungan (setor/tarik/edit goal), dialog transfer E-Wallet, dialog konfirmasi hapus.

### Widget kustom bersama

| Widget | Fungsi |
|---|---|
| `NotchedCard` | Kartu dengan potongan **notch step** di kanan-atas (+`buildNotchedCardPath`) — dipakai kartu dompet Home & ZainNoto |
| `DonutChart` | Cincin CustomPainter dengan slot center |
| `PillNavBar` | Nav bawah pill kustom + badge (dipakai kedua mode) |
| `DecorativeHeaderCircles` | Lingkaran dekoratif banner (`Positioned.fill`) |
| `ModeSwitchButton` | Tombol pindah mode (menampilkan mode tujuan) |
| `RupiahInputFormatter` | Masker input ribuan `Rp` (utils, bersama kedua mode) |

---

## 7. Tema & Desain

- **`AppTokens`** — `ThemeExtension` 20 warna semantik: `headerBg/Fg/Muted/Surface/Border`, `pageBg`, `card`, `softSurface(+Strong)`, `textPrimary/Muted`, `border`, `accent/onAccent`, `income` `#10B981`, `expense` `#F43F5E`, `warning` `#FBBF24`, `incomeOnHeader`, `expenseOnHeader`, `transfer` `#3F51B5`. Diakses dengan `context.tokens` di seluruh layar; otomatis berbalik ke varian gelap saat mode gelap aktif.
- **Skala tipografi `AppText` (D3)** — 11 langkah bernama (`micro` 10, `label` 11, `body` 12, `bodyLarge` 13, `subtitle` 14, `title` 16, `headline` 20, `display` 24, `displayLarge` 28, `stat` 32, `hero` 36). Semua literal `fontSize` di `lib/` sudah dimigrasikan ke konstanta ini (24 nilai lama dipadatkan, 0 literal tersisa).
- **`AppTheme`** — Material 3 `ColorScheme.fromSeed` dengan `primary` dioverride warna pilihan pengguna; tipografi **Poppins** (dibundel); kartu radius 20 tanpa elevasi; input borderless; SnackBar & dialog mengikuti token. Mendukung **mode terang & gelap** (`getTheme(..., dark: true)`), `themeMode` mengikuti `ThemeController.darkMode`.
- **Mode gelap (D6a)** — palet token gelap: kartu `#1E293B`, teks `#F1F5F9`/`#94A3B8`, border `#334155`, status lebih terang (`#34D399`/`#FB7185`/`#FCD34D`); background halaman = warna latar pilihan pengguna dicampur 88% ke `#0B1120` agar tetap ada sentuhan warna pilihan. Toggle di Pengaturan Tema, persist sebagai `dark_mode_enabled`.
- **`ThemeController`** — persist ke `SharedPreferences` (`custom_primary_color`, `custom_background_color`, `dark_mode_enabled`):
  - **7 preset aksen**: Plum Klasik (default `#381932`), Emerald Green, Electric Indigo, Deep Navy, Royal Purple, Warm Amber, Rose Crimson.
  - **4 preset background**: Krem Hangat (default `#FFF3E6`), Slate Lembut, Putih Bersih, Abu Sejuk.
  - Warna banner header dihitung otomatis dari aksen (varian alpha), sehingga semua layar konsisten dengan tema apa pun.

---

## 8. Mode Kelompok (ZainNoto) — Ringkas

Pembahasan lengkap ada di **[`ZAINNOTO.md`](ZAINNOTO.md)**. Ringkas:

- **Fitur**: grup kas + anggota, rencana iuran (mingguan/bulanan), periode & tagihan otomatis, pembayaran 1-tap/parsial dengan **alokasi FIFO**, kelebihan bayar menjadi **kredit** (terpakai otomatis), bebas iuran, tunggakan, rekap WhatsApp, statistik kontribusi, pengaturan grup.
- **Logic kunci**: status tagihan **selalu turunan** (unpaid/partial/paid/waived, tidak disimpan); periode idempoten; `client_ref` = kunci idempotensi anti double-transaction; edit/hapus pembayaran = realokasi/revert penuh (tanpa void+replace); saldo murni dari transaksi.
- **Data**: tabel `zn_*` (9 tabel) di `finflow.db` yang sama + `ZainNotoProvider` + audit log (dengan UI sejak B6c).
- **UI**: shell 4 tab (Beranda, Iuran checklist/matriks, Transaksi, Statistik) + `GroupManagementSheet`.

---

## 9. Backup & Restore (`backup_service.dart`)

- **Cakupan**: satu file **JSON** (`app: 'takaranoto'`, `version: 1`) berisi **kedua mode sekaligus** — 4 tabel finflow + 9 tabel zainnoto + seluruh `SharedPreferences` (termasuk tema).
- **Ekspor**: tulis `takaranoto-backup-YYYYMMDD-HHmm.json` ke folder temp lalu bagikan lewat share sheet.
- **Impor**: pilih file → validasi marker/versi/struktur → **backup pengaman otomatis** (`pra-restore-*.json`) → dalam transaksi DB: hapus children-first lalu insert parents-first (`ConflictAlgorithm.replace`) → pulihkan prefs. Setelah restore: `refreshAll()` + reload tema.
- **Batasan**: **tidak didukung di web** (layar menampilkan catatan khusus).

---

## 10. Platform & Menjalankan Aplikasi

- Folder platform lengkap: `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`.
- **Web**: sqlite3 wasm + IndexedDB (data **persisten**, berbeda dari yang tertulis di README lama); metadata tampilan: Android label `TakaraNoto`, iOS masih `Finflow Flutter` (belum di-rebrand), bundle `com.finflow.finflow_flutter`.
- **Penyimpanan**: satu file `finflow.db` (Pribadi + `zn_*`) di dokumen aplikasi (native) / IndexedDB (web). File `zainnoto.db` lama (pra-merger) tidak dibaca lagi.
- **Aset**: hanya `assets/images/logo.png`.

```bash
flutter pub get
flutter analyze
flutter test
flutter run                # pilih device; web: flutter run -d chrome
flutter build web
```

---

## 11. Test

| File | Cakupan |
|---|---|
| `test/database_helper_test.dart` | **Regresi A1–A5** (saldo dompet vs isi E-Wallet, belanja E-Wallet masuk statistik/anggaran, setor/tarik tabungan terpisah dari income/expense, hapus goal tidak mengubah laporan, anggaran lintas bulan) + **migrasi v6→v7** (data awet, UNIQUE komposit aktif, flag `is_savings` terisi) + **migrasi v7→v8** (tabel `zn_*` terbentuk, data Pribadi awet) |
| `test/finance_calc_test.dart` | `daysInMonth` (termasuk kabisat & fallback), `monthlyBudgetLimit`, agregasi income/expense/net (mengecualikan transfer & kategori savings), `displayName` transfer (4 kasus), `Category.isSpecial` |
| `test/backup_service_test.dart` | Round-trip backup penuh (finflow + zainnoto + prefs), impor mengganti (bukan menambah), tolak marker salah/versi lebih baru/struktur tidak lengkap |
| `test/notched_card_test.dart` | Geometri notch `buildNotchedCardPath` + render widget |
| `test/widget_test.dart` | `DonutChart` render + aman saat kosong |
| `test/ui_polish_test.dart` | `MaxWidthBody` membatasi lebar di layar lebar & penuh di layar sempit; `PillNavBar` punya label semantik per tab |
| `test/theme_dark_test.dart` | D6a: token & scaffold gelap (terang tetap utuh), persistensi `dark_mode_enabled` di `ThemeController` |
| `test/zainnoto/*` (11 file) | Alokasi FIFO, status iuran, generator periode, constraint skema, operasi pembayaran anti double-transaction, aturan tagihan (`dues_rules_test.dart`: B1 tagihan mulai `joined_at`, B2 ganti frekuensi, B3 anggota terhapus, B4 idempotensi `recordTransaction`, B5 plan tunggal + validasi), fitur B6 (`b6_features_test.dart`: warna/ikon grup, audit log, nomor WhatsApp), group flow, smoke shell |

Total **78 test** — semuanya lulus.

---

## 12. Riwayat Perbaikan & Catatan

**Perbaikan v7 (dari audit logic):**

1. **A1 — Isi Saldo tidak lagi menghilang.** `getCumulativeBalanceUpTo` dulu memfilter `is_transfer = 0`, sehingga top-up keluar tidak mengurangi dompet utama dan "Uang Riil" tampak bertambah. Kini saldo dompet utama menghitung semua baris `main` (transfer & tabungan ikut, karena uang benar-benar berpindah), terpisah dari aturan statistik.
2. **A2 — Belanja E-Wallet masuk laporan.** Semua query statistik/anggaran dulu memfilter `wallet_type='main'`; kini seluruh dompet dihitung dengan pengecualian `is_transfer = 1`, jadi pengeluaran E-Wallet tidak lagi hilang dari donut, anggaran, dan riwayat.
3. **A3 — Donut/legenda tidak mungkin >100%.** Filter `HAVING amount > 0` yang tidak efektif (resolusi alias `amount` ke kolom mentah di SQLite) diganti `HAVING SUM(t.amount) > 0` eksplisit, dan netting setor/tarik dihapus karena tabungan kini dipisah.
4. **A4 — Hapus target tabungan aman.** Klasifikasi tabungan pindah dari `savings_goal_id` ke flag kategori `is_savings` (backfill v7), sehingga `ON DELETE SET NULL` tidak lagi mengubah pemasukan/pengeluaran historis.
5. **A5 — Anggaran lintas bulan berfungsi.** UNIQUE global `budgets.category_id` diganti `UNIQUE(category_id, month_year)`; `BudgetModal._save()` kini menunggu penyimpanan (`await`) sebelum menutup, mencegah simpan ganda/gagal senyap; `_monthlyHint` memakai bulan yang dipilih, bukan `DateTime.now()`.

**Perbaikan ZainNoto (dari audit yang sama):**

1. **B1 — Anggota baru tidak menunggak periode lampau.** `generatePeriods` dan backfill `addMember` hanya membuat tagihan untuk periode yang berakhir pada/setelah `joined_at`; anggota yang gabung Februari tidak lagi punya tagihan Januari.
2. **B2 — Ganti frekuensi tidak menggandakan tagihan.** Mengubah frekuensi/jatuh tempo/tanggal mulai me-soft-delete periode yang belum punya pembayaran sama sekali (beserta charge-nya), lalu jadwal baru digenerate ulang; periode yang sudah ada pembayaran dipertahankan. Batching prefetch membuat proses ini (dan generate biasa) hanya beberapa query, bukan query per periode.
3. **B3 — Rekap konsisten.** `getGroupSummary` dan `getPeriodRows` kini mengecualikan anggota soft-deleted, sama seperti `getOverdueMembers` — tidak ada lagi "Tertib: −2 dari 5".
4. **B4 — `recordTransaction` idempoten** dengan `idempotencyKey` + `client_ref` (sebelumnya hanya `recordDuesPayment`).
5. **B5 — Rencana iuran aman.** Insert plan kedua ditolak (satu plan aktif per grup, cegah dobel tap), `start_date` & `dueDay` divalidasi; error simpan tampil di SnackBar (bukan pesan generik).
6. **Pipeline load:** semua query `_loadGroupData` dijalankan paralel, refresh berulang di-coalesce (satu loop menandai `pending`), matrix periode dimuat paralel. Splash: durasi minimum betul-betul 1,8 detik (sebelumnya delay berurutan total ~2,7 detik).

**Perbaikan UI tahap 1 (dari audit UI):**

1. **D1 — Kontras FAB ZainNoto.** `foregroundColor: Colors.black` (kontras ~1,3:1 untuk aksen gelap seperti Plum) diganti `t.onAccent` di dua FAB (Beranda & Transaksi).
2. **D2 — Dokumentasi dibetulkan.** Klaim "banner hijau" di `ZAINNOTO.md` dihapus; banner memang sengaja mengikuti tema aktif (`t.headerBg`), bukan warna tetap.
3. **D4 — Lebar konten maksimal.** Widget baru `MaxWidthBody` (maks 600 px) membungkus shell Pribadi dan ZainNoto, supaya konten tidak melar selebar layar di tablet/desktop/web.
4. **D5 — Aksesibilitas dasar.** Item `PillNavBar` kini punya `Semantics(button, selected, label)`; tooltip ditambahkan pada kontrol ikon-saja (setelan/ganti grup di banner ZainNoto, palet tema & navigasi bulan di Beranda Pribadi, edit/hapus transaksi, anggota, kategori, target tabungan).

**Perbaikan UI tahap 2 (D3 + D6):**

1. **D3 — Skala tipografi.** 24 nilai `fontSize` literal (240+ pemakaian di 28 file Pribadi & ZainNoto) dipadatkan menjadi 11 konstanta `AppText.*` di `theme/app_tokens.dart`; semua literal dimigrasikan (angka di luar skala dilipat ke langkah terdekat, mis. 15→14, 18→16, 22→20, 40→36). Tidak ada lagi `fontSize` angka mentah di `lib/`.
2. **D6a — Mode gelap.** `AppTheme.getTheme(..., dark: true)` + `AppTokens` varian gelap; toggle "Mode Gelap" di Pengaturan Tema, tersimpan (`dark_mode_enabled`) dan ikut ter-backup karena pref-nya di-dump semua. Background gelap diturunkan dari warna latar pilihan agar tetap personal.
3. **D6b — Font dibundel.** Poppins (400/500/600/700/800/900 + `OFL.txt`) masuk `assets/fonts/` + deklarasi `fonts:` di pubspec, dan `GoogleFonts.config.allowRuntimeFetching = false` di `main()` — tidak ada lagi unduhan font runtime, first-run offline tampil benar.

**Fitur baru dari audit (B6):**

1. **Pemilih warna & ikon grup.** Dialog buat/ubah grup kini punya palette 10 warna, 12 pilihan ikon (indeks 0 = inisial nama), dan preview avatar langsung; `GroupAvatar` menampilkan ikon pilihan di switcher, banner, dan info grup.
2. **Aksi WhatsApp.** Nomor HP anggota bisa ditekan (atau tombol chat) untuk membuka `wa.me`; di sheet "Daftar Penunggak Kas" tiap anggota bisa **"Tagih via WhatsApp"** dengan pesan berisi nominal, jumlah periode, dan tanggal menunggak tertua. Nomor dinormalisasi ke awalan 62 (`utils/whatsapp.dart`, dependensi baru `url_launcher`).
3. **Layar riwayat aktivitas.** Sheet `audit_log_sheet.dart` membaca `getAuditLog` (200 entri terakhir, terbaru dulu) dengan filter per entitas dan dialog detail JSON lama/baru; dibuka dari section "Riwayat Aktivitas" di `GroupManagementSheet`.

**Merger database (Fase 3):**

1. **Satu koneksi, satu file.** `zainnoto_database.dart` dihapus; `DatabaseHelper` naik ke **versi 8** dan membuat 9 tabel ZainNoto berprefix `zn_` (`db/zainnoto_schema.dart`, semua `IF NOT EXISTS`) di `finflow.db`. `ZainNotoRepository` kini memakai koneksi `DatabaseHelper` (bisa di-override lewat parameter `openDatabase` untuk test), dan semua SQL-nya di-rename ke `zn_*`.
2. **Tanpa migrasi data lama.** Data `zainnoto.db` sengaja ditinggalkan (tidak ada data riil); upgrade v7→v8 hanya membuat tabel baru — diuji lewat tes "migrasi v7 -> v8" (tabel `zn_*` terbentuk, data Pribadi awet).
3. **Backup kompatibel.** `BackupService` memakai satu koneksi; format file **tidak berubah** (kunci `finflow` + `zainnoto`, nama tabel lama) — saat restore, tabel `zainnoto` dipetakan ke `zn_*` via `zainnotoTablePrefix`, jadi backup lama tetap valid.

**Quirk & perilaku yang perlu diketahui:**

- Undo hapus transaksi menulis ulang sebagai baris **baru** (id baru; pasangan transfer tidak ikut dipulihkan).
- `FinanceProvider` menelan error ke `debugPrint` — kegagalan DB tampil sebagai UI kosong/statis tanpa pesan.
- Semua transaksi di-load ke memori (tanpa paginasi) dan setiap mutasi memicu reload penuh — sederhana tapi O(semua baris).
- Font Poppins dibundel di `assets/fonts/` (runtime fetching Google Fonts dimatikan) — tidak ada lagi fallback font saat offline.
- Duplikasi helper kecil antar layar (`_monthName`, map `_icon`, parse `_color`); **`tabs/lainnya_tab.dart` (ZainNoto) adalah kode mati**; beberapa util (`getCategorySpendingList`, `isPresetSelected`, sebagian fungsi `finance_calc`) hanya dipakai test.
- Penamaan hybrid: package `finflow_flutter` vs produk `TakaraNoto`; label iOS belum diganti.
- Mode aplikasi sengaja tidak dipersist (selalu mulai dari Pribadi).
