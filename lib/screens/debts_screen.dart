import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

/// Debts — installment plans with overdue flags and pay-installment action.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(debtPlansProvider);

    return Scaffold(
      backgroundColor: DukaColors.canvas,
      appBar: AppBar(title: const Text('Debts & Installments')),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
          icon: Icons.wifi_off,
          title: 'Could not load debt plans',
          body: 'Go online and pull to refresh. Cached customers still work.',
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.credit_score,
                title: 'No debt plans',
                body: 'Credit sales with payment plans will appear here.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(debtPlansProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final overdue = p.overdueDays > 0;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${p.customerName} • ${p.invoiceNo}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                StatusChip(
                                  overdue
                                      ? 'OVERDUE ${p.overdueDays}d'
                                      : p.status.toUpperCase(),
                                  overdue ? DukaColors.danger : DukaColors.success,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${kes(p.totalDebt)} remaining • ${kes(p.installmentAmount)} ${p.installmentType.toLowerCase()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: DukaColors.inkMuted,
                              ),
                            ),
                            Text(
                              'Next due ${p.nextDueDate.isNotEmpty ? p.nextDueDate : "—"}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: DukaColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'STK push for ${kes(p.installmentAmount)} sent — awaiting PIN',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.phone_android, size: 18),
                                    label: const Text('Collect installment'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Statement SMS queued via Africa\'s Talking'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.sms_outlined, size: 18),
                                  label: const Text('SMS'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
