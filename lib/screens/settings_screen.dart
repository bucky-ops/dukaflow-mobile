import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../data/hive_service.dart';
import '../data/sync_service.dart';
import '../services/biometric_service.dart';
import '../services/fcm_service.dart';
import '../services/printer_service.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'sync_center_screen.dart';

/// Settings — profile, sync center, Bluetooth printers, biometric, API
/// (DukaFlow REST + Frappe token), dark mode toggle (wireframe).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _scanning = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    BiometricService.isAvailable().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sync = ref.watch(syncProvider);
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: DukaColors.canvas,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile
          Card(
            child: ListTile(
              leading: Avatar(session.user?.name ?? 'DF'),
              title: Text(
                session.user?.name ?? 'DukaFlow Staff',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              subtitle: Text(
                '${session.user?.role ?? "Cashier"} • ${session.user?.storeName ?? "Thika Road"}',
                style: const TextStyle(fontSize: 11.5),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.logout, color: DukaColors.danger),
                onPressed: () async {
                  await ref.read(sessionProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Sync center
          Card(
            child: ListTile(
              leading: Icon(
                sync.syncing ? Icons.sync : Icons.cloud_sync_outlined,
                color: DukaColors.primary,
              ),
              title: Text(
                sync.syncing
                    ? 'Syncing to server…'
                    : '${sync.queueLength} pending sales',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              subtitle: Text(
                sync.lastSyncAt != null
                    ? 'Last synced ${fmtDate(sync.lastSyncAt!)}'
                    : 'Not synced yet this session',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: OutlinedButton(
                onPressed: sync.syncing ? null : () => ref.read(syncProvider.notifier).syncNow(),
                child: const Text('Sync Now'),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SyncCenterScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bluetooth printers
          const SectionHeader('Bluetooth Printers'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.print,
                    color: PrinterService.connected != null
                        ? DukaColors.success
                        : DukaColors.inkMuted,
                  ),
                  title: Text(
                    PrinterService.connected != null
                        ? 'EPSON TM-T20 • Connected'
                        : 'No printer connected',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: const Text(
                    '58mm / 80mm ESC-POS • QR + barcode capable',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton(
                          onPressed: () async {
                            setState(() => _scanning = true);
                            final devices = await PrinterService.scan();
                            setState(() => _scanning = false);
                            if (!mounted) return;
                            if (devices.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No bluetooth printers found — pair in system settings'),
                                ),
                              );
                              return;
                            }
                            await showModalBottomSheet<void>(
                              context: context,
                              builder: (_) => _PrinterSheet(devices: devices),
                            );
                          },
                          child: const Text('Scan'),
                        ),
                ),
                if (PrinterService.connected != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.link_off, size: 18),
                    title: const Text(
                      'Disconnect printer',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    onTap: () async {
                      await PrinterService.disconnect();
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Biometric
          if (_bioAvailable)
            Card(
              child: SwitchListTile(
                value: settings.biometric,
                onChanged: (v) async {
                  if (v) {
                    final ok = await BiometricService.authenticate(
                      reason: 'Confirm to enable biometric unlock',
                    );
                    if (!ok) return;
                  }
                  await ref.read(settingsProvider.notifier).setBiometric(v);
                },
                secondary: const Icon(Icons.fingerprint, color: DukaColors.primary),
                title: const Text(
                  'Biometric Login',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Fingerprint / Face ID to unlock POS',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),

          // Dark mode (visual toggle)
          Card(
            child: SwitchListTile(
              value: settings.darkMode,
              onChanged: (_) => ref.read(settingsProvider.notifier).toggleDark(),
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text(
                'Dark Mode',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              subtitle: const Text(
                'Light theme ships first; dark variant coming',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // API configuration
          const SectionHeader('Backend API'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: settings.baseUrl,
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    onFieldSubmitted: (v) async {
                      await ref.read(settingsProvider.notifier).setBaseUrl(v);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('API set to ${HiveService.baseUrl()}')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: settings.frappeToken,
                    decoration: const InputDecoration(
                      labelText: 'Frappe / ERPNext API token (optional)',
                      hintText: 'key:secret',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    onFieldSubmitted: (v) async {
                      await ref.read(settingsProvider.notifier).setFrappeToken(v);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Frappe token saved')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'DukaFlow REST (/api/*) is used by default. With a Frappe '
                    'token, /api/resource/* doctypes work too.',
                    style: const TextStyle(fontSize: 10.5, color: DukaColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // About + FCM state
          Card(
            child: ListTile(
              leading: Icon(
                Icons.notifications_active_outlined,
                color: FcmService.isConfigured ? DukaColors.success : DukaColors.inkMuted,
              ),
              title: const Text(
                'Push notifications (FCM)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: Text(
                FcmService.isConfigured
                    ? 'Firebase configured — alerts active'
                    : 'Add google-services.json to enable (README)',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '${AppConstants.appName} Mobile v2.4.1 • Offline-first • '
              'KRA eTIMS • M-Pesa Daraja',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: DukaColors.inkMuted),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PrinterSheet extends StatelessWidget {
  final List<dynamic> devices;

  const _PrinterSheet({required this.devices});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Bluetooth Printers',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          ...devices.map(
            (d) => ListTile(
              leading: const Icon(Icons.print),
              title: Text(
                d.name ?? 'Printer',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                d.address ?? '',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Text(
                'Connect',
                style: TextStyle(
                  color: DukaColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                final ok = await PrinterService.connect(d);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Printer connected' : 'Could not connect'),
                  ));
                }
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
