import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../data/sync_service.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

/// Sync Center — offline queue drill-down: progress, pending sales,
/// conflicts with "Resolve" (wireframe).
class SyncCenterScreen extends ConsumerStatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  ConsumerState<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends ConsumerState<SyncCenterScreen> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    final pending = SyncService.pendingSales();
    final synced = SyncService.cachedReceipts();
    final total = pending.length + synced.length;
    final pct = total == 0 ? 1.0 : synced.length / total;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        sync.online ? Icons.cloud_done : Icons.cloud_off,
                        color: sync.online ? DukaColors.success : DukaColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sync.online ? 'Online' : 'Offline — sales saved locally',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        '${(pct * 100).toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: DukaColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: DukaColors.border,
                      color: DukaColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${synced.length}/$total synced'
                    '${sync.lastSyncAt != null ? " • Last synced ${hhmm(sync.lastSyncAt!)}" : ""}',
                    style: const TextStyle(fontSize: 11.5, color: DukaColors.inkMuted),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _syncing || !sync.online
                          ? null
                          : () async {
                              setState(() => _syncing = true);
                              final r = await SyncService.syncPending();
                              if (!mounted) return;
                              setState(() => _syncing = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                  'Sync done — ${r.ok} uploaded'
                                  '${r.failed > 0 ? ", ${r.failed} waiting" : ""}',
                                ),
                              ));
                            },
                      icon: _syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DukaColors.white,
                              ),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('Sync Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (sync.conflicts.isNotEmpty) ...[
            const SectionHeader('Conflicts'),
            ...sync.conflicts.map(
              (c) => Card(
                color: DukaColors.dangerLight,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: DukaColors.danger),
                  title: Text(
                    'Conflict • ${c.receiptNo}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  subtitle: Text(
                    c.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () {
                      // Resolution: keep server state for stock conflicts —
                      // re-queue the sale untouched; owner reviews on web.
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Kept server stock — sale re-queued for review'),
                      ));
                    },
                    child: const Text('Resolve'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SectionHeader('Pending Sales • ${pending.length}'),
          if (pending.isEmpty)
            const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All synced',
              body: 'No pending sales. New offline sales appear here.',
            )
          else
            ...pending.map(
              (s) => Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined, color: DukaColors.warning),
                  title: Text(
                    '${s.displayNo} • ${kes(s.total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${s.customerName ?? "Walk-in"} • ${fmtDate(s.createdAt)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const StatusChip('PENDING', DukaColors.warning),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
