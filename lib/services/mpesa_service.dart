import '../data/api_client.dart';

/// M-Pesa STK (Lipa na M-Pesa — Push) via the backend Daraja integration.
///
/// Flow: app → POST /api/mpesa/stk → backend talks to Safaricom Daraja →
/// STK prompt lands on the customer's phone → backend receives the callback.
/// Offline or on failure the sale still saves locally and syncs later.
abstract final class MpesaService {
  static StkResult _last = const StkResult(status: StkStatus.idle);

  static StkResult get last => _last;

  /// Trigger the STK push. Never throws — errors become a failed StkResult
  /// so the UI can degrade gracefully to offline mode.
  static Future<StkResult> push({
    required String phone,
    required double amount,
    required String receiptNo,
  }) async {
    _last = const StkResult(status: StkStatus.pushing);
    try {
      final res = await Api.mpesaStk(
        phone: _normalize(phone),
        amount: amount,
        ref: receiptNo,
      );
      // Backend contract: {ok: true, checkoutRequestId | message} on queued
      final ok = res['ok'] == true || res['ResponseCode'] == '0';
      if (ok) {
        final reqId = (res['checkoutRequestId'] ??
                res['CheckoutRequestID'] ??
                res['message'] ??
                '')
            .toString();
        _last = StkResult(status: StkStatus.awaitingPin, checkoutId: reqId);
      } else {
        _last = StkResult(
          status: StkStatus.failed,
          error: (res['error'] ?? res['errorMessage'] ?? 'STK rejected').toString(),
        );
      }
    } on Exception catch (e) {
      _last = StkResult(status: StkStatus.offline, error: e.toString());
    }
    return _last;
  }

  static void reset() => _last = const StkResult(status: StkStatus.idle);

  /// Accept 07xx / 01xx / +2547xx / 2547xx formats → 2547XXXXXXXX.
  static String _normalize(String raw) {
    var p = raw.replaceAll(RegExp(r'\s+'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('0')) p = '254${p.substring(1)}';
    return p;
  }
}

enum StkStatus { idle, pushing, awaitingPin, confirmed, failed, offline }

class StkResult {
  final StkStatus status;
  final String checkoutId;
  final String error;

  const StkResult({required this.status, this.checkoutId = '', this.error = ''});

  String get message => switch (status) {
        StkStatus.idle => 'Ready',
        StkStatus.pushing => 'Sending STK push…',
        StkStatus.awaitingPin => 'Awaiting customer PIN…',
        StkStatus.confirmed => 'M-Pesa confirmed',
        StkStatus.failed => error,
        StkStatus.offline => 'Offline — sale saved, M-Pesa pending',
      };
}
