@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

package com.vibesync.shared.contracts

import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import platform.Foundation.NSData
import platform.Foundation.NSUUID
import platform.Foundation.NSTemporaryDirectory
import platform.Foundation.NSURL
import platform.Foundation.dataWithBytes
import platform.Foundation.writeToURL

/**
 * Writes export bytes to a unique temporary PDF file. The SwiftUI host then presents
 * that staged file through fileExporter so the user chooses the final save destination.
 */
internal class IosFileExporter : FileExporter {
    override suspend fun export(
        data: ByteArray,
        suggestedFileName: String,
        mimeType: String
    ): String? = stageExportCopy(data, suggestedFileName)

    fun stageExportCopy(data: ByteArray, suggestedFileName: String): String? {
        if (data.isEmpty()) return null

        val safeName = suggestedFileName
            .substringAfterLast('/')
            .substringAfterLast('\\')
            .map { character ->
                if (character.isLetterOrDigit() || character in "._-") character else '_'
            }
            .joinToString("")
            .ifBlank { "VibeSync-export.pdf" }

        val temporaryDirectory = NSTemporaryDirectory().trimEnd('/')
        val path = "$temporaryDirectory/${NSUUID().UUIDString}-$safeName"
        val destination = NSURL.fileURLWithPath(path)
        val nativeData = data.usePinned { pinned ->
            NSData.dataWithBytes(pinned.addressOf(0), data.size.toULong())
        }

        if (!nativeData.writeToURL(destination, atomically = true)) return null
        return destination.absoluteString
    }
}
