import 'package:dio/dio.dart';

import '../core/constants.dart';
import 'hive_service.dart';

/// DukaFlow REST client.
///
/// Talks to the DukaFlow backend (default https://api.dukaflow.site).
/// The same client also speaks Frappe/ERPNext-style APIs: when a Frappe
/// API token is configured (Settings), requests carry
/// `Authorization: token <key>:<secret>` and `/api/resource/...` routes work.
abstract final class Api {
  static Dio? _dio;

  static Dio get dio {
    final d = _dio;
    if (d != null) return d;
    final fresh = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    fresh.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = HiveService.baseUrl();
          final token = HiveService.frappeToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'token $token';
          }
          handler.next(options);
        },
      ),
    );
    _dio = fresh;
    return fresh;
  }

  /// Call after changing the base URL / token in Settings.
  static void reset() {
    _dio?.close();
    _dio = null;
  }

  static DioException _wrap(DioException e) {
    final msg = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Connection timed out',
      DioExceptionType.connectionError => 'No connection to server',
      _ => e.response?.data is Map && e.response?.data['error'] != null
          ? e.response!.data['error'].toString()
          : 'Network error',
    };
    return DioException(
      requestOptions: e.requestOptions,
      type: e.type,
      error: msg,
      response: e.response,
    );
  }

  // -- Generic verbs ----------------------------------------------
  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await dio.get(path, queryParameters: query);
      return r.data;
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  static Future<dynamic> post(String path, {Object? body}) async {
    try {
      final r = await dio.post(path, data: body);
      return r.data;
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  // -- DukaFlow API (matches the web app routes) ------------------
  static Future<Map<String, dynamic>> login(String pin) async {
    final data = await post('/api/auth/login', body: {'pin': pin});
    if (data is Map && data['ok'] == true) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }
    throw Exception(data is Map ? data['error'] ?? 'Invalid PIN' : 'Login failed');
  }

  static Future<List<dynamic>> products({int limit = 200}) async =>
      ((await get('/api/products', query: {'limit': limit})) as List?) ?? [];

  static Future<List<dynamic>> customers({int limit = 200}) async =>
      ((await get('/api/customers', query: {'limit': limit})) as List?) ?? [];

  static Future<List<dynamic>> debtPlans() async =>
      ((await get('/api/debt-plans')) as List?) ?? [];

  static Future<Map<String, dynamic>> dashboard() async {
    final data = await get('/api/dashboard');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<Map<String, dynamic>> createSale(Map<String, dynamic> payload) async {
    final data = await post('/api/sales', body: payload);
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  /// M-Pesa STK push via backend Daraja integration.
  static Future<Map<String, dynamic>> mpesaStk({
    required String phone,
    required double amount,
    required String ref,
  }) async {
    final data = await post('/api/mpesa/stk', body: {
      'phone': phone,
      'amount': amount.round(),
      'ref': ref,
      'description': 'DukaFlow payment $ref',
    });
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  // -- Frappe/ERPNext style (when backend is ERPNext) ------------
  static Future<List<dynamic>> frappeList(String doctype, {Map<String, dynamic>? filters}) async {
    final data = await get(
      '/api/resource/$doctype',
      query: {
        'limit_page_length': 200,
        if (filters != null) 'filters': filters,
      },
    );
    return (data is Map ? data['data'] as List? : data as List?) ?? [];
  }
}
