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
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .pageImageUnavailable:
            return "The scanned PDF page could not be rendered for text recognition."
        case .imageUnavailable:
            return "The selected image could not be prepared for text recognition."
        }
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

    /// Normalizes UIImage orientation and caps the OCR input at 2,600 pixels per side.
    /// This supports camera images and PhotosPicker assets without retaining full-resolution originals.
    static func recognize(image: UIImage) async throws -> [OcrTextObservation] {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            throw OcrEngineError.imageUnavailable
        }
        let scale = min(1, 2600 / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let normalizedImage = UIGraphicsImageRenderer(size: targetSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let cgImage = normalizedImage.cgImage else {
            throw OcrEngineError.imageUnavailable
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
