import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/mpesa_service.dart';
import 'receipt_screen.dart';

/// M-Pesa STK status - "Awaiting customer PIN…" per the wireframe, with
/// graceful offline degradation. Tap continue to open the receipt.
class MpesaStatusScreen extends StatefulWidget {
  final Sale sale;
  final StkResult result;

  const MpesaStatusScreen({super.key, required this.sale, required this.result});

  @override
  State<MpesaStatusScreen> createState() => _MpesaStatusScreenState();
}

class _MpesaStatusScreenState extends State<MpesaStatusScreen>
    with SingleTickerProviderStateMixin {
  late StkResult _result = widget.result;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _result.status == StkStatus.awaitingPin ||
        _result.status == StkStatus.pushing;
    final offline = _result.status == StkStatus.offline;
    final failed = _result.status == StkStatus.failed;

    return Scaffold(
      appBar: AppBar(title: const Text('M-Pesa STK')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.06).animate(_pulse),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: waiting
                      ? DukaColors.primaryLight
                      : offline
                          ? DukaColors.warningLight
                          : DukaColors.dangerLight,
                  child: Icon(
                    waiting
                        ? Icons.phone_iphone
                        : offline
                            ? Icons.cloud_off
                            : Icons.error_outline,
                    size: 44,
                    color: waiting
                        ? DukaColors.primary
                        : offline
                            ? DukaColors.warning
                            : DukaColors.danger,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                waiting
                    ? 'Awaiting customer PIN…'
                    : offline
                        ? 'Offline - M-Pesa pending'
                        : failed
                            ? 'STK push failed'
                            : 'M-Pesa confirmed',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.sale.customerName ?? "Customer"} • ${kes(widget.sale.total)}',
                style: const TextStyle(color: DukaColors.inkMuted, fontSize: 13),
              ),
              Text(
                '${_result.message} • Receipt ${widget.sale.displayNo}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: DukaColors.inkMuted, fontSize: 12),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ReceiptScreen(sale: widget.sale, justPaid: true),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('View receipt'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sale is saved on-device and will sync - M-Pesa confirmation '
                'arrives via Daraja callback.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: DukaColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
