import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import 'payslip_detail_screen.dart';

/// Payslip summary card (wireframe) — staff see their net pay + detail.
class PayslipScreen extends StatelessWidget {
  const PayslipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const net = 25400.0;
    final month = DateTime.now().month;
    final name = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'][month - 1];

    return Scaffold(
      backgroundColor: DukaColors.canvas,
      appBar: AppBar(title: const Text('My Payslip')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const StatusChip('VERIFIED', DukaColors.success),
                  const SizedBox(height: 8),
                  Text(
                    'MY PAYSLIP • $name',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: DukaColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kes(net),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: DukaColors.ink,
                    ),
                  ),
                  const Text(
                    'Net Pay • Kamau Maina • Cashier',
                    style: TextStyle(fontSize: 12, color: DukaColors.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const PayslipDetailScreen()),
                      ),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('View Payslip'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Statutory deductions applied'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                children: [
                  _Row('NSSF Tier I+II', 'KES 1,080'),
                  _Row('SHIF 2.75%', 'KES 962'),
                  _Row('Housing Levy 1.5%', 'KES 525'),
                  _Row('PAYE (after relief)', 'KES 3,200'),
                  Divider(),
                  _Row('Net to M-Pesa 0712 ••• 678', 'KES 25,400', bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: bold ? DukaColors.primary : DukaColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
