# DukaFlow Mobile 📱

**Kenya's offline-first retail POS - one Flutter codebase → Android APK + iOS IPA.**

> Your Duka in Your Pocket. Works 100% without internet - sales save locally in Hive,
> then sync automatically when connectivity returns. KRA eTIMS receipts, M-Pesa STK,
> Bluetooth thermal printing, barcode scanning, loyalty, biometric unlock.

![Flutter](https://img.shields.io/badge/Flutter-3.22-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.4-0175C2?logo=dart)
![CI](https://github.com/bucky-ops/dukaflow-mobile/actions/workflows/android.yml/badge.svg)

## Live Wireframe Preview

▶ [Open the interactive wireframe preview](https://bucky-ops.github.io/dukaflow-mobile/) - this is the interactive 15-screen mobile wireframe that the Flutter app implements.

---

## Screens (15 + bonus)

| # | Screen | Highlights |
|---|--------|-----------|
| 1 | Splash | Brand launch, auto biometric path |
| 2 | Login | Phone + 4-digit PIN, **Biometric Login** (fingerprint/Face ID), offline session unlock |
| 3 | Dashboard | KPIs, Quick Actions grid, **Live Sales Feed** |
| 4 | POS / Sell | Product grid, category chips, search, low-stock chips, cart FAB |
| 5 | Barcode Scanner | `mobile_scanner` - EAN/Code128/QR, adds to cart instantly |
| 6 | Cart | Qty steppers, **customer search by phone**, **loyalty toggle** ("Use 300 pts = KES 300"), bill discount, VAT 16% |
| 7 | Payment | Cash (tendered/change), **M-Pesa STK**, Card, Credit Sale |
| 8 | M-Pesa STK Status | "Awaiting customer PIN…" pulse, graceful offline degradation |
| 9 | Receipt | 80mm thermal mock, **KRA eTIMS QR**, Code128 barcode, **Bluetooth print**, WhatsApp share |
| 10 | Sales History | Merged pending + synced receipts, status filter |
| 11 | Customers | Phone-first search, tier badges, debtor counts |
| 12 | Customer Detail | Loyalty/debt/credit KPIs, M-Pesa payment request |
| 13 | Debts | Installment plans, overdue flags, collect via STK |
| 14 | Inventory | Stock levels + wireframe **Stock Transfer** composer |
| 15 | Settings | Sync center, Bluetooth printers, biometric toggle, **API base URL + Frappe token**, FCM state |
| ➕ | Payslip (+detail) | MY PAYSLIP with NSSF/SHIF/Housing/PAYE + Verified QR |
| ➕ | Sync Center | Queue progress bar, pending sales, **conflict resolution** |
| ➕ | Reports | 7-day sales bars, payment mix |

## Offline-First Architecture

```
POS sale --► Hive box `pending_sales` (ALWAYS, first write)
                │
                ├- online? --► instant sync --► POST /api/sales --► move to `receipts_cache`
                │
                └- offline --► connectivity_plus listener / workmanager
                               periodic job (15 min) drains queue automatically
```

- **Local DB**: Hive boxes - `pending_sales`, `products_cache`, `customers_cache`,
  `receipts_cache`, `settings`
- **Background job**: `workmanager` periodic task (`dukaflow.sync`, every 15 min, needs network)
- **Conflicts**: stock mismatches are surfaced in Sync Center with a Resolve action
- **Receipts never wait on the network** - the sale is safe on-device the moment you tap Complete

## Stack

| Concern | Choice |
|---------|--------|
| Framework | Flutter 3.22 (stable), Dart 3.4 |
| State | flutter_riverpod (StateNotifier) |
| Local DB | Hive + hive_flutter |
| API | Dio (interceptor-injected base URL + Frappe token) |
| Scanner | mobile_scanner |
| Thermal print | esc_pos_utils (ESC/POS builder) + bluetooth_print (transport) |
| Biometric | local_auth (FlutterFragmentActivity host) |
| Push | firebase_core + firebase_messaging (graceful no-op until configured) |
| Sync | connectivity_plus + workmanager |

## Backend

Default base URL: `https://api.dukaflow.site` (change in **Settings → Backend API**).

DukaFlow REST (default):
- `POST /api/auth/login` `{pin}` → staff session
- `GET /api/products` / `GET /api/customers` / `GET /api/debt-plans` / `GET /api/dashboard`
- `POST /api/sales` - sync payload `{clientId, items[], paymentMethod, totals…}`
- `POST /api/mpesa/stk` - Daraja STK push `{phone, amount, ref}`

Frappe / ERPNext compatibility: set a **Frappe API token** in Settings and
`/api/resource/<DocType>` list reads work through the same client
(e.g. `frappeList('Sales Invoice')`).

## Build & Deploy (free)

**Android APK - GitHub Actions (automatic)**
- Every push to `main` runs `.github/workflows/android.yml`
  → Flutter 3.22.3 + Java 17 → `flutter build apk --release` (fat + split-per-ABI)
  → artifacts attached to the run; **tag `v*` publishes a GitHub Release with APKs**

```bash
git tag v1.1.0 && git push origin v1.1.0   # → release with APKs
```

**iOS IPA - Codemagic (free 500 min/month)**
- `codemagic.yaml` included: bootstraps the iOS Runner (`flutter create . --platforms ios`),
  builds an unsigned IPA; add an App Store Connect API key for signed builds

**Code-push style updates**: pair with [Shorebird](https://shorebird.dev) for instant Dart patches.

## Push Notifications (FCM)

Firebase config is **intentionally not committed** (no secrets in git). To enable:

1. Create a Firebase project → add Android app `site.dukaflow.mobile`
2. Drop `google-services.json` into `android/app/` and add the
   google-services Gradle plugin
3. For iOS, drop `GoogleService-Info.plist` into the Runner
4. Rebuild - `FcmService` lights up automatically (the Settings screen shows the state)

## Getting Started (local dev)

```bash
git clone https://github.com/bucky-ops/dukaflow-mobile.git
cd dukaflow-mobile
flutter pub get
flutter run                      # or: flutter run --dart-define=API_URL=https://api.dukaflow.site
flutter build apk --release
```

Demo PINs (matching the web app): **Cashier `1234` • Owner `0000`**

## Project Layout

```
lib/
├-- core/          theme (DukaFlow tokens #0052CC/#00C853/#172B4D), constants, utils
├-- models/        Product, CartLine, Sale, Customer, DebtPlan… (JSON-map serializable)
├-- data/          hive_service, api_client (Dio), sync_service (offline queue engine)
├-- services/      biometric, mpesa (STK), printer (ESC/POS+BT), fcm
├-- state/         riverpod providers (session, cart, sync, products…)
├-- screens/       15 wireframe screens + payslip detail / sync center
└-- widgets/       KpiCard, StatusChip, TierBadge, EmptyState, OfflineBanner…
```

## Roadmap

- [ ] Dark theme full variant (toggle scaffolded in Settings)
- [ ] Cash drawer kick via bluetooth
- [ ] Africa's Talking SMS from the device
- [ ] Google Maps delivery routing
- [ ] Shorebird code-push pipeline

## License

MIT - see [LICENSE](LICENSE).
