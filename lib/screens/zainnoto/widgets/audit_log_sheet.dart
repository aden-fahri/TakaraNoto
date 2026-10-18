import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/format.dart';

/// Riwayat perubahan data (audit log) dalam bottom sheet read-only.
Future<void> showAuditLogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AuditLogSheet(),
  );
}

const List<({String? value, String label})> _entityFilters = [
  (value: null, label: 'Semua'),
  (value: 'transaction', label: 'Transaksi'),
  (value: 'charge', label: 'Tagihan'),
  (value: 'periods', label: 'Periode'),
  (value: 'dues_plan', label: 'Rencana'),
  (value: 'member', label: 'Anggota'),
  (value: 'group', label: 'Grup'),
];

String _entityLabel(String entity) {
  switch (entity) {
    case 'transaction':
      return 'Transaksi';
    case 'charge':
      return 'Tagihan';
    case 'periods':
      return 'Periode';
    case 'dues_plan':
      return 'Rencana iuran';
    case 'member':
      return 'Anggota';
    case 'group':
      return 'Grup';
    default:
      return entity;
  }
}

String _actionLabel(String action) {
  switch (action) {
    case 'insert':
      return 'Dibuat';
    case 'update':
      return 'Diubah';
    case 'delete':
      return 'Dihapus';
    default:
      return action;
  }
}

IconData _actionIcon(String action) {
  switch (action) {
    case 'insert':
      return Icons.add_rounded;
    case 'update':
      return Icons.edit_outlined;
    case 'delete':
      return Icons.delete_outline_rounded;
    default:
      return Icons.history_rounded;
  }
}

String _prettyJson(String raw) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
  } catch (_) {
    return raw;
  }
}

class _AuditLogSheet extends StatefulWidget {
  const _AuditLogSheet();

  @override
  State<_AuditLogSheet> createState() => _AuditLogSheetState();
}

class _AuditLogSheetState extends State<_AuditLogSheet> {
  String? _entityFilter;
  late Future<List<AuditEntry>> _future = _load();

  Future<List<AuditEntry>> _load() async {
    final provider = context.read<ZainNotoProvider>();
    final entries = await provider.repository.getAuditLog(
      entity: _entityFilter,
      limit: 200,
    );
    return entries.reversed.toList();
  }

  void _setFilter(String? value) {
    setState(() {
      _entityFilter = value;
      _future = _load();
    });
  }

  void _showEntryDetail(AuditEntry entry) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.tokens;
        return AlertDialog(
          title: Text(
            '${_entityLabel(entry.entity)} · ${_actionLabel(entry.action)}',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatWaktuLengkap(entry.createdAt),
                    style: TextStyle(fontSize: AppText.label, color: t.textMuted),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    'ID: ${entry.entityId}',
                    style: TextStyle(fontSize: AppText.label, color: t.textMuted),
                  ),
                  if (entry.oldJson != null) ...[
                    const SizedBox(height: 12),
                    _JsonBlock(label: 'Sebelum', json: entry.oldJson!),
                  ],
                  if (entry.newJson != null) ...[
                    const SizedBox(height: 12),
                    _JsonBlock(label: 'Sesudah', json: entry.newJson!),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (sheetContext, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: t.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            color: t.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Riwayat Perubahan',
                                style: TextStyle(
                                  fontSize: AppText.title,
                                  fontWeight: FontWeight.w800,
                                  color: t.textPrimary,
                                ),
                              ),
                              Text(
                                'Catatan otomatis perubahan data kas',
                                style: TextStyle(fontSize: AppText.body, color: t.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          tooltip: 'Tutup',
                          icon: Icon(Icons.close_rounded, color: t.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filter in _entityFilters) ...[
                            ChoiceChip(
                              label: Text(filter.label),
                              selected: _entityFilter == filter.value,
                              onSelected: (_) => _setFilter(filter.value),
                              labelStyle: TextStyle(
                                fontSize: AppText.body,
                                fontWeight: FontWeight.w600,
                                color: _entityFilter == filter.value
                                    ? t.onAccent
                                    : t.textMuted,
                              ),
                              selectedColor: t.accent,
                              backgroundColor: t.softSurface,
                              side: BorderSide(
                                color: t.border.withValues(alpha: 0.6),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<AuditEntry>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Gagal memuat riwayat',
                          style: TextStyle(color: t.textMuted),
                        ),
                      );
                    }
                    final entries = snapshot.data ?? const <AuditEntry>[];
                    if (entries.isEmpty) {
                      return Center(
                        child: Text(
                          'Belum ada riwayat perubahan',
                          style: TextStyle(color: t.textMuted),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _AuditEntryTile(entry: entries[index], onTap: _showEntryDetail),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuditEntryTile extends StatelessWidget {
  const _AuditEntryTile({required this.entry, required this.onTap});

  final AuditEntry entry;
  final ValueChanged<AuditEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDelete = entry.action == 'delete';
    final isInsert = entry.action == 'insert';
    final badgeColor = isDelete
        ? t.expense
        : isInsert
            ? t.income
            : t.accent;
    final hasDetail = entry.oldJson != null || entry.newJson != null;

    return Material(
      color: t.softSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: hasDetail ? () => onTap(entry) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _actionIcon(entry.action),
                  size: 17,
                  color: badgeColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_entityLabel(entry.entity)} ${_actionLabel(entry.action)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppText.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatWaktuLengkap(entry.createdAt),
                      style: TextStyle(fontSize: AppText.label, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              if (hasDetail)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: t.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.label, required this.json});

  final String label;
  final String json;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppText.body,
            fontWeight: FontWeight.w700,
            color: t.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.softSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            _prettyJson(json),
            style: TextStyle(
              fontSize: AppText.label,
              fontFamily: 'monospace',
              height: 1.4,
              color: t.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
