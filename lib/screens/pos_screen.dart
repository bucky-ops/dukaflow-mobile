import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';
import 'scanner_screen.dart';

/// POS - product grid with category chips + search, cart summary bar.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);

    if (products.items.isEmpty && !products.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(productsProvider.notifier).refresh();
      });
    }

    final categories = ['All', ...{for (final p in products.items) p.category}.toList()..sort()];
    var visible = products.items;
    if (_category != 'All') visible = visible.where((p) => p.category == _category).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      visible = visible
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              p.barcode.contains(q))
          .toList();
    }

    return Scaffold(
      backgroundColor: DukaColors.canvas,
      floatingActionButton: cart.lines.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: 'cart-fab',
              onPressed: () => _openCart(context),
              backgroundColor: DukaColors.primary,
              foregroundColor: DukaColors.white,
              icon: Badge(
                label: Text('${cart.count.toInt()}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              label: Text(kes(cart.totals.total)),
            )
          : null,
      body: Column(
        children: [
          // Search + scan bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search items or scan barcode (F2)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: DukaColors.primary),
                        onPressed: () => _scan(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Category chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = categories[i];
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  selectedColor: DukaColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? DukaColors.white : DukaColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _category = c),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          if (products.loading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: visible.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products',
                    body: 'Products cache is empty. Go online once to cache the catalog.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 190,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.88,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final p = visible[i];
                      return _ProductCard(
                        product: p,
                        onTap: () {
                          ref.read(cartProvider.notifier).add(p);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${p.name} added to cart'),
                              duration: const Duration(milliseconds: 800),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _scan(BuildContext context) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ScannerScreen()),
    );
    if (code == null) return;
    final p = ref.read(productsProvider.notifier).byBarcode(code);
    if (p != null) {
      ref.read(cartProvider.notifier).add(p);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${p.name} • ${kes(p.price)} added')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No product for barcode $code')),
        );
      }
    }
  }
}

void _openCart(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CartScreen()));
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  if (product.isLow)
                    const StatusChip('LOW', DukaColors.danger),
                ],
              ),
              const Spacer(),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              Text(
                '${product.sku} • ${product.qty} in stock',
                style: const TextStyle(fontSize: 10, color: DukaColors.inkMuted),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    kes(product.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: DukaColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: DukaColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: DukaColors.white, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
