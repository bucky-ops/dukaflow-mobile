import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'payment_screen.dart';

/// Cart - line qty steppers, customer picker (search by phone), loyalty
/// toggle ("Use 300 pts = KES 300"), totals with VAT 16%.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _searchCtrl = TextEditingController();
  Customer? _picked;

  @override
  void initState() {
    super.initState();
    _picked = ref.read(cartProvider).customer;
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final totals = cart.totals;
    final loyaltyPts = cart.customer?.loyaltyPoints ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          IconButton(
            tooltip: 'Clear cart',
            onPressed: cart.lines.isEmpty ? null : () {
              ref.read(cartProvider.notifier).clear();
              setState(() => _picked = null);
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Customer picker
                Card(
                  child: ListTile(
                    leading: _picked != null
                        ? Avatar(_picked!.name)
                        : const CircleAvatar(
                            backgroundColor: DukaColors.primaryLight,
                            child: Icon(Icons.person_add_alt, color: DukaColors.primary),
                          ),
                    title: Text(
                      _picked?.name ?? 'Walk-in customer',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    subtitle: _picked != null
                        ? Row(
                            children: [
                              Text(
                                _picked!.phone,
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              TierBadge(_picked!.tier),
                              Text(
                                ' • ${_picked!.loyaltyPoints} pts',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: DukaColors.inkMuted,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Tap to search by phone or name',
                            style: TextStyle(fontSize: 11),
                          ),
                    trailing: _picked != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              ref.read(cartProvider.notifier).setCustomer(null);
                              setState(() => _picked = null);
                            },
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => _pickCustomer(context),
                  ),
                ),
                const SizedBox(height: 12),
                if (cart.lines.isEmpty)
                  const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Cart is empty',
                    body: 'Add products from the Sell tab or scan a barcode.',
                  )
                else
                  ...cart.lines.map((l) => _LineTile(line: l)),
                // Loyalty toggle
                if (loyaltyPts > 0) ...[
                  const SizedBox(height: 10),
                  Card(
                    child: SwitchListTile(
                      value: cart.redeemLoyalty,
                      onChanged: (_) => ref.read(cartProvider.notifier).toggleRedeem(),
                      title: Text(
                        'Use $loyaltyPts pts = ${kes(loyaltyPts.toDouble())}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: DukaColors.primary,
                        ),
                      ),
                      subtitle: Text(
                        cart.redeemLoyalty
                            ? 'Loyalty discount applied'
                            : 'Redeem loyalty points as discount',
                        style: const TextStyle(fontSize: 11),
                      ),
                      secondary: const Icon(Icons.stars, color: DukaColors.primary),
                    ),
                  ),
                ],
                // Bill discount
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bill discount (KES)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(hintText: '0'),
                        onChanged: (v) => ref
                            .read(cartProvider.notifier)
                            .setExtraDiscount(double.tryParse(v) ?? 0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Totals + pay
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: DukaColors.white,
              border: Border(top: BorderSide(color: DukaColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  _TotalRow('Subtotal', kes(totals.subtotal)),
                  if (totals.discount > 0)
                    _TotalRow('Discount', '-${kes(totals.discount)}',
                        color: DukaColors.danger),
                  _TotalRow('VAT 16%', kes(totals.vat)),
                  const Divider(height: 14),
                  Row(
                    children: [
                      const Text(
                        'GRAND TOTAL',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        kes(totals.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: DukaColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: cart.lines.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PaymentScreen(),
                                ),
                              ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Charge'),
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

  Future<void> _pickCustomer(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: 520,
          child: StatefulBuilder(
            builder: (ctx, setModal) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: (_) => setModal(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search by phone or name…',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: _results().isEmpty
                      ? const EmptyState(
                          icon: Icons.person_search,
                          title: 'No customers',
                          body: 'Go online once to cache customers, or sell as walk-in.',
                        )
                      : ListView.builder(
                          itemCount: _results().length,
                          itemBuilder: (_, i) {
                            final c = _results()[i];
                            return ListTile(
                              leading: Avatar(c.name),
                              title: Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                '${c.phone} • ${c.loyaltyPoints} pts',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: TierBadge(c.tier),
                              onTap: () {
                                ref.read(cartProvider.notifier).setCustomer(c);
                                setState(() => _picked = c);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _searchCtrl.clear();
  }

  List<Customer> _results() {
    final all = ref.read(customersProvider);
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return all;
    return all
        .where((c) =>
            c.name.toLowerCase().contains(q.toLowerCase()) ||
            c.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')))
        .toList();
  }
}

class _LineTile extends ConsumerWidget {
  final CartLine line;

  const _LineTile({required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.product.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    '${kes(line.product.price)} × ${line.qty} • ${line.product.sku}',
                    style: const TextStyle(fontSize: 11, color: DukaColors.inkMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () =>
                  ref.read(cartProvider.notifier).setQty(line.product, line.qty - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '${line.qty.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            IconButton(
              onPressed: () =>
                  ref.read(cartProvider.notifier).setQty(line.product, line.qty + 1),
              icon: const Icon(Icons.add_circle_outline, color: DukaColors.primary),
            ),
            SizedBox(
              width: 76,
              child: Text(
                kes(line.lineTotal),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _TotalRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: DukaColors.inkMuted),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color ?? DukaColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
