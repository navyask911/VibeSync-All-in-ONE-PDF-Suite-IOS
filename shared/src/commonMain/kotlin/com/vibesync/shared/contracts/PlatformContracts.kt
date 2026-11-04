package com.vibesync.shared.contracts

/**
 * Platform-neutral PDF capability boundary.
 *
 * Page indexes are zero-based. Rendered page bytes are PNG encoded.
 * iOS adapter technology: PDFKit and Core Graphics.
 */
interface PdfEngine {
    suspend fun pageCount(pdfBytes: ByteArray): Int

    suspend fun renderPage(
        pdfBytes: ByteArray,
        pageIndex: Int,
        scale: Float
    ): ByteArray

    suspend fun extractText(pdfBytes: ByteArray, pageIndex: Int): String

    suspend fun exportPages(
        pdfBytes: ByteArray,
        zeroBasedPageIndexes: List<Int>
    ): ByteArray
}

/**
 * Platform-neutral text-recognition boundary.
 *
 * imageBytes contains an encoded raster image; languageTag is a BCP-47 tag or null for automatic selection.
 * iOS adapter technology: Vision (VNRecognizeTextRequest).
 */
interface OcrEngine {
    suspend fun recognize(imageBytes: ByteArray, languageTag: String?): String
}

/**
 * Platform-neutral translation boundary.
 *
 * Language tags use BCP-47 identifiers (for example, "en" or "hi").
 * iOS adapter technology: Google ML Kit Translation API (on-device; language models are downloaded
 * to the device). ML Kit supports iOS 15.5+ and 64-bit architectures; the app baseline is iOS 16.0+.
 */
interface Translator {
    suspend fun translate(
        text: String,
        sourceLanguageTag: String?,
        targetLanguageTag: String
    ): String
}

/**
 * Platform-neutral purchase and entitlement boundary.
 *
 * purchase returns true only for a verified, completed entitlement; pending or cancelled purchases
 * return false. Platform failures are reported as exceptions.
 * iOS adapter technology: StoreKit 2 (Product, Transaction.currentEntitlements, AppStore.sync).
 */
interface BillingProvider {
    suspend fun isEntitled(productId: String): Boolean

    suspend fun purchase(productId: String): Boolean

    suspend fun restorePurchases(): Set<String>
}

/**
 * Platform-neutral advertising boundary.
 *
 * showInterstitial returns true only when an interstitial was actually presented.
 * iOS adapter technology: Google Mobile Ads SDK for iOS (AdMob).
 */
interface AdProvider {
    suspend fun showInterstitial(placementId: String): Boolean
}

/**
 * Platform-neutral user-mediated file export boundary.
 *
 * Returns a URI for a staged export file, or null if staging cannot be completed.
 * The platform host presents the user-mediated save UI using SwiftUI fileExporter/FileDocument
 * with UniformTypeIdentifiers; use UIActivityViewController for a share-sheet flow where required.
 */
interface FileExporter {
    suspend fun export(
        data: ByteArray,
        suggestedFileName: String,
        mimeType: String
    ): String?
}
