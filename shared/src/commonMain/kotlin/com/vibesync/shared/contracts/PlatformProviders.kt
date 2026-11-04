package com.vibesync.shared.contracts

/**
 * Entry-point registry for platform-owned capability implementations.
 *
 * The iOS host registers its adapters during application startup, then reads these
 * nullable properties from Swift through the exported Shared framework. Keeping this
 * registry in commonMain avoids importing UIKit, PDFKit, StoreKit, or ad SDKs into
 * shared contracts.
 *
 * A provider stays null until the host installs it. Call [install] before exposing
 * the corresponding feature to the user; this registry does not supply fallbacks.
 */
object PlatformProviders {
    var pdfEngine: PdfEngine? = null
        private set

    var ocrEngine: OcrEngine? = null
        private set

    var translator: Translator? = null
        private set

    var billingProvider: BillingProvider? = null
        private set

    var adProvider: AdProvider? = null
        private set

    var fileExporter: FileExporter? = null
        private set

    /**
     * Installs the platform adapters as one startup operation.
     *
     * Nullable entries deliberately allow a platform host to install only the
     * capabilities it currently supports. Unimplemented capabilities remain null.
     */
    fun install(
        pdfEngine: PdfEngine?,
        ocrEngine: OcrEngine?,
        translator: Translator?,
        billingProvider: BillingProvider?,
        adProvider: AdProvider?,
        fileExporter: FileExporter?
    ) {
        this.pdfEngine = pdfEngine
        this.ocrEngine = ocrEngine
        this.translator = translator
        this.billingProvider = billingProvider
        this.adProvider = adProvider
        this.fileExporter = fileExporter
    }

    /** Clears all installed adapters, primarily for host teardown and tests. */
    fun clear() {
        pdfEngine = null
        ocrEngine = null
        translator = null
        billingProvider = null
        adProvider = null
        fileExporter = null
    }
}
