import PDFKit
import UIKit
import Vision

struct OcrTextObservation: Identifiable, Sendable {
    let id: UUID
    let text: String
    /// Vision's normalized rectangle, with a bottom-left origin.
    let normalizedBounds: CGRect
    let confidence: Float
}

enum OcrEngineError: LocalizedError {
    case pageImageUnavailable

    var errorDescription: String? {
        "The scanned PDF page could not be rendered for text recognition."
    }
}

/// On-device OCR for image-only PDF pages. The embedded PDF text layer remains
/// the preferred search path; this engine is used only when a page has no text.
enum OcrEngine {
    private struct SendableCGImage: @unchecked Sendable {
        let value: CGImage
    }

    static func recognize(
        page: PDFPage,
        renderScale: CGFloat = 2.5
    ) async throws -> [OcrTextObservation] {
        let pageBounds = page.bounds(for: .cropBox)
        let targetSize = CGSize(
            width: max(1, pageBounds.width * renderScale),
            height: max(1, pageBounds.height * renderScale)
        )
        let renderedPage = page.thumbnail(of: targetSize, for: .cropBox)
        guard let cgImage = renderedPage.cgImage else {
            throw OcrEngineError.pageImageUnavailable
        }
        return try await recognize(cgImage: cgImage)
    }

    static func recognize(cgImage: CGImage) async throws -> [OcrTextObservation] {
        let image = SendableCGImage(value: cgImage)
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if #available(iOS 16.0, *) {
                request.automaticallyDetectsLanguage = true
            }

            let handler = VNImageRequestHandler(cgImage: image.value, options: [:])
            try handler.perform([request])

            return (request.results ?? []).compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return OcrTextObservation(
                    id: UUID(),
                    text: candidate.string,
                    normalizedBounds: observation.boundingBox,
                    confidence: candidate.confidence
                )
            }
        }.value
    }
}
