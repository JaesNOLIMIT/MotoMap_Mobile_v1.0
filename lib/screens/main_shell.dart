import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import 'discover_screen.dart';
import 'home_screen.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';
import 'rides_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Discover'),
    (Icons.alt_route_outlined, Icons.alt_route_rounded, 'Plan'),
    (Icons.two_wheeler_outlined, Icons.two_wheeler_rounded, 'Rides'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenDiscover: () => setState(() => _index = 1)),
      const DiscoverScreen(),
      PlanScreen(onOpenRides: () => setState(() => _index = 3)),
      const RidesScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: MotoMapColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: MotoMapColors.background,
              border: Border.symmetric(
                vertical: BorderSide(color: MotoMapColors.outlineVariant),
              ),
            ),
            child: IndexedStack(index: _index, children: pages),
          ),
        ),
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              color: MotoMapColors.surface.withValues(alpha: 0.98),
              border: const Border(
                top: BorderSide(color: MotoMapColors.outlineVariant),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 68,
                child: Row(
                  children: List.generate(_items.length, (index) {
                    final item = _items[index];
                    final selected = _index == index;
                    return Expanded(
                      child: Semantics(
                        selected: selected,
                        label: item.$3,
                        child: InkWell(
                          onTap: () => setState(() => _index = index),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: selected ? 42 : 34,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? MotoMapColors.primary.withValues(
                                          alpha: 0.15,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  selected ? item.$2 : item.$1,
                                  size: 21,
                                  color: selected
                                      ? MotoMapColors.primary
                                      : MotoMapColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.$3,
                                style: TextStyle(
                                  color: selected
                                      ? MotoMapColors.primary
                                      : MotoMapColors.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
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
        ),
      ),
    );
  }
}
