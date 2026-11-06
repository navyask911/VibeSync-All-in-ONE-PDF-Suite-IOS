import PDFKit
import UIKit

enum SignaturePDFExporter {
    struct PagePreview {
        let image: UIImage
        let size: CGSize
    }

    enum ExportError: LocalizedError {
        case unreadablePDF
        case lockedPDF
        case invalidPage
        case invalidSignature
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .unreadablePDF:
                return "The selected PDF could not be opened."
            case .lockedPDF:
                return "This PDF is password protected. Unlock it before placing a signature."
            case .invalidPage:
                return "The selected PDF page is unavailable."
            case .invalidSignature:
                return "The selected signature image is invalid."
            case .exportFailed:
                return "The signed PDF could not be generated."
            }
        }
    }

    static func pagePreview(from data: Data, pageIndex: Int) throws -> PagePreview {
        let document = try openDocument(data)
        guard let page = document.page(at: pageIndex) else {
            throw ExportError.invalidPage
        }

        let bounds = page.bounds(for: .mediaBox).standardized
        guard bounds.width > 0, bounds.height > 0 else {
            throw ExportError.invalidPage
        }

        let scale = min(2.0, 1800.0 / max(bounds.width, 1), 2400.0 / max(bounds.height, 1))
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        return PagePreview(
            image: page.thumbnail(of: size, for: .mediaBox),
            size: CGSize(width: bounds.width, height: bounds.height)
        )
    }

    /// Recreates every source page as vector PDF content and paints the chosen signature
    /// into the selected page. Position and size are normalized to the page's top-left origin.
    static func addingSignature(
        to data: Data,
        signature: UIImage,
        pageIndex: Int,
        normalizedCenter: CGPoint,
        widthFraction: CGFloat,
        rotationDegrees: CGFloat
    ) throws -> Data {
        let document = try openDocument(data)
        guard pageIndex >= 0, pageIndex < document.pageCount,
              let signatureCGImage = signature.cgImage,
              signatureCGImage.width > 0,
              signatureCGImage.height > 0 else {
            throw ExportError.invalidSignature
        }

        let signatureAspect = CGFloat(signatureCGImage.width) / CGFloat(signatureCGImage.height)
        guard signatureAspect.isFinite, signatureAspect > 0,
              widthFraction.isFinite, widthFraction > 0 else {
            throw ExportError.invalidSignature
        }

        let firstBounds = document.page(at: 0)?.bounds(for: .mediaBox).standardized
            ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: firstBounds.size)
        )

        let signedData = renderer.pdfData { rendererContext in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let mediaBox = page.bounds(for: .mediaBox).standardized
                let outputBounds = CGRect(origin: .zero, size: mediaBox.size)
                rendererContext.beginPage(withBounds: outputBounds, pageInfo: [:])

                let context = rendererContext.cgContext
                context.saveGState()
                context.translateBy(x: -mediaBox.minX, y: mediaBox.height + mediaBox.minY)
                context.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: context)
                context.restoreGState()

                guard index == pageIndex else { continue }

                let pageWidth = outputBounds.width
                let pageHeight = outputBounds.height
                let signatureWidth = pageWidth * min(max(widthFraction, 0.06), 0.75)
                let signatureHeight = signatureWidth / signatureAspect
                let centerX = min(max(normalizedCenter.x, 0.0), 1.0) * pageWidth
                let centerY = min(max(normalizedCenter.y, 0.0), 1.0) * pageHeight

                context.saveGState()
                context.translateBy(x: centerX, y: centerY)
                context.rotate(by: rotationDegrees * .pi / 180)
                signature.draw(
                    in: CGRect(
                        x: -signatureWidth / 2,
                        y: -signatureHeight / 2,
                        width: signatureWidth,
                        height: signatureHeight
                    )
                )
                context.restoreGState()
            }
        }

        guard !signedData.isEmpty, PDFDocument(data: signedData)?.pageCount == document.pageCount else {
            throw ExportError.exportFailed
        }
        return signedData
    }

    private static func openDocument(_ data: Data) throws -> PDFDocument {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw ExportError.unreadablePDF
        }
        guard !document.isLocked else {
            throw ExportError.lockedPDF
        }
        return document
    }
}
