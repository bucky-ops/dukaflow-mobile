import 'dart:typed_data';

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

/// Bluetooth thermal printer (58mm / 80mm) with ESC/POS + QR support.
abstract final class PrinterService {
  static final BluetoothPrint _bluetooth = BluetoothPrint.instance;
  static List<BluetoothDevice> _devices = [];
  static BluetoothDevice? connected;
  static bool scanning = false;

  static List<BluetoothDevice> get devices => _devices;

  /// Scan for paired/nearby bluetooth printers.
  static Future<List<BluetoothDevice>> scan() async {
    scanning = true;
    _devices = [];
    try {
      final results = <BluetoothDevice>[];
      final sub = _bluetooth.scanResults.listen((list) {
        results
          ..clear()
          ..addAll(list);
      });
      await _bluetooth.startScan(timeout: const Duration(seconds: 4));
      await Future<void>.delayed(const Duration(seconds: 5));
      await _bluetooth.stopScan();
      await sub.cancel();
      _devices = results;
    } on Exception {
      _devices = [];
    }
    scanning = false;
    return _devices;
  }

  static Future<bool> connect(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device);
      connected = device;
      return true;
    } on Exception {
      connected = null;
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
    } on Exception {
      // ignore
    }
    connected = null;
  }

  /// Build ESC/POS bytes for a receipt (80mm default).
  static Future<Uint8List> buildReceiptBytes({
    required String storeName,
    required String storeSub,
    required String kraPin,
    required String receiptNo,
    required String cashier,
    required String? customerLine,
    required List<(String, double)> items,
    required double subtotal,
    required double discount,
    required double vat,
    required double total,
    required String paymentLine,
    required String? loyaltyLine,
    required String? cuInvoice,
    required DateTime when,
    bool mm80 = true,
  }) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(mm80 ? PaperSize.mm80 : PaperSize.mm58, profile);
    final bytes = <int>[];

    bytes.addAll(gen.text(
      'DUKAFLOW LTD',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));
    bytes.addAll(gen.text(storeSub, styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(gen.text('PIN: $kraPin', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(gen.hr(ch: '=', linesAfter: 1));
    bytes.addAll(gen.text('RECEIPT • $receiptNo', styles: const PosStyles(bold: true)));
    bytes.addAll(gen.text(
      'Date: ${when.day}/${when.month}/${when.year} • Cashier: $cashier',
    ));
    if (customerLine != null) bytes.addAll(gen.text(customerLine));
    bytes.addAll(gen.hr());
    for (final (name, amount) in items) {
      bytes.addAll(gen.text(name, styles: const PosStyles(bold: true)));
      bytes.addAll(gen.row([
        PosColumn(text: '', width: 6),
        PosColumn(
          text: amount.toStringAsFixed(0).padLeft(12),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    bytes.addAll(gen.hr());
    bytes.addAll(gen.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(
        text: subtotal.toStringAsFixed(0),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    if (discount > 0) {
      bytes.addAll(gen.row([
        PosColumn(text: 'Discount', width: 6),
        PosColumn(
          text: '-${discount.toStringAsFixed(0)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    bytes.addAll(gen.row([
      PosColumn(text: 'VAT 16%', width: 6),
      PosColumn(
        text: vat.toStringAsFixed(0),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(gen.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: total.toStringAsFixed(0),
        width: 6,
        styles: PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]));
    bytes.addAll(gen.hr(ch: '=', linesAfter: 1));
    bytes.addAll(gen.text(paymentLine, styles: const PosStyles(bold: true, align: PosAlign.center)));
    if (loyaltyLine != null) {
      bytes.addAll(gen.text(loyaltyLine, styles: const PosStyles(align: PosAlign.center)));
    }
    if (cuInvoice != null) {
      bytes.addAll(gen.text('CU: $cuInvoice', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(gen.text('KRA eTIMS Verified', styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(gen.feed(1));
    // QR — KRA eTIMS verification payload
    bytes.addAll(gen.qrcode('DUKAFLOW|$receiptNo|KES${total.toStringAsFixed(0)}',
        size: QRSize.Size6));
    bytes.addAll(gen.feed(1));
    // Barcode of receipt number
    bytes.addAll(gen.barcode(Barcode.code128(receiptNo.split(''))));
    bytes.addAll(gen.feed(1));
    bytes.addAll(gen.text('* Goods once sold not returnable *',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(gen.text('Powered by DukaFlow',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(gen.feed(2));
    bytes.addAll(gen.cut());
    return Uint8List.fromList(bytes);
  }

  /// Print a receipt over bluetooth using bluetooth_print LineText rows.
  /// Returns true on success.
  static Future<bool> printReceipt({
    required String storeName,
    required String storeSub,
    required String kraPin,
    required String receiptNo,
    required String cashier,
    required String? customerLine,
    required List<(String, double)> items,
    required double subtotal,
    required double discount,
    required double vat,
    required double total,
    required String paymentLine,
    required String? loyaltyLine,
    required String? cuInvoice,
    required DateTime when,
  }) async {
    final device = connected;
    if (device == null) return false;
    String right(String label, num v) =>
        '$label${'.' * (26 - label.length)}${v.toStringAsFixed(0)}';
    final lines = <LineText>[
      LineText(
        type: LineText.TYPE_TEXT,
        content: storeName,
        align: LineText.ALIGN_CENTER,
        weight: 1,
        fontZoom: 2,
      ),
      LineText(type: LineText.TYPE_TEXT, content: storeSub, align: LineText.ALIGN_CENTER),
      LineText(type: LineText.TYPE_TEXT, content: 'PIN: $kraPin', align: LineText.ALIGN_CENTER),
      LineText(type: LineText.TYPE_TEXT, content: '--------------------------------'),
      LineText(type: LineText.TYPE_TEXT, content: 'RECEIPT • $receiptNo', weight: 1),
      LineText(type: LineText.TYPE_TEXT, content: 'Date: ${fmtD(when)} • $cashier'),
      if (customerLine != null)
        LineText(type: LineText.TYPE_TEXT, content: customerLine),
      LineText(type: LineText.TYPE_TEXT, content: '--------------------------------'),
      for (final (name, amount) in items)
        LineText(type: LineText.TYPE_TEXT, content: '$name - ${amount.toStringAsFixed(0)}'),
      LineText(type: LineText.TYPE_TEXT, content: '--------------------------------'),
      LineText(type: LineText.TYPE_TEXT, content: right('Subtotal: ', subtotal)),
      if (discount > 0)
        LineText(type: LineText.TYPE_TEXT, content: right('Discount: ', -discount)),
      LineText(type: LineText.TYPE_TEXT, content: right('VAT 16%: ', vat)),
      LineText(
        type: LineText.TYPE_TEXT,
        content: right('TOTAL KES ', total),
        weight: 1,
        fontZoom: 2,
      ),
      LineText(type: LineText.TYPE_TEXT, content: paymentLine, align: LineText.ALIGN_CENTER, weight: 1),
      if (loyaltyLine != null)
        LineText(type: LineText.TYPE_TEXT, content: loyaltyLine, align: LineText.ALIGN_CENTER),
      if (cuInvoice != null) ...[
        LineText(type: LineText.TYPE_TEXT, content: 'CU: $cuInvoice', align: LineText.ALIGN_CENTER),
        LineText(
          type: LineText.TYPE_TEXT,
          content: 'KRA eTIMS Verified',
          align: LineText.ALIGN_CENTER,
          weight: 1,
        ),
      ],
      LineText(
        type: LineText.TYPE_QRCODE,
        content: 'DUKAFLOW|$receiptNo|KES${total.toStringAsFixed(0)}',
        size: 6,
        align: LineText.ALIGN_CENTER,
      ),
      LineText(
        type: LineText.TYPE_BARCODE,
        content: receiptNo,
        align: LineText.ALIGN_CENTER,
      ),
      LineText(
        type: LineText.TYPE_TEXT,
        content: '* Goods once sold not returnable *',
        align: LineText.ALIGN_CENTER,
      ),
      LineText(
        type: LineText.TYPE_TEXT,
        content: 'Powered by DukaFlow',
        align: LineText.ALIGN_CENTER,
      ),
    ];
    try {
      await _bluetooth.printReceipt(
        <String, dynamic>{'width': 80, 'height': 100, 'gap': 2},
        lines,
      );
      return true;
    } on Exception {
      return false;
    }
  }
}

String fmtD(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
