import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../services/backup_service.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_controller.dart';

/// Export / import the whole app data (personal + group + theme settings)
/// as a single JSON file.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _service = BackupService();
  bool _busy = false;
  String _busyLabel = '';

  Future<void> _exportBackup() async {
    setState(() {
      _busy = true;
      _busyLabel = 'Menyiapkan file backup...';
    });
    try {
      await _service.shareBackup();
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is BackupException ? error.message : 'Gagal membuat backup: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    final finance = context.read<FinanceProvider>();
    final theme = context.read<ThemeController>();

    final picked = await FilePicker.pickFile(
      dialogTitle: 'Pilih file backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _busyLabel = 'Memeriksa file backup...';
    });
    try {
      final decoded = jsonDecode(await File(path).readAsString());
      if (decoded is! Map) {
        throw BackupException('Isi file bukan format backup yang dikenal.');
      }
      final data = Map<String, Object?>.from(decoded);
      final validation = _service.validate(data);
      if (!validation.isValid) {
        throw BackupException(validation.error!);
      }

      setState(() => _busy = false);
      final confirmed = await _confirmRestore(validation);
      if (confirmed != true) return;

      setState(() {
        _busy = true;
        _busyLabel = 'Memulihkan data...';
      });
      final result = await _service.restoreFromJson(data);

      await finance.refreshAll();
      await theme.load();

      if (!mounted) return;
      await _showRestoreResult(result);
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is BackupException
              ? error.message
              : 'Gagal memulihkan data: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore(BackupValidation validation) {
    final t = context.tokens;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Timpa semua data?'),
        content: Text(
          'File backup ini berisi ${validation.totalRows} baris data'
          '${validation.exportedAt != null ? ' (dibuat ${_formatDate(validation.exportedAt!)})' : ''}.\n\n'
          'Seluruh data saat ini (Pribadi + Kelompok) akan diganti dengan isi '
          'file backup. Salinan data lama otomatis dibuat sebelum impor.',
          style: TextStyle(fontSize: 13, color: t.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, Pulihkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRestoreResult(RestoreResult result) {
    final t = context.tokens;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pemulihan berhasil'),
        content: Text(
          'Data Pribadi: ${result.finflowRows} baris\n'
          'Data Kelompok: ${result.zainnotoRows} baris\n\n'
          'Salinan data lama disimpan di:\n${result.safetyBackupPath}',
          style: TextStyle(fontSize: 13, color: t.textMuted, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  void _showMessage(String message, {bool isError = false}) {
    final t = context.tokens;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? t.expense : t.headerBg,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.pageBg,
      body: Stack(
        children: [
          Column(
            children: [
              const _Header(),
              Expanded(
                child: kIsWeb
                    ? _WebNotice()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        children: [
                          _ActionCard(
                            icon: Icons.ios_share_rounded,
                            title: 'Ekspor Backup',
                            description:
                                'Simpan salinan seluruh data aplikasi ke satu '
                                'file JSON, lalu bagikan ke penyimpanan atau '
                                'chat pilihanmu.',
                            buttonLabel: 'Bagikan Backup',
                            onPressed: _busy ? null : _exportBackup,
                          ),
                          const SizedBox(height: 16),
                          _ActionCard(
                            icon: Icons.settings_backup_restore_rounded,
                            title: 'Impor Backup',
                            description:
                                'Pulihkan data dari file backup. Seluruh data '
                                'saat ini akan diganti — salinan otomatis '
                                'dibuat dulu sebagai pengaman.',
                            buttonLabel: 'Pilih File Backup',
                            onPressed: _busy ? null : _importBackup,
                            destructive: true,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: t.softSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: t.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: t.accent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Backup mencakup: kategori & transaksi, '
                                    'anggaran, tabungan, seluruh data kas '
                                    'kelompok, dan pengaturan tema.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: t.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          if (_busy) _BusyOverlay(label: _busyLabel),
        ],
      ),
    );
  }
}

// ─── Header banner ────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.headerBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.headerSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.headerBorder, width: 1),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: t.headerFg,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Backup & Restore',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: t.headerFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Action card ──────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = destructive ? t.expense : t.accent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: t.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: destructive
                  ? ElevatedButton.styleFrom(backgroundColor: t.expense)
                  : null,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Web notice ───────────────────────────────────────────────────────────────
class _WebNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Backup & Restore hanya tersedia di Android, iOS, dan desktop.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: t.textMuted),
        ),
      ),
    );
  }
}

// ─── Busy overlay ─────────────────────────────────────────────────────────────
class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: t.accent),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
