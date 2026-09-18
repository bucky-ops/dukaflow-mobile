import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'customers_screen.dart';
import 'debts_screen.dart';
import 'inventory_screen.dart';
import 'history_screen.dart';
import 'pos_screen.dart';
import 'receipt_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

/// Home - KPIs, Quick Actions grid, Live Sales Feed (wireframe screen 3).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final history = ref.watch(historyProvider);
    final data = dash.asData?.value ?? DashboardData.empty;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        await ref.read(productsProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(
                'Today • ${fmtDateShort(DateTime.now())}',
                style: const TextStyle(color: DukaColors.inkMuted, fontSize: 12),
              ),
              const SizedBox(width: 8),
              const StatusChip('ONLINE • KRA Connected', DukaColors.success),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  label: 'Sales today (${data.todayCount})',
                  value: kes(data.todaySales, compact: true),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiCard(
                  label: '7-day sales',
                  value: kes(data.weekSales, compact: true),
                  icon: Icons.trending_up,
                  color: DukaColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  label: 'Debt outstanding',
                  value: kes(data.debtOutstanding, compact: true),
                  icon: Icons.credit_score,
                  color: DukaColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiCard(
                  label: 'Low stock items',
                  value: '${data.lowStock}',
                  icon: Icons.inventory_2_outlined,
                  color: DukaColors.danger,
                ),
              ),
            ],
          ),
          const SectionHeader('Quick Actions'),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _Action(
                icon: Icons.point_of_sale,
                label: 'New Sale',
                onTap: () => _go(context, const PosScreen()),
              ),
              _Action(
                icon: Icons.people_alt_outlined,
                label: 'Customers',
                onTap: () => _go(context, const CustomersScreen()),
              ),
              _Action(
                icon: Icons.credit_score_outlined,
                label: 'Debts',
                onTap: () => _go(context, const DebtsScreen()),
              ),
              _Action(
                icon: Icons.inventory_outlined,
                label: 'Stock',
                onTap: () => _go(context, const InventoryScreen()),
              ),
              _Action(
                icon: Icons.receipt_long_outlined,
                label: 'Receipts',
                onTap: () => _go(context, const HistoryScreen()),
              ),
              _Action(
                icon: Icons.insights,
                label: 'Reports',
                onTap: () => _go(context, const ReportsScreen()),
              ),
              _Action(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => _go(context, const SettingsScreen()),
              ),
              _Action(
                icon: Icons.sync,
                label: 'Sync Now',
                onTap: () => ref.read(syncProvider.notifier).syncNow(),
              ),
            ],
          ),
          const SectionHeader('Live Sales Feed', action: 'View All'),
          if (history.isEmpty)
            const EmptyState(
              icon: Icons.point_of_sale_outlined,
              title: 'No sales yet',
              body: 'Tap Sell or Scan to make your first sale - works fully offline.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (final s in history.take(6))
                    ListTile(
                      dense: true,
                      leading: const Avatar('DF', size: 34),
                      title: Text(
                        s.customerName ?? 'Walk-in customer',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${s.displayNo} • ${s.paymentMethod}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        kes(s.total),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: s.synced ? DukaColors.success : DukaColors.warning,
                        ),
                      ),
                      onTap: () => _go(context, ReceiptScreen(sale: s)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DukaColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: DukaColors.primary, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
