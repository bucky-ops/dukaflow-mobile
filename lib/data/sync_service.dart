import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/constants.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'hive_service.dart';

/// Offline-first sync engine.
///
/// - Sales are ALWAYS written to the Hive `pending_sales` box first.
/// - When connectivity returns (or a background job fires), the queue is
///   drained to POST /api/sales. Successful syncs move to `receipts_cache`.
/// - Conflicts (e.g. stock mismatch) are surfaced to the Sync Center screen.
abstract final class SyncService {
  static final _controller = StreamController<SyncState>.broadcast();
  static Stream<SyncState> get stream => _controller.stream;
  static SyncState _state = const SyncState();
  static StreamSubscription<List<ConnectivityResult>>? _connSub;
  static bool _syncing = false;

  static SyncState get state => _state;

  static void _push(SyncState s) {
    _state = s;
    _controller.add(s);
  }

  /// Start listening to connectivity changes (call once from main).
  static void startWatching() {
    _connSub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      _push(_state.copyWith(online: online));
      if (online && pendingCount() > 0) {
        syncPending(); // fire & forget — UI listens to state stream
      }
    });
    // seed initial state optimistically as online
    _push(_state.copyWith(online: true));
  }

  static void dispose() {
    _connSub?.cancel();
    _connSub = null;
  }

  static int pendingCount() => HiveService.pendingSales.length;

  static List<Sale> pendingSales() => HiveService.pendingSales.values
      .map((v) => Sale.fromJson(Map<String, dynamic>.from(v as Map)))
      .toList();

  static List<Sale> cachedReceipts() => HiveService.receipts.values
      .map((v) => Sale.fromJson(Map<String, dynamic>.from(v as Map)))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Persist a sale offline-first. Returns nothing — always succeeds.
  static void saveOffline(Sale sale) {
    HiveService.pendingSales.put(sale.id, sale.toJson());
    _push(_state.copyWith(queueLength: pendingCount()));
  }

  /// Drain the offline queue. Safe to call concurrently (guarded).
  static Future<SyncResult> syncPending() async {
    if (_syncing) return const SyncResult(ok: 0, failed: 0, conflict: []);
    _syncing = true;
    _push(_state.copyWith(syncing: true));
    var ok = 0, failed = 0;
    final conflicts = <SyncConflict>[];
    try {
      final sales = pendingSales();
      for (final sale in sales) {
        try {
          final res = await Api.createSale(sale.toSyncPayload());
          final serverNo =
              res['sale']?['receiptNo']?.toString() ?? res['receiptNo']?.toString();
          HiveService.receipts.put(
            sale.id,
            sale.copyWith(
              synced: true,
              syncedAt: DateTime.now().toIso8601String(),
              serverReceiptNo: serverNo,
            ).toJson(),
          );
          HiveService.pendingSales.delete(sale.id);
          ok++;
        } on Exception catch (e) {
          final msg = e.toString();
          if (msg.contains('stock') || msg.contains('Stock')) {
            conflicts.add(SyncConflict(
              saleId: sale.id,
              receiptNo: sale.displayNo,
              detail: msg,
            ));
            failed++;
          } else {
            failed++; // keep in queue for retry
          }
        }
      }
    } finally {
      _syncing = false;
      _push(SyncState(
        online: _state.online,
        syncing: false,
        queueLength: pendingCount(),
        lastSyncAt: DateTime.now(),
        conflicts: conflicts.isEmpty ? _state.conflicts : conflicts,
      ));
    }
    return SyncResult(ok: ok, failed: failed, conflict: conflicts);
  }

  /// Manual "Sync Now" from UI.
  static Future<void> syncNow() => syncPending();

  /// Background entry point (workmanager top-level callback).
  static Future<SyncResult> backgroundSync() => syncPending();
}

class SyncState {
  final bool online;
  final bool syncing;
  final int queueLength;
  final DateTime? lastSyncAt;
  final List<SyncConflict> conflicts;

  const SyncState({
    this.online = true,
    this.syncing = false,
    this.queueLength = 0,
    this.lastSyncAt,
    this.conflicts = const [],
  });

  SyncState copyWith({
    bool? online,
    bool? syncing,
    int? queueLength,
    DateTime? lastSyncAt,
    List<SyncConflict>? conflicts,
  }) =>
      SyncState(
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
        queueLength: queueLength ?? this.queueLength,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        conflicts: conflicts ?? this.conflicts,
      );
}

class SyncConflict {
  final String saleId;
  final String receiptNo;
  final String detail;

  const SyncConflict({
    required this.saleId,
    required this.receiptNo,
    required this.detail,
  });
}

class SyncResult {
  final int ok;
  final int failed;
  final List<SyncConflict> conflict;

  const SyncResult({required this.ok, required this.failed, required this.conflict});
}
