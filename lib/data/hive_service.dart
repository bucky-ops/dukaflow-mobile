import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants.dart';

/// Hive bootstrap. All data is stored as JSON maps — no codegen adapters.
abstract final class HiveService {
  static late Box settings;
  static late Box products;
  static late Box customers;
  static late Box pendingSales; // offline queue: unsynced sales
  static late Box receipts; // cached synced sales for history

  static Future<void> init() async {
    await Hive.initFlutter();
    settings = await Hive.openBox(AppConstants.settingsBox);
    products = await Hive.openBox(AppConstants.productsBox);
    customers = await Hive.openBox(AppConstants.customersBox);
    pendingSales = await Hive.openBox(AppConstants.pendingSalesBox);
    receipts = await Hive.openBox(AppConstants.receiptsBox);
  }

  // ── settings box helpers ─────────────────────────────────────
  static String baseUrl() =>
      (settings.get('baseUrl') as String?) ?? AppConstants.defaultBaseUrl;

  static Future<void> setBaseUrl(String v) => settings.put('baseUrl', v);

  static String? frappeToken() => settings.get('frappeToken') as String?;

  static Future<void> setFrappeToken(String? v) async =>
      v == null || v.isEmpty ? settings.delete('frappeToken') : settings.put('frappeToken', v);

  static bool biometricEnabled() => (settings.get('biometric') as bool?) ?? false;

  static Future<void> setBiometric(bool v) => settings.put('biometric', v);

  static StaffSession? session() {
    final raw = settings.get('session');
    if (raw is! Map) return null;
    final name = raw['name'] as String?;
    if (name == null) return null;
    return StaffSession(
      name: name,
      role: (raw['role'] as String?) ?? 'Cashier',
      storeName: raw['storeName'] as String?,
    );
  }

  static Future<void> setSession(StaffSession s) => settings.put('session', {
        'name': s.name,
        'role': s.role,
        'storeName': s.storeName,
      });

  static Future<void> clearSession() => settings.delete('session');

  static String nextOfflineReceiptNo() {
    final n = ((settings.get('offlineSeq') as num?)?.toInt() ?? 0) + 1;
    settings.put('offlineSeq', n);
    return 'MOB-${DateTime.now().year}-${n.toString().padStart(4, '0')}';
  }
}

class StaffSession {
  final String name;
  final String role;
  final String? storeName;

  const StaffSession({required this.name, required this.role, this.storeName});
}
