import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import 'receipt_screen.dart';

/// Full payslip detail - line items + Verified QR (wireframe).
class PayslipDetailScreen extends StatelessWidget {
  const PayslipDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DukaFlow Payslip')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: DukaColors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'DUKAFLOW PAYSLIP • SEP 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const Text(
                    'Kamau Maina • Cashier • Thika Road',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: DukaColors.inkMuted),
                  ),
                  const Divider(height: 18),
                  const _Line('Basic Pay', 'KES 30,000'),
                  const _Line('House allowance', 'KES 5,000'),
                  const _Line('Transport', 'KES 3,000'),
                  const _Line('Gross', 'KES 38,000', bold: true),
                  const Divider(height: 18),
                  const _Line('NSSF Tier I+II', '-1,080'),
                  const _Line('SHIF 2.75%', '-962'),
                  const _Line('Housing Levy 1.5%', '-525'),
                  const _Line('PAYE (after relief)', '-3,200'),
                  const _Line('HELB', '-150'),
                  const Divider(height: 18),
                  Row(
                    children: [
                      const Text(
                        'NET PAY',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const Spacer(),
                      Text(
                        'KES ${38283 - 1080 - 962 - 525 - 3200 - 150}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: DukaColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: QrImageView(
                      data: 'DUKAFLOW|PAYSLIP|2026-09|KM|VERIFIED',
                      version: QrVersions.auto,
                      size: 86,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Verified QR • viewed via web Receipt Studio',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9.5, color: DukaColors.inkMuted),
                  ),
                  const SizedBox(height: 10),
                  const _BarcodeMini(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Payslip PDF queued - will email when online'),
                ));
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export PDF'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _Line(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeMini extends StatelessWidget {
  const _BarcodeMini();

  @override
  Widget build(BuildContext context) {
    final bars = List<double>.generate(46, (i) => 1.0 + ((i * 37) % 3));
    return Column(
      children: [
        SizedBox(
          height: 26,
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
          'PAYSLIP-2026-09-KM',
          style: const TextStyle(fontSize: 9, letterSpacing: 2),
        ),
      ],
    );
  }
}
