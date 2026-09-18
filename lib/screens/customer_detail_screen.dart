import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

/// Customer detail — loyalty, debt, credit limit, quick M-Pesa debt request.
class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Avatar(c.name, size: 56),
                  const SizedBox(height: 8),
                  Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.phone,
                    style: const TextStyle(fontSize: 12, color: DukaColors.inkMuted),
                  ),
                  const SizedBox(height: 6),
                  TierBadge(c.tier),
                  Text(
                    ' • ${c.loyaltyPoints} pts',
                    style: const TextStyle(fontSize: 12, color: DukaColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  label: 'Loyalty points',
                  value: '${c.loyaltyPoints}',
                  icon: Icons.stars,
                  color: DukaColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: KpiCard(
                  label: 'Debt balance',
                  value: kes(c.debtBalance, compact: true),
                  icon: Icons.credit_score,
                  color: c.debtBalance > 0 ? DukaColors.warning : DukaColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  label: 'Credit limit',
                  value: kes(c.creditLimit, compact: true),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: KpiCard(
                  label: 'Lifetime spent',
                  value: kes(c.totalSpent, compact: true),
                  icon: Icons.trending_up,
                  color: DukaColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (c.giftCardBalance > 0)
            Card(
              child: ListTile(
                leading: const Icon(Icons.card_giftcard, color: DukaColors.success),
                title: const Text(
                  'Gift card balance',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                trailing: Text(
                  kes(c.giftCardBalance),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  'M-Pesa request of ${kes(1000)} sent to ${c.phone} • awaiting PIN',
                ),
              ));
            },
            icon: const Icon(Icons.phone_android),
            label: const Text('Request M-Pesa payment'),
          ),
        ],
      ),
    );
  }
}
