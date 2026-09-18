import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

/// Reports — 7-day sales bars + payment mix, computed from local history.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final now = DateTime.now();

    // 7-day buckets
    final days = List.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day - (6 - i));
      final sales = history
          .where((s) =>
              s.createdAt.year == d.year &&
              s.createdAt.month == d.month &&
              s.createdAt.day == d.day)
          .fold<double>(0, (sum, s) => sum + s.total);
      return (label: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d.weekday - 1], total: sales);
    });
    final maxDay = days.map((d) => d.total).fold<double>(0, (a, b) => a > b ? a : b);

    // payment mix
    final byMethod = <String, double>{};
    for (final s in history) {
      byMethod[s.paymentMethod] = (byMethod[s.paymentMethod] ?? 0) + s.total;
    }
    final weekTotal = days.fold<double>(0, (a, d) => a + d.total);

    return Scaffold(
      backgroundColor: DukaColors.canvas,
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  label: 'Last 7 days',
                  value: kes(weekTotal, compact: true),
                  icon: Icons.insights,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: KpiCard(
                  label: 'Receipts',
                  value: '${history.length}',
                  icon: Icons.receipt_long,
                  color: DukaColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales • Last 7 days',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in days) ...[
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  d.total > 0 ? kes(d.total, compact: true).replaceAll('KES ', '') : '',
                                  style: const TextStyle(fontSize: 8.5, color: DukaColors.inkMuted),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 8 +
                                      (maxDay > 0 ? (d.total / maxDay) * 100 : 0),
                                  decoration: BoxDecoration(
                                    color: d.total > 0
                                        ? DukaColors.primary
                                        : DukaColors.border,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  d.label,
                                  style: const TextStyle(fontSize: 9.5, color: DukaColors.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader('Payment mix'),
          if (byMethod.isEmpty)
            const EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'No data yet',
              body: 'Make a few sales and the mix will light up.',
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    for (final e in byMethod.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 96,
                              child: Text(
                                e.key,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: weekTotal > 0 ? e.value / weekTotal : 0,
                                  minHeight: 8,
                                  backgroundColor: DukaColors.border,
                                  color: DukaColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              kes(e.value, compact: true),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
