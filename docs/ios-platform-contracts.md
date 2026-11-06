# iOS platform contract plan

This is an interface-only boundary proposal for the shared Kotlin Multiplatform module. It does not contain platform implementations and does not move Android business logic. The iOS choices below are the intended adapter technologies for a later migration phase.

| commonMain interface | iOS adapter technology | Status / notes |
|---|---|---|
| PdfEngine | **PDFKit** + Core Graphics | Implemented in iosMain. PDFDocument/PDFPage provide page count, text extraction, PNG page rendering and selected-page export. This initial slice does not claim advanced editing parity. |
| OcrEngine | **Vision** | Implemented in iosMain with VNRecognizeTextRequest, accurate recognition and language correction; exposed to the SwiftUI image/PDF import flow. |
| Translator | **Google ML Kit for iOS (Translate)** | Implemented by the native Swift IosMLKitTranslator adapter. Translation models are downloaded on-device after disclosure and are restricted to Wi-Fi. The iOS host uses the Swift adapter because Google's iOS ML Kit distribution is CocoaPods-based. |
| BillingProvider | **StoreKit 2** | Product, verified Transaction, Transaction.currentEntitlements, and AppStore.sync for purchase and restore state. |
| AdProvider | **Google Mobile Ads SDK for iOS (AdMob)** | Native SDK adapter; consent, ATT, ad identifiers and placement policy remain platform-specific decisions. |
| FileExporter | **Foundation temporary file + SwiftUI FileDocument / fileExporter** | Implemented in iosMain as a staged local file URI; the SwiftUI host reads the staged copy and presents the system save destination picker. |

## Contract conventions

- PDF page indexes are zero-based. PdfEngine.renderPage returns PNG-encoded bytes.
- OCR and translation language identifiers are BCP-47 tags.
- BillingProvider.purchase returns true only after the platform verifies a completed entitlement; pending/cancelled flows return false. Platform failures are surfaced as exceptions.
- AdProvider.showInterstitial returns true only when presentation occurred.
- FileExporter.export returns a URI for staged export bytes, or null if staging fails. The SwiftUI host performs the user-mediated destination selection and final copy.

## Explicit non-goals for this phase

- Billing and advertising implementations remain out of scope. Vision OCR and the native ML Kit translation adapter are implemented and wired into the SwiftUI TranslationView.
- No Android implementation relocation or business-logic migration.
- The PDF implementation is an initial import, inspect, render, and page-copy slice; it does not assert parity with all Android PDF tools.
- No iOS purchase product IDs, ad unit IDs, tracking configuration or privacy prompts are selected here.
- The ML Kit Translation adapter is integrated in the native SwiftUI host through the GoogleMLKit/Translate CocoaPod; it is not registered as a suspend-function implementation in the KMP provider registry.
