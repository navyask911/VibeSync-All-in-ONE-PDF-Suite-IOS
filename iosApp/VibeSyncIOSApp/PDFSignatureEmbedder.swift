import Foundation
import PDFKit
import UIKit

enum PDFSignatureEmbeddingError: LocalizedError {
    case invalidPage
    case invalidImage
    case invalidPlacement
    case flatteningFailed

    var errorDescription: String? {
        switch self {
        case .invalidPage:
            return "The selected PDF page is not available for signature placement."
        case .invalidImage:
            return "The selected signature image could not be rendered."
        case .invalidPlacement:
            return "The signature placement is outside the PDF page."
        case .flatteningFailed:
            return "The signature annotation could not be embedded into the PDF."
        }
    }
}

/// Creates printable PDFKit stamp annotations and flattens them into PDF page content.
enum PDFSignatureEmbedder {
    static func addSignature(
        image: UIImage,
        to document: PDFDocument,
        pageIndex: Int,
        center: CGPoint,
        width: CGFloat,
        rotationDegrees: CGFloat
    ) throws -> PDFSignatureStampAnnotation {
        guard let page = document.page(at: pageIndex) else {
            throw PDFSignatureEmbeddingError.invalidPage
        }
        guard image.cgImage != nil, image.size.width > 0, image.size.height > 0 else {
            throw PDFSignatureEmbeddingError.invalidImage
        }
        guard width.isFinite, width > 0,
              center.x.isFinite, center.y.isFinite,
              rotationDegrees.isFinite else {
            throw PDFSignatureEmbeddingError.invalidPlacement
        }

        let pageBounds = page.bounds(for: .cropBox)
        guard !pageBounds.isEmpty else {
            throw PDFSignatureEmbeddingError.invalidPlacement
        }

        let safeWidth = min(width, pageBounds.width * 0.85)
        let imageSize = CGSize(
            width: safeWidth,
            height: safeWidth * image.size.height / image.size.width
        )
        let geometry = annotationGeometry(
            pageBounds: pageBounds,
            center: center,
            imageSize: imageSize,
            rotationDegrees: rotationDegrees
        )
        let annotation = makeAnnotation(
            bounds: geometry.bounds,
            image: image,
            imageSize: geometry.imageSize,
            rotationDegrees: rotationDegrees
        )
        page.addAnnotation(annotation)
        return annotation
    }

    static func makeAnnotation(
        bounds: CGRect,
        image: UIImage,
        imageSize: CGSize,
        rotationDegrees: CGFloat
    ) -> PDFSignatureStampAnnotation {
        PDFSignatureStampAnnotation(
            bounds: bounds,
            signatureImage: image,
            imageSize: imageSize,
            rotationDegrees: rotationDegrees
        )
    }

    static func annotationGeometry(
        pageBounds: CGRect,
        center: CGPoint,
        imageSize: CGSize,
        rotationDegrees: CGFloat
    ) -> (bounds: CGRect, imageSize: CGSize) {
        let radians = rotationDegrees * .pi / 180
        let envelopeWidth = abs(cos(radians)) * imageSize.width
            + abs(sin(radians)) * imageSize.height
        let envelopeHeight = abs(sin(radians)) * imageSize.width
            + abs(cos(radians)) * imageSize.height
        let halfWidth = min(envelopeWidth / 2, pageBounds.width / 2)
        let halfHeight = min(envelopeHeight / 2, pageBounds.height / 2)

        let safeCenter = CGPoint(
            x: min(max(center.x, pageBounds.minX + halfWidth), pageBounds.maxX - halfWidth),
            y: min(max(center.y, pageBounds.minY + halfHeight), pageBounds.maxY - halfHeight)
        )
        return (
            CGRect(
                x: safeCenter.x - halfWidth,
                y: safeCenter.y - halfHeight,
                width: halfWidth * 2,
                height: halfHeight * 2
            ),
            imageSize
        )
    }

    static func flattenedData(from document: PDFDocument) throws -> Data {
        guard document.pageCount > 0,
              let data = document.dataRepresentation(options: [
                PDFDocumentWriteOption.burnInAnnotationsOption: true
              ]),
              !data.isEmpty,
              let reopenedDocument = PDFDocument(data: data),
              reopenedDocument.pageCount == document.pageCount else {
            throw PDFSignatureEmbeddingError.flatteningFailed
        }
        return data
    }
}

final class PDFSignatureStampAnnotation: PDFAnnotation {
    var signatureImage: UIImage
    var imageSize: CGSize
    var rotationDegrees: CGFloat

    init(
        bounds: CGRect,
        signatureImage: UIImage,
        imageSize: CGSize,
        rotationDegrees: CGFloat
    ) {
        self.signatureImage = signatureImage
        self.imageSize = imageSize
        self.rotationDegrees = rotationDegrees
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
        shouldDisplay = true
        shouldPrint = true
    }

    required init?(coder: NSCoder) {
        signatureImage = UIImage()
        imageSize = .zero
        rotationDegrees = 0
        super.init(coder: coder)
    }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = signatureImage.cgImage else { return }
        context.saveGState()
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: -rotationDegrees * .pi / 180)
        context.scaleBy(x: 1, y: -1)
        context.draw(
            cgImage,
            in: CGRect(
                x: -imageSize.width / 2,
                y: -imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )
        )
        context.restoreGState()
    }
}
