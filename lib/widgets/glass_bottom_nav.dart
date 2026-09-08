import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback? onTap;
  final int? badgeCount;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.onTap,
    this.badgeCount,
  });
}

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<NavItem> items;
  final Color activeColor;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
    required this.items,
    this.activeColor = const Color(0xFF7FAA75),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isActive = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      onTap?.call(i);
                      item.onTap?.call();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.only(
                        top: 8,
                        bottom: 8,
                        left: isActive ? 6 : 4,
                        right: isActive ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? activeColor.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                isActive ? item.activeIcon : item.icon,
                                size: 24,
                                color: isActive ? activeColor : const Color(0xFF999999),
                              ),
                              if (item.badgeCount != null && item.badgeCount! > 0)
                                Positioned(
                                  top: -6,
                                  right: -14,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFC62828),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${item.badgeCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive ? activeColor : const Color(0xFF999999),
                            ),
                          ),
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 18,
                              height: 3,
                              decoration: BoxDecoration(
                                color: activeColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
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
    );
  }
}
