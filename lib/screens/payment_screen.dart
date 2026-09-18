import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../data/hive_service.dart';
import '../data/sync_service.dart';
import '../models/models.dart';
import '../services/mpesa_service.dart';
import '../state/providers.dart';
import 'mpesa_status_screen.dart';
import 'receipt_screen.dart';

/// Payment — method selector (Cash / M-Pesa STK / Card / Credit Sale),
/// tendered change for cash, then finalize the sale OFFLINE-FIRST.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentMethod _method = PaymentMethod.cash;
  final _tenderedCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tenderedCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _finalize() async {
    final cart = ref.read(cartProvider);
    if (cart.lines.isEmpty) return;
    final total = cart.totals.total;
    final tendered = double.tryParse(_tenderedCtrl.text) ?? 0;

    if (_method == PaymentMethod.cash && tendered < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tendered ${kes(tendered)} is less than total ${kes(total)}')),
      );
      return;
    }

    setState(() => _saving = true);

    final session = ref.read(sessionProvider).user;
    final sale = Sale(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      receiptNo: HiveService.nextOfflineReceiptNo(),
      customerId: cart.customer?.id,
      customerName: cart.customer?.name,
      staffName: session?.name ?? 'Mobile',
      lines: cart.lines,
      paymentMethod: _method.wire,
      subtotal: cart.totals.subtotal,
      discount: cart.totals.discount,
      vat: cart.totals.vat,
      total: total,
      tendered: tendered,
      redeemLoyalty: cart.redeemLoyalty,
      createdAt: DateTime.now(),
    );

    // 1) OFFLINE FIRST — persist to Hive 'pending_sales' immediately.
    SyncService.saveOffline(sale);

    // 2) Try instant sync (skips silently when offline).
    unawaited(ref.read(syncProvider.notifier).syncNow());

    // 3) M-Pesa STK push when selected.
    if (_method == PaymentMethod.mpesaStk) {
      final res = await MpesaService.push(
        phone: _phoneCtrl.text.trim(),
        amount: total,
        receiptNo: sale.receiptNo,
      );
      if (!mounted) return;
      ref.read(cartProvider.notifier).clear();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => MpesaStatusScreen(
            sale: sale,
            result: res,
          ),
        ),
        (r) => r.isFirst,
      );
      return;
    }

    if (!mounted) return;
    ref.read(cartProvider.notifier).clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => ReceiptScreen(sale: sale, justPaid: true)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = cart.totals.total;
    final tendered = double.tryParse(_tenderedCtrl.text) ?? 0;
    final change = tendered - total;

    return Scaffold(
      appBar: AppBar(title: Text('Pay ${kes(total)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose payment method',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DukaColors.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...PaymentMethod.values.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                color: _method == m ? DukaColors.primaryLight : DukaColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _method == m ? DukaColors.primary : DukaColors.border,
                    width: _method == m ? 2 : 1,
                  ),
                ),
                child: RadioListTile<PaymentMethod>(
                  value: m,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                  title: Text(
                    m.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    switch (m) {
                      PaymentMethod.cash => 'Count cash + change calculator',
                      PaymentMethod.mpesaStk => 'Lipa na M-Pesa — STK push (Daraja)',
                      PaymentMethod.card => 'Card terminal settlement',
                      PaymentMethod.creditSale => 'Record as customer debt',
                    },
                    style: const TextStyle(fontSize: 11),
                  ),
                  secondary: Icon(
                    switch (m) {
                      PaymentMethod.cash => Icons.payments,
                      PaymentMethod.mpesaStk => Icons.phone_android,
                      PaymentMethod.card => Icons.credit_card,
                      PaymentMethod.creditSale => Icons.credit_score,
                    },
                    color: DukaColors.primary,
                  ),
                ),
              ),
            ),
          ),
          if (_method == PaymentMethod.cash) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _tenderedCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cash tendered',
                prefixText: 'KES ',
                suffixIcon: IconButton(
                  tooltip: 'Exact',
                  icon: const Icon(Icons.equalizer),
                  onPressed: () =>
                      setState(() => _tenderedCtrl.text = total.toStringAsFixed(0)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Change due',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  kes(change > 0 ? change : 0),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: change > 0 ? DukaColors.success : DukaColors.inkMuted,
                  ),
                ),
              ],
            ),
          ],
          if (_method == PaymentMethod.mpesaStk) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'M-Pesa phone number',
                prefixText: '+254 ',
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
          ],
          if (_method == PaymentMethod.creditSale && cart.customer == null) ...[
            const SizedBox(height: 8),
            const StatusChip('Credit sale needs a customer — pick one in cart',
                DukaColors.warning),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _finalize,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DukaColors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _method == PaymentMethod.mpesaStk
                    ? 'Send STK Push & Save'
                    : 'Complete Sale • ${kes(total)}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Sale is saved on-device first, then synced — never lose a sale.',
              style: TextStyle(fontSize: 11, color: DukaColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
