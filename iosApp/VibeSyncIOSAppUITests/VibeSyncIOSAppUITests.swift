import Foundation
import Shared
import PDFKit
import UIKit
import XCTest

final class VibeSyncIOSAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testIDCardComposerAndSignatureManagerNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        let idCardButton = app.descendants(matching: .any)
            .matching(identifier: "tool_id_card")
            .firstMatch
        XCTAssertTrue(idCardButton.waitForExistence(timeout: 15), "ID Card Composer entry point did not appear.")
        idCardButton.tap()

        let idCardGuidance = app.staticTexts["id_card_guidance"]
        XCTAssertTrue(idCardGuidance.waitForExistence(timeout: 10), "ID Card Composer did not load after tapping its dashboard entry.")
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot(named: "screenshot_id_card", from: app)

        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "ID Card Composer did not expose a navigation Back button.")
        backButton.tap()

        let signatureButton = app.descendants(matching: .any)
            .matching(identifier: "tool_signature_manager")
            .firstMatch
        XCTAssertTrue(signatureButton.waitForExistence(timeout: 10), "Signature Manager entry point did not reappear after returning to the dashboard.")
        signatureButton.tap()

        let signatureImportButton = app.buttons["signature_pdf_import_button"]
        XCTAssertTrue(signatureImportButton.waitForExistence(timeout: 10), "Signature Manager did not load after tapping its dashboard entry.")
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot(named: "screenshot_signature", from: app)
    }

    func testPdfKitEngineReadsPdfGeneratedFromDummyImage() throws {
        let imageSize = CGSize(width: 160, height: 90)
        let dummyImage = UIGraphicsImageRenderer(size: imageSize).image { renderer in
            renderer.cgContext.setFillColor(UIColor.white.cgColor)
            renderer.cgContext.fill(CGRect(origin: .zero, size: imageSize))
            renderer.cgContext.setFillColor(UIColor.systemBlue.cgColor)
            renderer.cgContext.fill(CGRect(x: 16, y: 16, width: 128, height: 58))
        }

        // Create the page from the image with PDFKit itself, then serialize the document.
        let pdfPage = try XCTUnwrap(PDFPage(image: dummyImage))
        let pdfDocument = PDFDocument()
        pdfDocument.insert(pdfPage, at: 0)
        let pdfData = try XCTUnwrap(pdfDocument.dataRepresentation())

        XCTAssertGreaterThan(pdfData.count, 0, "The dummy image should generate a non-empty PDF.")

        let pdfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VibeSync-PdfEngine-Test-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        try pdfData.write(to: pdfURL, options: .atomic)
        let attributes = try FileManager.default.attributesOfItem(atPath: pdfURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertGreaterThan(fileSize, 0, "The generated PDF file must contain bytes.")

        // This synchronous bridge delegates to the actual shared IosPdfEngine implementation.
        IosPlatformProviders.shared.install()
        let pageCount = IosPlatformProviders.shared.pdfPageCount(data: pdfData)
        XCTAssertEqual(Int(pageCount), 1, "The PDFKit-backed PdfEngine should read the generated one-page PDF.")
    }

    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
