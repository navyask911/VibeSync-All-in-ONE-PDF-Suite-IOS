import Foundation
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
        let app = XCUIApplication()
        app.launchArguments.append("--pdf-engine-smoke-test")
        app.launch()

        let result = app.staticTexts["pdf_engine_smoke_result"]
        XCTAssertTrue(
            result.waitForExistence(timeout: 20),
            "The app did not report a result for the PDFKit engine smoke test."
        )
        let message = result.label
        XCTAssertTrue(
            message.contains("PDF_ENGINE_TEST_PASSED"),
            "PDFKit engine smoke test failed: \(message)"
        )
        XCTAssertTrue(message.contains("bytes="), "The test result must report the non-empty PDF file size.")
        XCTAssertTrue(message.contains("pages=1"), "The PdfEngine parser must report the generated single page.")
    }

    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
