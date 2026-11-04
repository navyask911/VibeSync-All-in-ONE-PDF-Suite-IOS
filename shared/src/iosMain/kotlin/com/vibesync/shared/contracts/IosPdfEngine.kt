@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

package com.vibesync.shared.contracts

import kotlinx.cinterop.addressOf
import kotlinx.cinterop.useContents
import kotlinx.cinterop.usePinned
import platform.CoreGraphics.CGSizeMake
import platform.Foundation.NSData
import platform.Foundation.getBytes
import platform.Foundation.dataWithBytes
import platform.PDFKit.PDFDocument
import platform.PDFKit.kPDFDisplayBoxMediaBox
import platform.UIKit.UIImagePNGRepresentation
import kotlin.math.roundToInt

/**
 * PDFKit-backed iOS implementation. PDFPage thumbnails are rasterized by Core Graphics
 * and encoded as PNG to satisfy the common PdfEngine contract.
 */
internal class IosPdfEngine : PdfEngine {
    override suspend fun pageCount(pdfBytes: ByteArray): Int = pageCountSync(pdfBytes)

    fun pageCountSync(pdfBytes: ByteArray): Int =
        openDocument(pdfBytes).pageCount.toInt()

    override suspend fun renderPage(
        pdfBytes: ByteArray,
        pageIndex: Int,
        scale: Float
    ): ByteArray {
        require(scale.isFinite() && scale > 0f) { "Render scale must be a positive finite value." }
        val document = openDocument(pdfBytes)
        val page = document.pageAtIndex(pageIndex.checkedPageIndex(document).toULong())
            ?: throw IllegalArgumentException("PDF page $pageIndex is unavailable.")

        val (pageWidth, pageHeight) = page.boundsForBox(kPDFDisplayBoxMediaBox).useContents {
            size.width to size.height
        }
        require(pageWidth > 0.0 && pageHeight > 0.0) { "PDF page has invalid dimensions." }

        // Keep thumbnail memory bounded while retaining the caller's requested scale.
        val boundedScale = scale.toDouble().coerceAtMost(MAX_RENDER_SCALE)
        val width = (pageWidth * boundedScale).roundToInt().coerceIn(1, MAX_RENDER_DIMENSION)
        val height = (pageHeight * boundedScale).roundToInt().coerceIn(1, MAX_RENDER_DIMENSION)
        val image = page.thumbnailOfSize(
            CGSizeMake(width.toDouble(), height.toDouble()),
            forBox = kPDFDisplayBoxMediaBox
        )
        return UIImagePNGRepresentation(image)?.toByteArray()
            ?: throw IllegalStateException("PDFKit could not encode the rendered page.")
    }

    override suspend fun extractText(pdfBytes: ByteArray, pageIndex: Int): String {
        val document = openDocument(pdfBytes)
        val page = document.pageAtIndex(pageIndex.checkedPageIndex(document).toULong())
            ?: throw IllegalArgumentException("PDF page $pageIndex is unavailable.")
        return page.string.orEmpty()
    }

    override suspend fun exportPages(
        pdfBytes: ByteArray,
        zeroBasedPageIndexes: List<Int>
    ): ByteArray {
        require(zeroBasedPageIndexes.isNotEmpty()) { "At least one page must be selected." }
        val source = openDocument(pdfBytes)
        val output = PDFDocument()

        zeroBasedPageIndexes.forEach { pageIndex ->
            val page = source.pageAtIndex(pageIndex.checkedPageIndex(source).toULong())
                ?: throw IllegalArgumentException("PDF page $pageIndex is unavailable.")
            output.insertPage(page, atIndex = output.pageCount)
        }

        return output.dataRepresentation()?.toByteArray()
            ?: throw IllegalStateException("PDFKit could not create the exported PDF.")
    }

    private fun openDocument(pdfBytes: ByteArray): PDFDocument {
        require(pdfBytes.isNotEmpty()) { "The selected PDF is empty." }
        return PDFDocument(data = pdfBytes.toNSData())
            ?: throw IllegalArgumentException("The selected file is not a readable PDF.")
    }

    private fun Int.checkedPageIndex(document: PDFDocument): Int {
        require(this >= 0 && this < document.pageCount.toInt()) {
            "PDF page index $this is outside the document."
        }
        return this
    }

    private fun ByteArray.toNSData(): NSData =
        usePinned { pinned ->
            NSData.dataWithBytes(pinned.addressOf(0), size.toULong())
        }

    private fun NSData.toByteArray(): ByteArray {
        val byteCount = length.toInt()
        if (byteCount == 0) return ByteArray(0)
        return ByteArray(byteCount).also { result ->
            result.usePinned { pinned ->
                getBytes(pinned.addressOf(0), length)
            }
        }
    }

    private companion object {
        const val MAX_RENDER_SCALE = 8.0
        const val MAX_RENDER_DIMENSION = 8192
    }
}
