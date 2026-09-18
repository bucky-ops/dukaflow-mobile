import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/printer_service.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

/// Receipt — 80mm thermal preview with KRA eTIMS QR + Code128 barcode,
/// Bluetooth print, WhatsApp share. Wireframe receipt layout.
class ReceiptScreen extends ConsumerStatefulWidget {
  final Sale sale;
  final bool justPaid;

  const ReceiptScreen({super.key, required this.sale, this.justPaid = false});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _printing = false;
  bool _printed = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      if (PrinterService.connected == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No printer connected — open Settings → Printers'),
        ));
        return;
      }
      final ok = await PrinterService.printReceipt(
        storeName: 'DUKAFLOW LTD',
        storeSub: 'Thika Road Mall, Nairobi • 0712 345 678',
        kraPin: 'P051234567K',
        receiptNo: widget.sale.displayNo,
        cashier: widget.sale.staffName,
        customerLine: widget.sale.customerName != null
            ? 'Customer: ${widget.sale.customerName}'
            : null,
        items: [for (final l in widget.sale.lines) (l.product.name, l.lineTotal)],
        subtotal: widget.sale.subtotal,
        discount: widget.sale.discount,
        vat: widget.sale.vat,
        total: widget.sale.total,
        paymentLine: widget.sale.paymentMethod.toUpperCase(),
        loyaltyLine: widget.sale.redeemLoyalty ? 'Loyalty redeemed' : null,
        cuInvoice: 'KRAMW000123456',
        when: widget.sale.createdAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Printing on EPSON TM-T20…' : 'Print failed — check printer'),
      ));
      if (ok) setState(() => _printed = true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _shareWhatsApp() {
    final s = widget.sale;
    final buf = StringBuffer()
      ..writeln('*DukaFlow Receipt ${s.displayNo}*')
      ..writeln('Total: ${kes(s.total)} (${s.paymentMethod})');
    for (final l in s.lines) {
      buf.writeln('${l.product.name} x${l.qty.toStringAsFixed(0)} = ${kes(l.lineTotal)}');
    }
    buf.writeln('KRA eTIMS Verified • Asante!');
    final url =
        'https://wa.me/?text=${Uri.encodeComponent(buf.toString())}';
    // No url_launcher dep — copy to clipboard + snackbar (fast, offline-safe).
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('WhatsApp share text copied — paste in WhatsApp'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    final qrData = 'DUKAFLOW|${s.displayNo}|${s.total.toStringAsFixed(0)}|'
        'CU:KRAMW000123456|${s.createdAt.toIso8601String()}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt ${s.displayNo}'),
        actions: [
          if (s.synced)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: StatusChip('SYNCED', DukaColors.success)),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: StatusChip('PENDING SYNC', DukaColors.warning)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.justPaid) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DukaColors.successLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DukaColors.success),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: DukaColors.success, size: 40),
                  const SizedBox(height: 6),
                  Text(
                    'Sale Successful!',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: DukaColors.ink,
                    ),
                  ),
                  Text(
                    'KRA eTIMS Verified • ${s.paymentMethod} Confirmed',
                    style: const TextStyle(fontSize: 12, color: DukaColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          // ── Thermal paper mock ────────────────────────────────
          Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
              decoration: BoxDecoration(
                color: DukaColors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'DUKAFLOW LTD',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  Text(
                    'Thika Road Mall, Nairobi • 0712 345 678',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9.5, color: DukaColors.inkMuted),
                  ),
                  Text(
                    'PIN: P051234567K • BRANCH: 01',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9.5, color: DukaColors.inkMuted),
                  ),
                  const Divider(height: 14),
                  Text(
                    'RECEIPT • ${s.displayNo}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  Text(
                    'Date: ${fmtDate(s.createdAt)} • ${s.staffName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9.5),
                  ),
                  if (s.customerName != null)
                    Text(
                      'Customer: ${s.customerName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9.5),
                    ),
                  const Divider(height: 14),
                  ...s.lines.map(
                    (l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              l.product.name,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${l.qty.toStringAsFixed(0)} x ${l.product.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 9.5, color: DukaColors.inkMuted),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.lineTotal.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 14),
                  _r('Subtotal', s.subtotal),
                  if (s.discount > 0)
                    _r('Discount${s.redeemLoyalty ? " (Loyalty)" : ""}', -s.discount),
                  _r('VAT 16% incl.', s.vat),
                  const Divider(height: 10),
                  Row(
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        'KES ${s.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.paymentMethod.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: DukaColors.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 96,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'CU: KRAMW000123456 • SCU: 01',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9),
                  ),
                  const Text(
                    'KRA eTIMS Verified',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: DukaColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Code128-style barcode from receipt no
                  _Barcode(data: s.displayNo),
                  const SizedBox(height: 6),
                  const Text(
                    '* Goods once sold not returnable *',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9),
                  ),
                  const Text(
                    'Powered by DukaFlow • v2.4.1',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 8.5, color: DukaColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _printing ? null : _print,
                  icon: _printing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: DukaColors.white),
                        )
                      : Icon(_printed ? Icons.print : Icons.print_outlined),
                  label: Text(_printed ? 'Print again' : 'Print'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareWhatsApp,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('New Sale'),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _r(String label, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: DukaColors.inkMuted)),
            const Spacer(),
            Text(
              v.toStringAsFixed(0),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

/// CSS-free barcode renderer: deterministic Code128-looking bars from text.
class _Barcode extends StatelessWidget {
  final String data;

  const _Barcode({required this.data});

  @override
  Widget build(BuildContext context) {
    final bars = <double>[];
    var seed = data.isEmpty ? 1 : data.codeUnitAt(0);
    for (var i = 0; i < 52; i++) {
      seed = (seed * 31 + (data.isEmpty ? 7 : data.codeUnitAt(i % data.length))) % 1000;
      bars.add(1.0 + (seed % 3)); // 1..3 px widths
    }
    return Column(
      children: [
        SizedBox(
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final w in bars)
                Container(
                  width: w,
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  color: Colors.black,
                ),
            ],
          ),
        ),
        Text(
          data,
          style: const TextStyle(fontSize: 9, letterSpacing: 2),
        ),
      ],
    );
  }
}
