import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Data class for a bottom navigation item.
class NavItem {
  final IconData icon;
  final String label;
  const NavItem({required this.icon, required this.label});
}

/// Custom pill-style bottom navigation bar shared by both app shells
/// (Pribadi and Kelompok).
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.showBadge = false,
    this.badgeIndex = 2,
  });

  final int currentIndex;
  final List<NavItem> items;
  final ValueChanged<int> onTap;

  /// Shows a small alert dot on [badgeIndex].
  final bool showBadge;
  final int badgeIndex;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bgColor = t.card;
    final activeColor = t.accent;
    final inactiveColor = t.textMuted;
    final pillColor = t.softSurface;

    return Container(
      color: bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 0.5,
            color: t.border,
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: List.generate(items.length, (i) {
                    final isActive = i == currentIndex;
                    final showDot = showBadge && i == badgeIndex;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isActive ? pillColor : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppTheme.buttonRadius),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Icon(
                                      items[i].icon,
                                      key: ValueKey(isActive),
                                      size: isActive ? 26 : 24,
                                      color: isActive
                                          ? activeColor
                                          : inactiveColor,
                                    ),
                                  ),
                                  // Alert badge
                                  if (showDot)
                                    Positioned(
                                      right: -4,
                                      top: -3,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: t.expense,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (isActive) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: activeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
