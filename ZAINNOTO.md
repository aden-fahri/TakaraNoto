# ZainNoto — Fitur & Logic (Mode Kas Kelompok)

Dokumen ini merangkum seluruh fitur dan logic **ZainNoto**, mode pengelolaan **kas kelompok** di dalam aplikasi TakaraNoto. Ditulis berdasarkan kode aktual di `lib/zainnoto/` dan `lib/screens/zainnoto/`.

---

## 1. Ringkasan & Konsep

Aplikasi memiliki **dua mode** yang dikelola `AppModeController` (`lib/providers/app_mode_controller.dart`):

| Mode | Label | Shell | Penjelajah data |
|---|---|---|---|
| `AppMode.personal` | Pribadi | `MainNavigationScreen` (TakaraNoto) | Keuangan pribadi (`finflow.db`) |
| `AppMode.group` | Kelompok | `ZainNotoShellScreen` (ZainNoto) | Kas kelompok (tabel `zn_*` di `finflow.db`) |

- Pemilihan mode dilakukan lewat tombol `ModeSwitchButton` (ringkas, menampilkan **mode tujuan**: `ZainNoto →` saat di TakaraNoto, `TakaraNoto →` saat di ZainNoto).
- `AppModeGate` di `lib/main.dart` me-render shell sesuai mode aktif.
- Mode **tidak dipersist** — aplikasi selalu terbuka di mode Pribadi.
- Sejak **merger Fase 3**, ZainNoto memakai **database yang sama** dengan mode Pribadi (`finflow.db`, skema v8) dengan semua tabelnya diberi prefix `zn_`, dan tetap memakai **provider terpisah** (`ZainNotoProvider`) sehingga state UI tidak tercampur. Satu koneksi DB dibagi lewat `DatabaseHelper`; format file backup tidak berubah (kunci `zainnoto` tetap ada) sehingga backup lama tetap bisa direstore.
- Seluruh teks UI berbahasa Indonesia; semua uang disimpan sebagai **integer rupiah**; tanggal `YYYY-MM-DD`; timestamp ISO-8601 UTC.

---

## 2. Peta File

### Library inti — `lib/zainnoto/`

| File | Peran |
|---|---|
| `db/zainnoto_schema.dart` | Schema tabel ZainNoto `zn_*` (9 tabel + index, `IF NOT EXISTS`) yang dibuat di `finflow.db` oleh `DatabaseHelper` (v8); `PRAGMA foreign_keys = ON` tetap aktif |
| `logic/allocation.dart` | Alokator FIFO murni (`DebtItem`, `AllocationDraft`, `AllocationResult`, `allocateFifo`) |
| `logic/dues_status.dart` | Status turunan `ChargeStatus {unpaid, partial, paid, waived}` + `deriveChargeStatus` — status **tidak pernah disimpan** |
| `logic/period_generator.dart` | Perencana periode murni & idempoten (`planPeriods`) untuk mingguan/bulanan |
| `models/entities.dart` | Enum + entitas: `Group`, `Member`, `DuesPlan`, `Period`, `Charge`, `GroupTransaction`, `Allocation`, `MemberCredit`, `AuditEntry` |
| `models/derived.dart` | View-model: `PeriodMemberRow`, `GroupSummary`, `MemberOverdueSummary`, `AllocationDetail` |
| `providers/zainnoto_provider.dart` | `ZainNotoProvider extends ChangeNotifier` — state UI, alur load/refresh, wrapper CRUD, state matriks |
| `repositories/zainnoto_repository.dart` | Semua baca/tulis DB, operasi multi-langkah dalam transaksi, mirroring audit, agregat ringkasan |
| `utils/dates.dart` | `monthNamesId`, `dateToStr`, `dateFromStr`, `dateOnly`, `nowIso` |
| `utils/format.dart` | `formatRupiah`, `periodShortLabel`, `formatTanggalSingkat`, `formatTanggal`, `formatWaktuLengkap` (locale `id` dengan fallback aman) |
| `utils/whatsapp.dart` | `whatsappDigits`/`whatsappUri`/`openWhatsApp` — normalisasi nomor Indonesia ke `wa.me` (awalan 62) |

### UI — `lib/screens/zainnoto/`

| File | Peran |
|---|---|
| `zainnoto_shell_screen.dart` | Shell 4 tab (Beranda, Iuran, Transaksi, Statistik) + `PillNavBar`; load grup pasca-frame |
| `tabs/beranda_tab.dart` | Dashboard: banner, kartu dompet, kartu keaktifan & tunggakan, quick actions, FAB belanja, sheet daftar penunggak |
| `tabs/iuran_tab.dart` | Tab iuran: navigator periode, mode Checklist/Matriks, 1-tap "Lunas" dengan undo |
| `tabs/transaksi_tab.dart` | Buku transaksi dengan filter tipe, dikelompokkan per tanggal |
| `tabs/statistik_tab.dart` | Ringkasan keuangan, tingkat ketertiban, donut pengeluaran, leaderboard kontribusi anggota |
| `tabs/lainnya_tab.dart` | **Kode legacy (orphan)** — tidak dipakai shell; fiturnya digantikan `GroupManagementSheet` |
| `widgets/dues_style.dart` | Warna & label Indonesia untuk status iuran |
| `widgets/group_avatar.dart` | Avatar lingkaran grup: ikon pilihan (`groupIconOptions`) atau inisial nama, warna dari `colorHex` (fallback `0xFF059669`) |
| `widgets/audit_log_sheet.dart` | Sheet read-only riwayat perubahan (`getAuditLog`): filter entitas, detail old/new JSON |
| `widgets/member_avatar.dart` | Avatar anggota diwarnai status (bg 14% alpha) |
| `widgets/iuran_matrix.dart` | Matriks anggota × 12 periode terakhir + legenda |
| `widgets/payment_detail_sheet.dart` | Detail pembayaran: riwayat, bayar sebagian, edit/hapus, bebas iuran |
| `widgets/transaction_form_sheet.dart` | Form tambah/edit transaksi kas |
| `widgets/group_management_sheet.dart` | Sheet pengaturan: info grup, anggota, rencana iuran & periode, rekap WhatsApp, shortcut backup |
| `widgets/group_sheets.dart` | `showGroupSwitcher`, `showCreateGroupDialog`/`showEditGroupDialog` (nama, deskripsi, warna & ikon grup), style input grup |

---

## 3. Model Data & Skema SQLite

### 3.1 Enum

- `DuesFrequency`: `weekly` | `monthly` (fallback → `weekly`)
- `MemberStatus`: `active` | `inactive` (fallback → `active`)
- `TxType`: `dues` (iuran) | `otherIncome` (`other_income`) | `expense`; `isIncome => this != expense`

### 3.2 Entitas

| Entitas | Field penting | Catatan |
|---|---|---|
| `Group` | name, description?, iconIndex, colorHex, deletedAt? | Soft delete (`isDeleted`) |
| `Member` | groupId, name, phoneNumber?, joinedAt, status, deletedAt? | `isActive`; anggota nonaktif tidak ditagih periode baru |
| `DuesPlan` | amount, frequency, dueDay, startDate | UI efektif memakai plan pertama |
| `Period` | duesPlanId, label, startDate, endDate, dueDate, `amountSnapshot` | Snapshot tarif saat pembuatan; unik per `(dues_plan_id, start_date)` |
| `Charge` | memberId, periodId, amountDue, waived | **Tidak ada kolom status** — selalu diturunkan; unik per `(period_id, member_id)` |
| `GroupTransaction` | groupId, memberId?, type, amount, category?, note?, date, isDeleted, `clientRef?` | `clientRef` = kunci idempotensi |
| `Allocation` | transactionId, chargeId, amountAllocated | Jembatan uang → tagihan; unik per `(transaction_id, charge_id)` |
| `MemberCredit` | memberId, sourceTransactionId, amountRemaining | Sisa kelebihan bayar (harus > 0) |
| `AuditEntry` | entity, entityId, action, oldJson?, newJson?, createdAt | Log append-only |

Semua ID = UUID v4 (`repository.dart`), kecuali `zn_audit_log` memakai auto-increment integer.

### 3.3 Tabel & Constraint

- Tabel (semua berprefix `zn_` di database bersama): `zn_groups`, `zn_members`, `zn_dues_plans`, `zn_periods`, `zn_charges`, `zn_transactions`, `zn_allocations`, `zn_member_credits`, `zn_audit_log`.
- FK: semua anak → induk `ON DELETE CASCADE`; `zn_transactions.member_id → zn_members SET NULL`.
- **Unique index penting**:
  - `uq_zn_period (dues_plan_id, start_date)` — periode tidak ganda
  - `uq_zn_charge (period_id, member_id)` — tagihan tidak ganda
  - `uq_zn_tx_client_ref (client_ref) WHERE client_ref IS NOT NULL` — anti double-transaction di level DB
  - `uq_zn_alloc (transaction_id, charge_id)` — alokasi tidak ganda
- **Check constraint**: `amount >= 0` (plans/charges), `amount > 0` (transactions/allocations/credits), status anggota & frekuensi & tipe divalidasi enum.
- **Soft delete**: `deleted_at` pada groups/members/dues_plans/periods/charges; `is_deleted` + `deleted_at` pada transactions. Tabel allocations/credits/audit_log dihapus keras.
- Index tambahan untuk lookup umum (per grup, per anggota, per tanggal, per entitas audit).

---

## 4. Logic Inti (Algoritma)

### 4.1 Pembuatan periode (`logic/period_generator.dart`)

`planPeriods({frequency, dueDay, startDate, upTo, amount})` — murni & idempoten:

- **Mingguan**: blok 7 hari mulai dari `startDate`. `dueDate = blockStart + (dueDay.clamp(1,7) - 1)`. Label `"Minggu N <Bulan> <tahun>"` (N dihitung dari tanggal, blok berganti tiap tanggal 1/8/15/22/29).
- **Bulanan**: bulan kalender mulai bulan `startDate`. `dueDate = min(dueDay.clamp(1,28), akhirBulan)` — jadi `dueDay 30` di Februari jatuh ke tanggal 28/29. Label `"<Bulan> <tahun>"`.
- `amountSnapshot = amount` untuk setiap draft; idempotensi dicapai karena pemanggil melewati `(dues_plan_id, start_date)` yang sudah ada.
- Mengembalikan `[]` bila `upTo` sebelum `startDate`.

### 4.2 Generate tagihan & idempotensi (`repository.generatePeriods`)

Satu transaksi DB (prefetch batch, bukan query per periode):

1. Ambil semua plan aktif grup + semua anggota **aktif** (beserta `joined_at`) dalam 2 query.
2. Prefetch semua periode plan & charge-nya (2 query) untuk lookup `(dues_plan_id, start_date)` dan `(period_id, member_id)`.
3. Untuk tiap plan → `planPeriods(...)`:
   - Periode **aktif** yang sudah ada → dilewati.
   - Periode yang **soft-deleted** dengan `(dues_plan_id, start_date)` sama (sisa perubahan jadwal) → **diaktifkan ulang** dengan label/tanggal/snapshot baru.
   - Selain itu → insert periode baru (UUID + snapshot amount).
4. Untuk tiap anggota: **hanya ditagih bila `end_date >= joined_at`** (B1 — periode yang berakhir sebelum anggota bergabung tidak pernah muncul). Charge aktif dilewati; charge soft-deleted diaktifkan ulang (`amount_due` diperbarui, `waived` dipertahankan); sisanya insert baru.
5. Bila ada ≥ 1 periode baru/revive → jalankan `_consumeCredits` untuk semua anggota non-deleted (termasuk nonaktif) — hook pemakaian kredit otomatis.
6. Mengembalikan jumlah periode baru + revive.

Dipanggil provider pada **setiap load/refresh grup** (`_loadGroupData`), sehingga periode sampai hari ini selalu ada dan pemanggilan berulang aman (3 lalu 0).

### 4.3 Backfill anggota baru (`repository.addMember`)

Anggota baru langsung ditagih untuk periode non-deleted yang **berakhir pada/setelah `joined_at`** (B1), memakai `amount_snapshot` masing-masing periode (tarif historis), bukan tarif plan saat ini. Periode yang berakhir sebelum anggota bergabung tidak dibuatkan tagihan.

### 4.4 Alokasi pembayaran FIFO (`logic/allocation.dart` + `repository._allocateForMember`)

- `amount <= 0` → tanpa alokasi.
- Tagihan diurutkan `dueDate ASC`, seri dipecah berdasarkan id charge (ascending) — **tunggu paling tua dibayar lebih dulu**.
- Setiap tagihan diambil `min(sisa, sisaTagihan)`; sisanya menjadi `leftover`.
- Query `_unpaidCharges`: charge non-deleted, `waived = 0`, periode non-deleted, grup sama; `paid` = SUM alokasi yang **transaksinya tidak dihapus**; hanya sisa > 0 yang menjadi kandidat.
- `leftover > 0` **tidak pernah dibuang** — disimpan sebagai `member_credits` dengan `source_transaction_id` transaksi tersebut.

### 4.5 Kredit / kelebihan bayar (`repository._consumeCredits`)

- Kredit diurutkan `created_at ASC`, tagihan menunggak diurutkan tanggal jatuh tempo.
- Kredit dikonsumsi FIFO ke tagihan tertua; setiap pemakaian menulis `allocation` dengan `transaction_id = source_transaction_id` kredit.
- Kredit habis → row dihapus; sisa → `amount_remaining` diperbarui.
- Dipicu **otomatis** setiap ada periode baru dibuat (langkah 4.2) — jadi bayar di muka otomatis lunas begitu periode baru muncul.
- Karena alokasi kredit memakai id transaksi sumber, mengedit/menghapus transaksi sumber otomatis me-revert pemakaian kredit tersebut.

### 4.6 Anti double-transaction (`client_ref`)

- `recordDuesPayment` **dan** `recordTransaction` menerima `idempotencyKey` (UI: UUID baru per aksi). Bila key sudah ada → mengembalikan id transaksi **yang sudah ada** tanpa membuat row kedua.
- Level DB: partial unique index `uq_tx_client_ref` sebagai pengaman cadangan.
- Semua penulisan multi-langkah dibungkus `db.transaction`.

### 4.7 Edit pembayaran (`repository.editTransaction`)

Satu transaksi DB (edit-in-place, bukan void+replace):

1. Validasi: transaksi ada & belum dihapus; amount baru > 0.
2. Update row (amount/date/note/category/member_id).
3. Khusus `dues`: **hapus semua** alokasi & kredit bersumber transaksi ini, lalu alokasikan ulang penuh `newAmount` secara FIFO (untuk anggota baru bila ditukar).
   - Efek: edit 10.000 → 15.000 hanya menambah 5.000; ganti anggota mengembalikan tagihan anggota lama menjadi menunggak.
4. Tulis audit `update` (old + new JSON).

### 4.8 Hapus pembayaran (`repository.deleteTransaction`)

Soft delete (`is_deleted = 1`), hapus alokasi per transaksi & kredit yang bersumber dari transaksi itu, tulis audit `delete`. Semua status turunan langsung kembali (karena query mengabaikan alokasi dari transaksi terhapus). UI menyediakan undo lewat SnackBar "Batal".

### 4.9 Status tagihan (turunan — tidak disimpan)

`deriveChargeStatus`: `waived` menang lebih dulu → `paid` bila `paid >= amountDue` → `partial` bila `paid > 0` → selain itu `unpaid`.

- `PeriodMemberRow.remaining = max(0, amountDue - paid)`.
- `isOverdue(asOf) = !waived && paid < amountDue && dueDate < asOf` (strict).

### 4.10 Ringkasan & tunggakan (`repository.getGroupSummary` dkk.)

- **Saldo** = SUM seluruh transaksi hidup (`expense` negatif, lainnya positif). **Alokasi & kredit tidak pernah mengubah saldo** (kelebihan bayar dihitung sekali saat transaksi dicatat).
- **Tunggakan**: per charge hidup non-waived dengan `due_date < hari ini` dan `paid < amount_due`; `overdueTotal` + `overdueMemberCount` per anggota (**anggota soft-deleted dikecualikan** via JOIN `members.deleted_at IS NULL`, konsisten dengan `getOverdueMembers`). `getOverdueMembers` menambah `unpaid_count`, total, dan `oldest_due_date`, diurutkan total terbesar.
- **Periode berjalan** = periode terakhir dengan `start_date <= hari ini`. `currentPeriodPaidCount` menghitung baris berstatus `paid` (waived dikecualikan); `activityPct = round(paid/total*100)`.
- `getPeriodRows` (dipakai checklist & matriks): join charges→members→periods, LEFT JOIN allocations & transaksi hidup; `paid` hanya menjumlah alokasi dari transaksi hidup; **anggota soft-deleted tidak ditampilkan**; urut nama anggota (`COLLATE NOCASE`).

### 4.11 Audit log

`_audit` menulis `entity` (group/member/dues_plan/charge/transaction), `entity_id`, `action` (insert/update/delete), `old_json`, `new_json`, timestamp — **di dalam transaksi DB yang sama** dengan mutasinya. Dibaca via `getAuditLog(...)`; ditampilkan lewat sheet `audit_log_sheet.dart` (tombol "Lihat Riwayat Perubahan" di section Riwayat Aktivitas `GroupManagementSheet`), lengkap dengan filter entitas dan detail JSON lama/baru.

### 4.12 Rencana iuran: validasi, plan tunggal & perubahan jadwal (`repository.upsertDuesPlan`)

- **Validasi**: `amount >= 0`; `dueDay` 1–7 (mingguan) / 1–28 (bulanan); `start_date` harus parseable `YYYY-MM-DD`.
- **Satu plan aktif per grup**: insert tanpa `id` ditolak (`StateError`) bila sudah ada plan aktif — UI selalu mengedit plan `first`, jadi insert kedua berarti dobel tap/bug.
- **Perubahan jadwal** (frekuensi, `due_day`, atau `start_date` berubah): `_replaceUnpaidPeriods` men-soft-delete **semua periode aktif plan yang tidak punya alokasi sama sekali** beserta charge-nya (audit `periods` action `delete`, reason `schedule_change`). Periode yang sudah ada pembayaran **dipertahankan apa adanya**. Periode belum lunas akan dibangun ulang sesuai jadwal baru oleh `generatePeriods` berikutnya (revive, §4.2). Perubahan `amount` saja tidak menyentuh periode (nominal periode adalah snapshot).

---

## 5. API `ZainNotoProvider`

### State & getter

`groups`, `selectedGroup`, `isLoading`, `isRefreshing`, `error`, `summary`, `currentPeriod`, `periodRows`, `periods`, `members` (aktif), `allMembers` (termasuk nonaktif), `transactions`, `duesPlans`, `overdueMembers`, `selectedPeriod`, `matrixByPeriod`, `isLoadingMatrix`, `matrixNeedsReload`.

Derived: `totalIncome`, `totalExpense`, `memberById(id)`.

### Method

| Method | Fungsi |
|---|---|
| `loadGroups()` | Muat daftar grup; auto-pilih grup pertama & load datanya |
| `selectGroup(group)` / `refreshGroup()` | Pindah grup / muat ulang data grup terpilih |
| `createGroup({name, description, iconIndex, colorHex})` | Buat grup (warna & ikon pilihan), reload daftar, pilih & load grup baru |
| `updateGroup({id, name, description, iconIndex?, colorHex?})` | Ubah info, warna, dan/atau ikon grup |
| `deleteGroup(id)` | Soft delete grup, bersihkan pilihan |
| `markPaid({memberId, amount, date?})` | Catat iuran dengan idempotency key UUID; lalu refresh |
| `editTransaction({id, amount?, date?, note?, category?, memberId?})` | Edit transaksi (re-alokasi otomatis untuk dues) |
| `deleteTransaction(id)` | Soft delete transaksi + revert alokasi/kredit |
| `setChargeWaived(chargeId, {waived})` | Tandai/batalkan "Bebas Iuran" |
| `addTransaction({type, amount, category?, note?, date?})` | Tambah transaksi kas masuk/keluar (dues tidak via sini); idempotency key UUID per aksi |
| `addMember({name, phoneNumber?, joinedAt?})` | Tambah anggota + backfill tagihan sejak periode bergabung |
| `updateMember({id, name?, phoneNumber?, status?})` | Ubah data/status anggota |
| `removeMember(id)` | Soft delete anggota (riwayat tetap) |
| `saveDuesPlan({id?, amount, frequency, dueDay, startDate})` | Upsert rencana iuran (validasi penuh; perubahan jadwal me-reset periode belum lunas) |
| `generatePeriodsNow()` | Sinkronkan periode sampai hari ini; mengembalikan jumlah periode baru/revive |
| `selectPeriod(period)` / `loadMatrix({maxPeriods: 12})` | Load baris checklist periode terpilih / matriks 12 periode terakhir |
| `allocationDetailsFor(transactionId)` | Rincian alokasi per transaksi (untuk detail pembayaran) |

Pola error: catch → `_error = 'Gagal …: $error'`, `notifyListeners()`, kembalikan `false`/`null`/`0`; UI menampilkan kartu error/SnackBar dengan tombol coba lagi.

---

## 6. Alur UI

### Shell (`zainnoto_shell_screen.dart`)

`IndexedStack` 4 tab + `PillNavBar`: Beranda (home), Iuran (checklist), Transaksi (receipt), Statistik (analytics). `loadGroups()` dijalankan pasca-frame; antar-tab lewat `_goToTab`.

### Beranda

- Banner mengikuti tema aktif (`t.headerBg` — warna aksen pilihan pengguna, bukan selalu hijau) dengan lingkaran dekoratif + tombol `ModeSwitchButton` ("TakaraNoto →"), tombol setelan grup (tooltip "Kelola grup & anggota"), dan tombol ganti grup (tooltip "Ganti grup").
- `_ModernGroupWalletCard` (kartu notch): label "DOMPET KAS KELOMPOK", chip periode berjalan, **Saldo Kas Bersama** (merah bila negatif), pill "Masuk"/"Keluar".
- Bento: **Keaktifan** (lunas/total periode ini + progress) dan **Tunggakan** (nominal + jumlah orang). Tunggakan > 0 → sheet "Daftar Penunggak Kas" (tombol **"Tagih via WhatsApp"** per anggota yang punya nomor — pesan berisi nominal, jumlah periode, dan tanggal tertua).
- Quick actions: Catat Iuran (→ tab Iuran), Transaksi (→ tab Transaksi), Statistik (→ tab Statistik), Kelola (→ sheet pengaturan).
- FAB "Catat Belanja / Kas Keluar" → form transaksi (default `expense`).
- Empty state tanpa grup: CTA "Buat Grup Kas Sekarang" + kartu error & tombol coba lagi bila gagal load.

### Iuran

- Banner: judul, chip `lunas/total`, navigator periode (‹ label ›, jatuh tempo), toggle **Checklist / Matriks**.
- **Checklist**: per anggota — avatar berwarna status, nama, chip status, sisa (bila sebagian), tanggal jatuh tempo/lewat; tombol "Lunas" (nominal sisa) → `markPaid` + SnackBar undo "Batal". Tap baris → `PaymentDetailSheet`.
- **Matriks** (`iuran_matrix.dart`): baris anggota × 12 periode terakhir; ikon sel = lunas ✓ / dicicil ⏳ / nunggak ⚠ / belum jatuh tempo 🗓 / bebas ⛔; lazy-load saat perlu.

### PaymentDetailSheet

- Ringkasan Tagihan/Terbayar/Sisa, riwayat pembayaran (dengan rincian alokasi per periode), aksi: **Tandai Lunas**, **Bayar Sebagian** (form, hint "Pembayaran otomatis mengisi tagihan tertua lebih dulu"), **Tandai/Batalkan Bebas Iuran**, edit (amount/tanggal/catatan; alokasi dihitung ulang), dan hapus + konfirmasi.

### Transaksi

- Banner + statistik masuk/keluar; filter: Semua / Iuran / Masuk / Keluar.
- Daftar dikelompokkan "Hari Ini", "Kemarin", atau tanggal penuh; tap → edit via `TransactionFormSheet`.
- Form: tipe Keluar (default)/Masuk; edit dues menampilkan chip read-only "Iuran · <nama>"; input rupiah berformat titik; date picker; catatan; hapus dengan konfirmasi.

### Statistik

- Kartu keuangan: Saldo Bersih, Total Pemasukan, Total Pengeluaran.
- Ketertiban: `((anggota - menunggak) / anggota * 100)`, badge "X% Tertib".
- Donut pengeluaran per kategori + legenda persen/nominal.
- Leaderboard kontribusi: total iuran per anggota (top 8, peringkat #n).

### GroupManagementSheet (Pengaturan & Anggota)

1. **Info Grup** — ubah (nama, deskripsi, warna & ikon), ganti, tambah, hapus grup (soft delete; data kas tetap tersimpan).
2. **Anggota** — tambah/ubah/hapus; switch "Nonaktif" berarti tidak ikut ditagih periode baru; nomor HP bisa ditekan untuk **chat WhatsApp** (`url_launcher`, `wa.me`, normalisasi awalan 62 via `utils/whatsapp.dart`).
3. **Rencana Iuran & Jadwal** — nominal, frekuensi (default bulanan), hari jatuh tempo (mingguan: Senin–Minggu; bulanan: tanggal 1–28), tanggal mulai; tombol **"Buat/Sinkron Periode Sekarang"**.
4. **Rekap WhatsApp** — ringkasan periode berjalan (saldo, tunggakan, daftar lunas/belum) dibagikan via `share_plus`.
5. **Riwayat Aktivitas** — buka sheet `audit_log_sheet.dart` (filter per entitas, detail JSON lama/baru).
6. **Data & Cadangan** — pintasan ke layar backup/restore.

---

## 7. Integrasi

- **Mode gate**: `AppModeGate` (`lib/main.dart`) memilih `ZainNotoShellScreen` atau `MainNavigationScreen`; `ZainNotoProvider` di-provide di root.
- **Backup/Restore** (`lib/services/backup_service.dart`): export menyertakan key `'zainnoto'` (9 tabel, urutan parents-first, **nama tabel tetap tanpa prefix** agar kompatibel dengan backup lama); restore memakai satu koneksi `DatabaseHelper` dan memetakan nama lama ke tabel `zn_*` lewat `zainnotoTablePrefix`, menghapus children-first lalu insert dengan `ConflictAlgorithm.replace`, didahului backup pengaman. Validasi memastikan kedua map ada. Tidak didukung di web.
- **Web**: `main.dart` men-set `databaseFactoryFfiWeb` (sqlite3 wasm + IndexedDB) agar `finflow.db` (termasuk tabel `zn_*`) jalan & persisten di browser.
- **Tema**: seluruh layar memakai token `context.tokens` (`accent/onAccent`, `income`, `expense`, `warning`, `header*`, `card`, `border`, dst.) sehingga mengikuti theme yang dipilih di TakaraNoto.

---

## 8. Test

| File (`test/zainnoto/`) | Cakupan |
|---|---|
| `helpers.dart` | `openTestDatabase()` (sqfliteFfi + `DatabaseHelper` in-memory, tabel `zn_*` ikut dibuat) & seed grup "Kas Futsal", anggota Alice/Bob, plan mingguan Rp20.000 |
| `allocation_test.dart` | FIFO tertua dulu, leftover, lewati tagihan lunas, amount ≤ 0 |
| `dues_status_test.dart` | Derivasi status: 0 → unpaid, sebagian → partial, ≥ due → paid, waived prioritas |
| `group_flow_test.dart` | `loadGroups` pada DB kosong, `createGroup` sukses & auto-select |
| `period_generator_test.dart` | Blok mingguan, dueDay, label; bulan kalender, clamp Februari, snapshot amount |
| `dues_rules_test.dart` | B1 tagihan mulai `joined_at` (generate & backfill), B2 ganti frekuensi (periode lunas tetap, belum lunas diganti), B3 anggota terhapus keluar dari rekap/checklist, B4 idempotensi `recordTransaction`, B5 plan tunggal + validasi input |
| `b6_features_test.dart` | B6: `iconIndex`/`colorHex` grup tersimpan & ter-update, audit `group` insert/update + filter entitas, normalisasi nomor WhatsApp & `whatsappUri` |
| `schema_constraints_test.dart` | Unique charge/allocation, FK, CHECK amount, idempotency `client_ref` |
| `payment_ops_test.dart` | Anti double-transaction (edit/hapus/ganti anggota/dobel tap), generator idempoten, kredit otomatis, waived, audit, ringkasan |
| `shell_smoke_test.dart` | Widget: shell tanpa grup & dengan data, semua tab aman dibuild |

Di luar folder ini: `test/backup_service_test.dart` menguji round-trip backup termasuk 9 tabel ZainNoto.

---

## 9. Catatan Penting

- **Status selalu turunan** — `charges` tidak menyimpan status; kebenaran data dijamin oleh alokasi dari transaksi hidup.
- **Tagihan dimulai dari periode bergabung** — anggota tidak pernah menunggak periode sebelum `joined_at`; periode yang berakhir sebelum tanggal bergabung tidak dibuatkan charge.
- **Ganti jadwal bukan angka** — mengubah frekuensi/jatuh tempo/tanggal mulai me-reset periode yang belum dibayar sesuai jadwal baru; periode yang sudah ada pembayaran dipertahankan (jadwal lama & baru bisa sesaat tumpang tindih untuk periode tersebut).
- **Saldo ≠ Σ sisa tagihan** — saldo murni dari transaksi; kredit/kelebihan bayar tersimpan sebagai `member_credits`, bukan saldo kedua.
- **Anggota nonaktif** berhenti menerima tagihan baru, tetapi tagihan lama & kreditnya tetap dihitung (kredit tetap dikonsumsi otomatis).
- **Edit-in-place**: mengedit pembayaran menghapus & mengalokasikan ulang seluruh nominalnya — tidak ada void+replace, sehingga konsisten dan idempoten.
- **Audit log lengkap** — ditampilkan lewat sheet Riwayat Perubahan (filter entitas + detail JSON lama/baru) dari `GroupManagementSheet`.
- **`tabs/lainnya_tab.dart` adalah kode mati** (1181 baris) — tidak diimport siapa pun; fungsinya sudah digantikan `GroupManagementSheet`. Kandidat penghapusan.
- **Warna/ikon grup** disimpan di skema (`colorHex`, `iconIndex`) dan dipilih dari dialog buat/ubah grup (preview avatar langsung, `groupIconOptions` indeks 0 = inisial nama).
- **Semua operasi multi-langkah dibungkus transaksi DB**; pengaman berlapis: idempotency key + partial unique index, FIFO tie-break by id, leftover never dropped.
- **Database dibagi dengan mode Pribadi (merger Fase 3)** — semua tabel ZainNoto berprefix `zn_` di `finflow.db` (skema v8, dibuat `createZainNotoSchema`); `zainnoto.db` lama tidak dibaca lagi dan backup lama tetap bisa direstore.
