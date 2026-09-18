import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'receipt_screen.dart';

/// Sales history — merged pending + synced receipts with status filter.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'All'; // All | Pending | Synced

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(historyProvider.notifier).reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(historyProvider);
    final items = all.where((s) {
      return switch (_filter) {
        'Pending' => !s.synced,
        'Synced' => s.synced,
        _ => true,
      };
    }).toList();

    return Scaffold(
      backgroundColor: DukaColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sales & Receipts'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (final f in ['All', 'Pending', 'Synced']) ...[
                  ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    selectedColor: DukaColors.primary,
                    labelStyle: TextStyle(
                      color: _filter == f ? DukaColors.white : DukaColors.inkMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Text(
                  '${items.length} receipts',
                  style: const TextStyle(fontSize: 11, color: DukaColors.inkMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No receipts',
                    body: 'Your sales will appear here — online or offline.',
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.read(historyProvider.notifier).reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = items[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: s.synced
                                  ? DukaColors.successLight
                                  : DukaColors.warningLight,
                              child: Icon(
                                s.synced ? Icons.check : Icons.cloud_upload_outlined,
                                size: 18,
                                color: s.synced ? DukaColors.success : DukaColors.warning,
                              ),
                            ),
                            title: Text(
                              s.displayNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: Text(
                              '${s.customerName ?? "Walk-in"} • ${s.paymentMethod}\n'
                              '${fmtDate(s.createdAt)}',
                              style: const TextStyle(fontSize: 11, height: 1.4),
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  kes(s.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                StatusChip(
                                  s.synced ? 'Synced' : 'Pending',
                                  s.synced ? DukaColors.success : DukaColors.warning,
                                ),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ReceiptScreen(sale: s),
                                ),
                              );
                              ref.read(historyProvider.notifier).reload();
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
