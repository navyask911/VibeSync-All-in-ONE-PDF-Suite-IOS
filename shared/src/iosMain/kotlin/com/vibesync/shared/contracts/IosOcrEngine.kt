@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

package com.vibesync.shared.contracts

import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import platform.Foundation.NSData
import platform.Foundation.NSObject
import platform.Foundation.dataWithBytes
import platform.UIKit.UIImage
import platform.Vision.VNImageRequestHandler
import platform.Vision.VNRecognizeTextRequest
import platform.Vision.VNRecognizedTextObservation
import platform.Vision.VNRequestTextRecognitionLevelAccurate

/**
 * Apple Vision text recognition adapter. Recognition executes entirely on-device.
 * The synchronous bridge is exposed to SwiftUI; the suspend override supports common callers.
 */
internal class IosOcrEngine : OcrEngine {
    override suspend fun recognize(imageBytes: ByteArray, languageTag: String?): String =
        recognizeSync(imageBytes, languageTag)

    fun recognizeSync(imageBytes: ByteArray, languageTag: String?): String {
        require(imageBytes.isNotEmpty()) { "The selected image is empty." }
        val image = UIImage(data = imageBytes.toNSData())
            ?: throw IllegalArgumentException("The selected image could not be decoded.")
        val cgImage = image.CGImage
            ?: throw IllegalArgumentException("The selected image has no raster representation.")

        val request = VNRecognizeTextRequest()
        request.recognitionLevel = VNRequestTextRecognitionLevelAccurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = languageTag.isNullOrBlank()
        languageTag?.takeIf { it.isNotBlank() }?.let { tag ->
            request.recognitionLanguages = listOf(visionLanguageTag(tag))
        }

        val handler = VNImageRequestHandler(cGImage = cgImage, options = emptyMap<Any?, Any?>())
        handler.performRequests(listOf(request), error = null)

        val observations = request.results as? List<VNRecognizedTextObservation> ?: emptyList()
        return observations.mapNotNull { observation ->
            // VNRecognizedText is an Objective-C object. KVC reads its public
            // NSString property directly and avoids a Kotlin/Native selector
            // naming mismatch in the generated Vision bindings.
            val candidate = observation.topCandidates(1uL)
                .firstOrNull() as? NSObject
            (candidate?.valueForKey("string") as? String)
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
        }.joinToString("\n")
    }

    private fun visionLanguageTag(languageTag: String): String {
        val normalized = languageTag.replace('_', '-')
        return when (normalized.lowercase()) {
            "iw", "iw-il" -> "he"
            "zh" -> "zh-Hans"
            "tl", "fil" -> "fil"
            else -> normalized
        }
    }

    private fun ByteArray.toNSData(): NSData =
        usePinned { pinned ->
            NSData.dataWithBytes(pinned.addressOf(0), size.toULong())
        }
}
