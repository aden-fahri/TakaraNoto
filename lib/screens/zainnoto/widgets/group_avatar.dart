import 'package:flutter/material.dart';

/// Ikon yang bisa dipilih untuk grup; indeks 0 berarti tampilkan inisial
/// nama grup (default lama), indeks lain menunjuk [groupIconOptions].
const List<IconData?> groupIconOptions = [
  null, // inisial nama
  Icons.sports_soccer_rounded,
  Icons.school_rounded,
  Icons.volunteer_activism_rounded,
  Icons.celebration_rounded,
  Icons.savings_rounded,
  Icons.fitness_center_rounded,
  Icons.home_rounded,
  Icons.directions_bike_rounded,
  Icons.work_rounded,
  Icons.groups_rounded,
  Icons.favorite_rounded,
];

/// Circle avatar showing a group's initial or its chosen icon in its color.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.name,
    required this.colorHex,
    this.iconIndex = 0,
    this.size = 42,
  });

  final String name;
  final String colorHex;
  final int iconIndex;
  final double size;

  Color get _color {
    final cleaned = colorHex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return const Color(0xFF059669);
    return Color(0xFF000000 | value);
  }

  IconData? get _icon {
    if (iconIndex <= 0 || iconIndex >= groupIconOptions.length) return null;
    return groupIconOptions[iconIndex];
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final icon = _icon;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: size * 0.52, color: Colors.white)
          : Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
    );
  }
}
