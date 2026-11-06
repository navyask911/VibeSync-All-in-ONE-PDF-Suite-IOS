@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

package com.vibesync.shared.contracts

import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import platform.Foundation.NSData
import platform.Foundation.getBytes

/**
 * iOS registration and Swift-friendly entry points for PDF, Vision OCR and file export.
 *
 * PDFKit, Vision and the file exporter are registered in the common provider registry.
 * Translation is supplied by the native Swift ML Kit adapter because the iOS SDK ships as a Pod.
 */
object IosPlatformProviders {
    private val pdfEngine = IosPdfEngine()
    private val ocrEngine = IosOcrEngine()
    private val fileExporter = IosFileExporter()

    /** Register the iOS PDFKit, Vision and temporary-file adapters with commonMain. */
    fun install() {
        PlatformProviders.install(
            pdfEngine,
            ocrEngine,
            null,
            null,
            null,
            fileExporter
        )
    }

    /** Synchronous bridge used by the SwiftUI picker flow. Zero means the PDF was unreadable. */
    fun pdfPageCount(data: NSData): Int =
        runCatching { pdfEngine.pageCountSync(data.toByteArrayForBridge()) }.getOrDefault(0)

    /** Synchronous Vision bridge used by the SwiftUI image/PDF OCR flow. */
    fun recognizeText(data: NSData, languageTag: String?): String =
        ocrEngine.recognizeSync(data.toByteArrayForBridge(), languageTag)

    /** Stages a copy for SwiftUI fileExporter; null means the staging write failed. */
    fun stageExportCopy(data: NSData, suggestedFileName: String): String? =
        runCatching {
            fileExporter.stageExportCopy(data.toByteArrayForBridge(), suggestedFileName)
        }.getOrNull()

    private fun NSData.toByteArrayForBridge(): ByteArray {
        val byteCount = length.toInt()
        if (byteCount == 0) return ByteArray(0)
        return ByteArray(byteCount).also { result ->
            result.usePinned { pinned ->
                getBytes(pinned.addressOf(0), length)
            }
        }
    }
}
