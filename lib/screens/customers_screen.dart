import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'customer_detail_screen.dart';

/// Customers — search by phone (wireframe), debtors summary, tier badges.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final query = _q.trim().toLowerCase();
    final list = query.isEmpty
        ? customers
        : customers
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                c.phone.replaceAll(' ', '').contains(query.replaceAll(' ', '')))
            .toList();
    final debtors = customers.where((c) => c.debtBalance > 0).length;

    return Scaffold(
      backgroundColor: DukaColors.canvas,
      appBar: AppBar(title: Text('Customers • ${customers.length}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Search by phone or name…',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                StatusChip('Debtors • $debtors', DukaColors.warning),
                const SizedBox(width: 8),
                StatusChip(
                  'All • ${customers.length}',
                  DukaColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.person_search,
                    title: 'No customers found',
                    body: 'Try another phone number, or go online to refresh.',
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(customersProvider.notifier).refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = list[i];
                        return Card(
                          child: ListTile(
                            leading: Avatar(c.name),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TierBadge(c.tier),
                              ],
                            ),
                            subtitle: Text(
                              '${c.phone} • ${c.loyaltyPoints} pts'
                              '${c.debtBalance > 0 ? " • debt ${kes(c.debtBalance)}" : ""}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CustomerDetailScreen(customer: c),
                              ),
                            ),
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
