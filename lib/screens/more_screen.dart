import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'debts_screen.dart';
import 'inventory_screen.dart';
import 'payslip_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'sync_center_screen.dart';

/// More — grid of the remaining screens (wireframe covers these as tabs).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.inventory_outlined, 'Inventory', const InventoryScreen()),
      (Icons.credit_score_outlined, 'Debts', const DebtsScreen()),
      (Icons.badge_outlined, 'My Payslip', const PayslipScreen()),
      (Icons.insights, 'Reports', const ReportsScreen()),
      (Icons.cloud_sync_outlined, 'Sync Center', const SyncCenterScreen()),
      (Icons.settings_outlined, 'Settings', const SettingsScreen()),
    ];

    return Scaffold(
      backgroundColor: DukaColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('More'),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (final (icon, label, screen) in items)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => screen),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DukaColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: DukaColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
