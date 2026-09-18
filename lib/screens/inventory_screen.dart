import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

/// Inventory — stock levels with low-stock flags + store transfer composer
/// (mirrors the wireframe's Stock Transfer card).
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _fromStore = 'Thika Road';
  String _toStore = 'Kiambu Road';
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final list = products.items;
    final lowCount = list.where((p) => p.isLow).length;

    return Scaffold(
      backgroundColor: DukaColors.canvas,
      appBar: AppBar(title: Text('Inventory • $lowCount low')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stock transfer composer (wireframe) ────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz, color: DukaColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Stock Transfer',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const Spacer(),
                      StatusChip('$_selected selected', DukaColors.primary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StoreDropdown(
                          label: 'From Store',
                          value: _fromStore,
                          items: const ['Thika Road', 'Kiambu Road'],
                          onChanged: (v) => setState(() => _fromStore = v),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 18),
                      ),
                      Expanded(
                        child: _StoreDropdown(
                          label: 'To Store',
                          value: _toStore,
                          items: const ['Thika Road', 'Kiambu Road'],
                          onChanged: (v) => setState(() => _toStore = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selected.isEmpty || _fromStore == _toStore
                          ? null
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                  'Transfer of $_selected items queued '
                                  '($_fromStore → $_toStore) — syncs when online',
                                ),
                              ));
                              setState(() => _selected.clear());
                            },
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Submit Transfer'),
                    ),
                  ),
                  if (_fromStore == _toStore)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Pick two different stores',
                        style: TextStyle(fontSize: 11, color: DukaColors.danger),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SectionHeader(
            'Stock Levels',
            action: 'Refresh',
            onAction: () => ref.read(productsProvider.notifier).refresh(),
          ),
          ...list.map((p) {
            final low = p.isLow;
            return Card(
              child: CheckboxListTile(
                value: _selected.contains(p.id),
                onChanged: (v) => setState(() {
                  v == true ? _selected.add(p.id) : _selected.remove(p.id);
                }),
                secondary: Text(p.emoji, style: const TextStyle(fontSize: 22)),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    if (low) ...[
                      const SizedBox(width: 6),
                      const StatusChip('LOW', DukaColors.danger),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${p.sku} • ${kes(p.price)} • reorder @ ${p.reorderPoint}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  '${p.qty}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: low ? DukaColors.danger : DukaColors.ink,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StoreDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _StoreDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: DukaColors.inkMuted),
        ),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          items: [
            for (final s in items)
              DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10)),
        ),
      ],
    );
  }
}
