import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/api_client.dart';
import '../data/hive_service.dart';
import '../data/sync_service.dart';
import '../models/models.dart';

// -----------------------------------------------------------------
// Auth / session
// -----------------------------------------------------------------

class SessionState {
  final bool loading;
  final StaffUser? user;
  final String? error;

  const SessionState({this.loading = false, this.user, this.error});
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(SessionState(user: _restore()));

  static StaffUser? _restore() {
    final s = HiveService.session();
    if (s == null) return null;
    return StaffUser(
      id: 0,
      name: s.name,
      role: s.role,
      storeName: s.storeName,
    );
  }

  bool get isLoggedIn => state.user != null;

  /// Biometric unlock path - restore the locally saved session (no PIN).
  Future<void> restore() async {
    final user = _restore();
    if (user != null) {
      state = SessionState(user: user);
      unawaited(bootstrapCaches());
    }
  }

  Future<void> loginWithPin(String pin) async {
    state = SessionState(loading: true, user: state.user);
    try {
      final user = await Api.login(pin);
      final staff = StaffUser.fromJson(user);
      await HiveService.setSession(StaffSession(
        name: staff.name,
        role: staff.role,
        storeName: staff.storeName,
      ));
      state = SessionState(user: staff);
      unawaited(bootstrapCaches());
    } on Exception catch (e) {
      // OFFLINE fallback: allow known cached session PIN-less? No -
      // require server except when a previous session exists on device.
      final cached = HiveService.session();
      if (cached != null) {
        state = SessionState(
          user: _restore(),
          error: 'Offline - unlocked with saved session',
        );
      } else {
        state = SessionState(error: e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> logout() async {
    await HiveService.clearSession();
    state = const SessionState();
  }

  /// Pull products + customers into Hive for full offline operation.
  Future<void> bootstrapCaches() async {
    try {
      final prods = await Api.products();
      await HiveService.products.clear();
      for (final p in prods) {
        final map = Map<String, dynamic>.from(p as Map);
        HiveService.products.put(map['id'], map);
      }
    } on Exception {
      // offline - keep cached
    }
    try {
      final custs = await Api.customers();
      await HiveService.customers.clear();
      for (final c in custs) {
        final map = Map<String, dynamic>.from(c as Map);
        HiveService.customers.put(map['id'], map);
      }
    } on Exception {
      // offline - keep cached
    }
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) => SessionNotifier());

// -----------------------------------------------------------------
// Sync state → reactive for UI
// -----------------------------------------------------------------

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(SyncService.state) {
    _sub = SyncService.stream.listen((s) => state = s);
    state = state.copyWith(queueLength: SyncService.pendingCount());
  }

  StreamSubscription<SyncState>? _sub;

  Future<void> syncNow() async {
    await SyncService.syncNow();
    state = SyncService.state;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) => SyncNotifier());

// -----------------------------------------------------------------
// Products (Hive cache first, refresh from API)
// -----------------------------------------------------------------

class ProductsState {
  final List<Product> items;
  final bool loading;

  const ProductsState({this.items = const [], this.loading = false});
}

class ProductsNotifier extends StateNotifier<ProductsState> {
  ProductsNotifier() : super(const ProductsState()) {
    _loadFromCache();
  }

  void _loadFromCache() {
    final cached = HiveService.products.values
        .map((v) => Product.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    if (cached.isNotEmpty) state = ProductsState(items: cached);
  }

  Future<void> refresh() async {
    state = ProductsState(items: state.items, loading: true);
    try {
      final prods = await Api.products();
      await HiveService.products.clear();
      for (final p in prods) {
        final map = Map<String, dynamic>.from(p as Map);
        await HiveService.products.put(map['id'], map);
      }
      _loadFromCache();
      state = ProductsState(items: _all());
    } on Exception {
      state = ProductsState(items: _all());
    }
  }

  List<Product> _all() => HiveService.products.values
      .map((v) => Product.fromJson(Map<String, dynamic>.from(v as Map)))
      .toList();

  Product? byBarcode(String code) {
    final q = code.trim();
    for (final p in state.items) {
      if (p.barcode == q || p.sku.toUpperCase() == q.toUpperCase()) return p;
    }
    return null;
  }
}

final productsProvider =
    StateNotifierProvider<ProductsNotifier, ProductsState>((ref) => ProductsNotifier());

// -----------------------------------------------------------------
// Cart
// -----------------------------------------------------------------

class CartState {
  final List<CartLine> lines;
  final Customer? customer;
  final bool redeemLoyalty;
  final double extraDiscount;
  final int loyaltyRedeemedPts;

  const CartState({
    this.lines = const [],
    this.customer,
    this.redeemLoyalty = false,
    this.extraDiscount = 0,
    this.loyaltyRedeemedPts = 0,
  });

  CartTotals get totals =>
      CartTotals.compute(lines, extraDiscount + (redeemLoyalty ? loyaltyRedeemedPts : 0));

  double get count => lines.fold(0, (s, l) => s + l.qty);

  int get earnedPoints => (totals.total / AppConstants.loyaltyEarnPerKes).floor();

  CartState copyWith({
    List<CartLine>? lines,
    Customer? customer,
    bool clearCustomer = false,
    bool? redeemLoyalty,
    double? extraDiscount,
    int? loyaltyRedeemedPts,
  }) =>
      CartState(
        lines: lines ?? this.lines,
        customer: clearCustomer ? null : (customer ?? this.customer),
        redeemLoyalty: redeemLoyalty ?? this.redeemLoyalty,
        extraDiscount: extraDiscount ?? this.extraDiscount,
        loyaltyRedeemedPts: loyaltyRedeemedPts ?? this.loyaltyRedeemedPts,
      );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void add(Product p, {double qty = 1}) {
    final idx = state.lines.indexWhere((l) => l.product.id == p.id);
    if (idx >= 0) {
      final lines = [...state.lines];
      lines[idx] = lines[idx].copyWith(qty: lines[idx].qty + qty);
      state = state.copyWith(lines: lines);
    } else {
      state = state.copyWith(lines: [...state.lines, CartLine(product: p, qty: qty)]);
    }
  }

  void setQty(Product p, double qty) {
    if (qty <= 0) {
      remove(p);
      return;
    }
    final lines = [...state.lines];
    final idx = lines.indexWhere((l) => l.product.id == p.id);
    if (idx >= 0) lines[idx] = lines[idx].copyWith(qty: qty);
    state = state.copyWith(lines: lines);
  }

  void remove(Product p) => state = state.copyWith(
        lines: state.lines.where((l) => l.product.id != p.id).toList(),
      );

  void setCustomer(Customer? c) {
    state = state.copyWith(
      clearCustomer: c == null,
      customer: c,
      loyaltyRedeemedPts: c != null ? c.loyaltyPoints : 0,
    );
    if (c == null) state = state.copyWith(redeemLoyalty: false);
  }

  void toggleRedeem() {
    final can = (state.customer?.loyaltyPoints ?? 0) > 0;
    if (!can) return;
    state = state.copyWith(redeemLoyalty: !state.redeemLoyalty);
  }

  void setExtraDiscount(double v) => state = state.copyWith(extraDiscount: v);

  void clear() => state = const CartState();
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

// -----------------------------------------------------------------
// Sales history (pending + synced)
// -----------------------------------------------------------------

class HistoryNotifier extends StateNotifier<List<Sale>> {
  HistoryNotifier() : super(const []) {
    reload();
  }

  void reload() {
    final pending = SyncService.pendingSales();
    final synced = SyncService.cachedReceipts();
    state = [...pending, ...synced]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<Sale>>((ref) => HistoryNotifier());

// -----------------------------------------------------------------
// Customers
// -----------------------------------------------------------------

class CustomersNotifier extends StateNotifier<List<Customer>> {
  CustomersNotifier() : super(const []) {
    _loadFromCache();
    refresh();
  }

  void _loadFromCache() {
    state = HiveService.customers.values
        .map((v) => Customer.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  Future<void> refresh() async {
    try {
      final custs = await Api.customers();
      await HiveService.customers.clear();
      for (final c in custs) {
        final map = Map<String, dynamic>.from(c as Map);
        await HiveService.customers.put(map['id'], map);
      }
      _loadFromCache();
    } on Exception {
      // offline - cache is already loaded
    }
  }

  List<Customer> search(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return state;
    return state
        .where((c) =>
            c.name.toLowerCase().contains(query) ||
            c.phone.replaceAll(' ', '').contains(query.replaceAll(' ', '')))
        .toList();
  }
}

final customersProvider =
    StateNotifierProvider<CustomersNotifier, List<Customer>>((ref) => CustomersNotifier());

// -----------------------------------------------------------------
// Debts
// -----------------------------------------------------------------

final debtPlansProvider = FutureProvider<List<DebtPlan>>((ref) async {
  try {
    final raw = await Api.debtPlans();
    return raw.map((d) => DebtPlan.fromJson(Map<String, dynamic>.from(d as Map))).toList();
  } on Exception {
    return const [];
  }
});

// -----------------------------------------------------------------
// Dashboard
// -----------------------------------------------------------------

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  try {
    final d = await Api.dashboard();
    final today = d['today'] as Map?;
    final week = d['week'] as Map?;
    final lowStock = ((d['lowStock'] as Map?)?['count'] as num?)?.toInt() ?? 0;
    return DashboardData(
      todaySales: ((today?['total'] ?? today?['sales'] ?? 0) as num).toDouble(),
      todayCount: ((today?['count'] ?? 0) as num).toInt(),
      weekSales: ((week?['total'] ?? 0) as num).toDouble(),
      debtOutstanding: ((d['debts'] as Map?)?['outstanding'] as num?)?.toDouble() ?? 0,
      lowStock: lowStock,
      stockValue: ((d['stock'] as Map?)?['value'] as num?)?.toDouble() ?? 0,
    );
  } on Exception {
    return DashboardData.empty;
  }
});

// -----------------------------------------------------------------
// Settings
// -----------------------------------------------------------------

class SettingsState {
  final String baseUrl;
  final String? frappeToken;
  final bool biometric;
  final bool darkMode;

  const SettingsState({
    this.baseUrl = AppConstants.defaultBaseUrl,
    this.frappeToken,
    this.biometric = false,
    this.darkMode = false,
  });
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
      : super(SettingsState(
          baseUrl: HiveService.baseUrl(),
          frappeToken: HiveService.frappeToken(),
          biometric: HiveService.biometricEnabled(),
        ));

  Future<void> setBaseUrl(String v) async {
    await HiveService.setBaseUrl(v.trim());
    Api.reset();
    state = SettingsState(
      baseUrl: HiveService.baseUrl(),
      frappeToken: state.frappeToken,
      biometric: state.biometric,
      darkMode: state.darkMode,
    );
  }

  Future<void> setFrappeToken(String? v) async {
    await HiveService.setFrappeToken(v);
    Api.reset();
    state = SettingsState(
      baseUrl: state.baseUrl,
      frappeToken: HiveService.frappeToken(),
      biometric: state.biometric,
      darkMode: state.darkMode,
    );
  }

  Future<void> setBiometric(bool v) async {
    await HiveService.setBiometric(v);
    state = SettingsState(
      baseUrl: state.baseUrl,
      frappeToken: state.frappeToken,
      biometric: HiveService.biometricEnabled(),
      darkMode: state.darkMode,
    );
  }

  void toggleDark() =>
      state = SettingsState(
        baseUrl: state.baseUrl,
        frappeToken: state.frappeToken,
        biometric: state.biometric,
        darkMode: !state.darkMode,
      );
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) => SettingsNotifier());
