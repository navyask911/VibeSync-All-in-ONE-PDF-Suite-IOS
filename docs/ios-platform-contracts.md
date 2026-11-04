# iOS platform contract plan

This is an interface-only boundary proposal for the shared Kotlin Multiplatform module. It does not contain platform implementations and does not move Android business logic. The iOS choices below are the intended adapter technologies for a later migration phase.

| commonMain interface | Planned iOS adapter technology | Notes |
|---|---|---|
| PdfEngine | **PDFKit** + Core Graphics | PDFDocument and PDFPage for page operations, text extraction and rasterization. Advanced editing/export behaviors must be assessed against the Android feature set before parity claims. |
| OcrEngine | **Vision** | VNRecognizeTextRequest; use Vision language correction and recognition-level settings in the future adapter. |
| Translator | **Google ML Kit for iOS (Translate)** | On-device Translation API; language-specific models are downloaded and managed on-device. ML Kit's published iOS prerequisites are iOS 15.5+ and 64-bit architecture, so the app's iOS 16.0 floor satisfies this requirement. |
| BillingProvider | **StoreKit 2** | Product, verified Transaction, Transaction.currentEntitlements, and AppStore.sync for purchase and restore state. |
| AdProvider | **Google Mobile Ads SDK for iOS (AdMob)** | Native SDK adapter; consent, ATT, ad identifiers and placement policy remain platform-specific decisions. |
| FileExporter | **SwiftUI FileDocument / fileExporter** | UniformTypeIdentifiers for export types; UIActivityViewController for share-sheet presentation when needed. |

## Contract conventions

- PDF page indexes are zero-based. PdfEngine.renderPage returns PNG-encoded bytes.
- OCR and translation language identifiers are BCP-47 tags.
- BillingProvider.purchase returns true only after the platform verifies a completed entitlement; pending/cancelled flows return false. Platform failures are surfaced as exceptions.
- AdProvider.showInterstitial returns true only when presentation occurred.
- FileExporter.export returns a platform URI string after a successful user-mediated export, or null on cancellation.

## Explicit non-goals for this phase

- No iosMain implementations or actual declarations.
- No Android implementation relocation or business-logic migration.
- No parity assertion for the PDF, OCR, translation, billing, ads or export feature sets.
- No iOS purchase product IDs, ad unit IDs, tracking configuration or privacy prompts are selected here.
- The ML Kit Translation adapter is a recorded platform decision only; no translation implementation or SDK integration is included in this phase.
