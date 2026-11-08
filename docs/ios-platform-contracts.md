# iOS platform contract plan

This is an interface-only boundary proposal for the shared Kotlin Multiplatform module. It does not contain platform implementations and does not move Android business logic. The iOS choices below are the intended adapter technologies for a later migration phase.

| commonMain interface | iOS adapter technology | Status / notes |
|---|---|---|
| PdfEngine | **PDFKit** + Core Graphics | Implemented in iosMain. PDFDocument/PDFPage provide page count, text extraction, PNG page rendering and selected-page export. This initial slice does not claim advanced editing parity. |
| OcrEngine | **Vision** | VNRecognizeTextRequest; use Vision language correction and recognition-level settings in the future adapter. |
| Translator | **Google ML Kit for iOS (Translate)** | On-device Translation API; language-specific models are downloaded and managed on-device. ML Kit's published iOS prerequisites are iOS 15.5+ and 64-bit architecture, so the app's iOS 16.0 floor satisfies this requirement. |
| BillingProvider | **StoreKit 2** | Product, verified Transaction, Transaction.currentEntitlements, and AppStore.sync for purchase and restore state. |
| AdProvider | **Google Mobile Ads SDK for iOS (AdMob)** | Implemented by AdMobProvider.swift through Swift Package Manager. The dashboard banner is suppressed while the verified Pro Pass entitlement is active. |
| FileExporter | **Foundation temporary file + SwiftUI FileDocument / fileExporter** | Implemented in iosMain as a staged local file URI; the SwiftUI host reads the staged copy and presents the system save destination picker. |

## Contract conventions

- PDF page indexes are zero-based. PdfEngine.renderPage returns PNG-encoded bytes.
- OCR and translation language identifiers are BCP-47 tags.
- BillingProvider.purchase returns true only after the platform verifies a completed entitlement; pending/cancelled flows return false. Platform failures are surfaced as exceptions.
- AdProvider.showInterstitial returns true only when presentation occurred.
- FileExporter.export returns a URI for staged export bytes, or null if staging fails. The SwiftUI host performs the user-mediated destination selection and final copy.

## Explicit non-goals for this phase

- No OCR, translation, billing or advertising implementations are included.
- No Android implementation relocation or business-logic migration.
- The PDF implementation is an initial import, inspect, render, and page-copy slice; it does not assert parity with all Android PDF tools.
- No iOS purchase product IDs, ad unit IDs, tracking configuration or privacy prompts are selected here.
- The ML Kit Translation adapter is a recorded platform decision only; no translation implementation or SDK integration is included in this phase.


## Billing and advertising implementation

- The iOS subscription uses the existing product identifier `vibesync_pro_1y` as a yearly auto-renewing StoreKit subscription.
- StoreKit 2 grants Pro only from verified, non-revoked current entitlements. Restore Purchases invokes `AppStore.sync()` only after an explicit user action.
- The local Xcode purchase environment is `iosApp/VibeSyncIOSApp/StoreKitConfig.storekit`; it contains the annual Pro Pass product used by simulator tests.
- Google Mobile Ads is resolved through the Swift Package Manager package `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`.
- Debug builds use Google's official sample iOS AdMob app and test banner/interstitial unit IDs. Release build settings require real iOS app, banner, and interstitial IDs before ads can be served; Android ad unit IDs are not reused.
- Configure `ADMOB_APP_ID`, `ADMOB_BANNER_AD_UNIT_ID`, and `ADMOB_INTERSTITIAL_AD_UNIT_ID` in the Release app target build settings before App Store distribution.
