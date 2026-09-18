import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'more_screen.dart';
import 'pos_screen.dart';
import 'scanner_screen.dart';

/// App shell - bottom navigation (Home / Sell / Scan / History / More)
/// with a central scan FAB, offline banner and sync indicator.
class HomeShell extends ConsumerStatefulWidget {
  final int initialTab;

  const HomeShell({super.key, this.initialTab = 0});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int _tab = widget.initialTab;

  static const _screens = <Widget>[
    DashboardScreen(),
    PosScreen(),
    SizedBox(), // scan opens as a route via FAB
    HistoryScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    final session = ref.watch(sessionProvider);
    final showOffline = !sync.online;
    final showFab = _tab == 0 || _tab == 1 || _tab == 3;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.storefront, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                session.user?.storeName ?? 'Thika Road',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Offline queue badge - tap to force sync.
          IconButton(
            tooltip: 'Sync',
            onPressed: () => ref.read(syncProvider.notifier).syncNow(),
            icon: Badge(
              isLabelVisible: sync.queueLength > 0,
              label: Text('${sync.queueLength}'),
              child: sync.syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DukaColors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (showOffline) OfflineBanner(onTap: () => ref.read(syncProvider.notifier).syncNow()),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: _screens[_tab],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              heroTag: 'scan-fab',
              backgroundColor: DukaColors.success,
              foregroundColor: DukaColors.white,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ScannerScreen()),
                );
                if (_tab != 1) setState(() => _tab = 1);
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.dashboard_outlined,
              active: Icons.dashboard,
              label: 'Home',
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0),
            ),
            _NavItem(
              icon: Icons.point_of_sale_outlined,
              active: Icons.point_of_sale,
              label: 'Sell',
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1),
            ),
            const SizedBox(width: 56), // FAB notch
            _NavItem(
              icon: Icons.receipt_long_outlined,
              active: Icons.receipt_long,
              label: 'Sales',
              selected: _tab == 3,
              onTap: () => setState(() => _tab = 3),
            ),
            _NavItem(
              icon: Icons.menu,
              active: Icons.menu,
              label: 'More',
              selected: _tab == 4,
              onTap: () => setState(() => _tab = 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData active;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.active,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? DukaColors.primary : DukaColors.inkMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? active : icon, color: color, size: 22),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
