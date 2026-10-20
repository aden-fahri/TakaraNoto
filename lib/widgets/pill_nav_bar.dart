import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem({required this.icon, required this.label});
}

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
  final bool showBadge;
  final int badgeIndex;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bgColor = t.nav;
    final activeColor = t.accent;
    final inactiveColor = t.textMuted;
    final pillColor = t.softSurface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: t.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 75.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: List.generate(items.length, (i) {
                final isActive = i == currentIndex;
                final showDot = showBadge && i == badgeIndex;

                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isActive,
                    label: items[i].label,
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isActive ? pillColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isActive)
                              Container(
                                width: 28,
                                height: 3,
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: activeColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                            else
                              const SizedBox(height: 9),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  items[i].icon,
                                  size: 22,
                                  color: isActive ? activeColor : inactiveColor,
                                ),
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
                            const SizedBox(height: 4),
                            ExcludeSemantics(
                              child: Text(
                                items[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppText.label,
                                  fontWeight: FontWeight.w500,
                                  color: isActive ? activeColor : inactiveColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
