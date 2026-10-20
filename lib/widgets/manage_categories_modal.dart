import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/finance_provider.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

class ManageCategoriesModal extends StatefulWidget {
  final String initialType; // 'expense' or 'income'
  const ManageCategoriesModal({super.key, required this.initialType});

  @override
  State<ManageCategoriesModal> createState() => _ManageCategoriesModalState();
}

class _ManageCategoriesModalState extends State<ManageCategoriesModal> {
  late String _type;
  bool _isCreating = false;

  // New Category Form State
  final _nameCtrl = TextEditingController();
  String _selectedIcon = 'ellipsis';
  String _selectedColor = '#9b59b6';

  final List<Map<String, dynamic>> _availableIcons = const [
    {'name': 'fast_food', 'icon': Icons.fastfood_rounded},
    {'name': 'car', 'icon': Icons.directions_car_rounded},
    {'name': 'cart', 'icon': Icons.shopping_cart_rounded},
    {'name': 'gamepad_2', 'icon': Icons.sports_esports_rounded},
    {'name': 'heart_pulse', 'icon': Icons.favorite_rounded},
    {'name': 'receipt', 'icon': Icons.receipt_long_rounded},
    {'name': 'banknote', 'icon': Icons.payments_rounded},
    {'name': 'trending_up', 'icon': Icons.trending_up_rounded},
    {'name': 'gift', 'icon': Icons.redeem_rounded},
    {'name': 'ellipsis', 'icon': Icons.more_horiz_rounded},
  ];

  final List<String> _availableColors = const [
    '#ff7f50', // Coral
    '#3498db', // Blue
    '#9b59b6', // Purple
    '#e74c3c', // Red
    '#2ecc71', // Green
    '#f1c40f', // Yellow
    '#fd79a8', // Pink
    '#1abc9c', // Teal
    '#e67e22', // Orange
    '#34495e', // Slate
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  void _saveCategory() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama kategori!')),
      );
      return;
    }

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    provider.addCat(
      name: name,
      icon: _selectedIcon,
      color: _selectedColor,
      type: _type,
    );

    // Reset and close form
    setState(() {
      _nameCtrl.clear();
      _selectedIcon = 'ellipsis';
      _selectedColor = '#9b59b6';
      _isCreating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kategori "$name" berhasil ditambahkan!')),
    );
  }

  void _deleteCategory(Category cat) async {
    final usage = await DatabaseHelper.instance.categoryUsage(cat.id!);
    if (!mounted) return;
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final candidates = provider.categories
        .where((c) =>
            c.id != cat.id &&
            c.type == cat.type &&
            c.isSpecial == false)
        .toList();
    Category? target = candidates.isNotEmpty ? candidates.first : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Hapus Kategori'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Terdampak: ${usage.transactions} transaksi, ${usage.budgets} anggaran.'),
              const SizedBox(height: 8),
              if (usage.transactions > 0 || usage.budgets > 0) ...[
                const Text('Pindahkan ke:'),
                const SizedBox(height: 4),
                DropdownButton<Category>(
                  value: target,
                  items: candidates
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => target = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  if (usage.transactions > 0 || usage.budgets > 0) {
                    if (target == null) return;
                    await DatabaseHelper.instance
                        .reassignCategory(cat.id!, target!.id!);
                  }
                  await provider.deleteCat(cat.id!);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Kategori "${cat.name}" telah dihapus.')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: Text(
                usage.transactions > 0 || usage.budgets > 0
                    ? 'Pindahkan dan hapus'
                    : 'Hapus',
                style: TextStyle(color: ctx.tokens.expense),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final tokens = context.tokens;
    final modalBg = tokens.card;
    final borderCol = tokens.border;

    final filteredCats = provider.categories.where((c) => c.type == _type).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: modalBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderCol,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_isCreating) {
                          setState(() => _isCreating = false);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.softSurface,
                          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                        ),
                        child: Icon(
                          _isCreating ? Icons.arrow_back_ios_new_rounded : Icons.close_rounded,
                          size: 18,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _isCreating ? 'Tambah Kategori' : 'Kelola Kategori',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 34),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tabs (Only show if not currently creating a category)
              if (!_isCreating)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabBtn(
                          label: 'Pengeluaran',
                          isActive: _type == 'expense',
                          activeColor: tokens.expense,
                          onTap: () => setState(() => _type = 'expense'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TabBtn(
                          label: 'Pemasukan',
                          isActive: _type == 'income',
                          activeColor: tokens.income,
                          onTap: () => setState(() => _type = 'income'),
                        ),
                      ),
                    ],
                  ),
                ),

              // Dynamic content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isCreating
                      ? _buildCreateForm()
                      : _buildCategoriesList(filteredCats),
                ),
              ),

              // Footer Button
              if (!_isCreating)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: borderCol, width: 0.5)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.accent,
                        foregroundColor: tokens.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadius)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => setState(() => _isCreating = true),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Buat Kategori Baru',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesList(List<Category> cats) {
    final tokens = context.tokens;
    if (cats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.category_outlined, size: 48, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text(
              'Belum ada kategori ${_type == 'expense' ? 'pengeluaran' : 'pemasukan'}.',
              style: TextStyle(fontSize: AppText.bodyLarge, color: tokens.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cats.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final cat = cats[i];
        final catColor = _parseColor(cat.color);
        final isDefault = cat.isSpecial; // Internal categories cannot be deleted

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tokens.border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: catColor,
                child: Icon(
                  _availableIcons.firstWhere(
                    (ic) => ic['name'] == cat.icon,
                    orElse: () => _availableIcons.last,
                  )['icon'] as IconData,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppText.subtitle),
                    ),
                    if (isDefault)
                      Text(
                        'Bawaan Sistem',
                        style: TextStyle(fontSize: AppText.micro, color: tokens.textMuted),
                      ),
                  ],
                ),
              ),
              // Internal categories are locked; user categories can be deleted
              if (!isDefault)
                IconButton(
                  tooltip: 'Hapus kategori',
                  icon: Icon(Icons.delete_outline_rounded, color: tokens.expense),
                  onPressed: () => _deleteCategory(cat),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateForm() {
    final tokens = context.tokens;
    final accentColor = _type == 'expense' ? tokens.expense : tokens.income;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name Field
        Text(
          'Nama Kategori',
          style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w600, color: tokens.textMuted),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          style: const TextStyle(fontSize: AppText.subtitle),
          decoration: InputDecoration(
            hintText: 'Misal: Kosan, Liburan, Freelance...',
            fillColor: tokens.softSurface,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),

        // Color Picker
        Text(
          'Pilih Warna',
          style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w600, color: tokens.textMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _availableColors.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final colorHex = _availableColors[i];
              final isSelected = _selectedColor == colorHex;
              final color = _parseColor(colorHex);

              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorHex),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: tokens.textPrimary,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Icon Picker
        Text(
          'Pilih Ikon',
          style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w600, color: tokens.textMuted),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: _availableIcons.length,
          itemBuilder: (_, i) {
            final iconMap = _availableIcons[i];
            final iconName = iconMap['name'] as String;
            final iconData = iconMap['icon'] as IconData;
            final isSelected = _selectedIcon == iconName;

            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = iconName),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.15)
                      : tokens.softSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? accentColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  iconData,
                  color: isSelected ? accentColor : tokens.textMuted,
                  size: 22,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        // Save Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadius)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _saveCategory,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Simpan Kategori', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeBg = activeColor.withValues(alpha: 0.12);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeBg : tokens.softSurface,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          border: Border.all(
            color: isActive ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppText.bodyLarge,
              fontWeight: FontWeight.w700,
              color: isActive ? activeColor : tokens.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
