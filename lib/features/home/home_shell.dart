import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/breakpoint_latch.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Android 首版：隐藏考试 / 工坊（桌面版保留）。
  static List<_NavItem> get _items {
    const core = <_NavItem>[
      _NavItem(
        icon: Icons.piano_outlined,
        selectedIcon: Icons.piano_rounded,
        label: '练习',
      ),
      _NavItem(
        icon: Icons.library_music_outlined,
        selectedIcon: Icons.library_music_rounded,
        label: '曲库',
      ),
    ];
    const desktopExtra = <_NavItem>[
      _NavItem(
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check_rounded,
        label: '考试',
      ),
      _NavItem(
        icon: Icons.handyman_outlined,
        selectedIcon: Icons.handyman_rounded,
        label: '工坊',
      ),
    ];
    const profile = _NavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: '我的',
    );
    if (Platform.isAndroid) {
      return [...core, profile];
    }
    return [...core, ...desktopExtra, profile];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return WideBreakpointBuilder(
      enter: 900,
      exit: 860,
      builder: (context, wide) {
        if (wide) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PracticeRail(
                  selectedIndex: navigationShell.currentIndex,
                  items: items,
                  onSelect: _goBranch,
                ),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            destinations: [
              for (final item in items)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Narrow rail: switch sections only. Song lists stay in the page.
class _PracticeRail extends StatelessWidget {
  const _PracticeRail({
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
  });

  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 18),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'P',
                style: AppTheme.body(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onAccent,
                ),
              ),
            ),
            const SizedBox(height: 22),
            for (var i = 0; i < items.length; i++)
              _RailButton(
                item: items[i],
                selected: selectedIndex == i,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.accent : AppColors.textSecondary;
    const radius = BorderRadius.all(Radius.circular(14));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : Colors.transparent,
            borderRadius: radius,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 22,
                      color: fg,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: AppTheme.body(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
