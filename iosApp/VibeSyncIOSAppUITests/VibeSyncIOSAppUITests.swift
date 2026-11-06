import Foundation
import XCTest

final class VibeSyncIOSAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testIDCardComposerAndSignatureManagerNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        let brandTitle = app.staticTexts["dashboard_brand_title"]
        XCTAssertTrue(brandTitle.waitForExistence(timeout: 15), "The dashboard brand header did not appear.")
        XCTAssertTrue(app.staticTexts["Core toolkit"].exists, "The Core toolkit section did not appear.")
        XCTAssertTrue(app.buttons["dashboard_open_pdf_fab"].exists, "The Open PDF floating action button did not appear.")
        XCTAssertTrue(app.staticTexts["All files stay on your device. No cloud upload."].exists)
        attachScreenshot(named: "screenshot_dashboard", from: app)

        let idCardButton = app.descendants(matching: .any)
            .matching(identifier: "tool_id_card")
            .firstMatch
        scrollToElement(idCardButton, in: app)
        XCTAssertTrue(idCardButton.waitForExistence(timeout: 10), "ID Card Composer entry point did not appear.")
        XCTAssertTrue(idCardButton.isHittable, "ID Card Composer entry point is not tappable.")
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
        scrollToElement(signatureButton, in: app)
        XCTAssertTrue(signatureButton.waitForExistence(timeout: 10), "Signature Manager entry point did not reappear after returning to the dashboard.")
        XCTAssertTrue(signatureButton.isHittable, "Signature Manager entry point is not tappable.")
        signatureButton.tap()

        let signatureImportButton = app.buttons["signature_pdf_import_button"]
        XCTAssertTrue(signatureImportButton.waitForExistence(timeout: 10), "Signature Manager did not load after tapping its dashboard entry.")
        let vaultError = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "The secure signature vault failed")
        ).firstMatch
        XCTAssertFalse(vaultError.exists, "Signature Manager displayed a Keychain vault failure.")
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot(named: "screenshot_signature", from: app)
    }

    func testSignatureVaultCanSaveAndLoadWithoutKeychainError() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--signature-vault-smoke-test"]
        app.launch()

        let result = app.staticTexts["signature_vault_smoke_result"]
        XCTAssertTrue(
            result.waitForExistence(timeout: 20),
            "The app did not report a result for the Keychain signature-vault smoke test."
        )
        XCTAssertTrue(
            result.label.contains("SIGNATURE_VAULT_TEST_PASSED"),
            "SignatureVault save/load failed: \(result.label)"
        )

        app.terminate()
        app.launchArguments = []
        app.launch()

        let signatureButton = app.descendants(matching: .any)
            .matching(identifier: "tool_signature_manager")
            .firstMatch
        scrollToElement(signatureButton, in: app)
        XCTAssertTrue(signatureButton.waitForExistence(timeout: 10), "Signature Manager entry point did not appear.")
        signatureButton.tap()

        let importButton = app.buttons["signature_pdf_import_button"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 10), "Signature Manager did not finish loading.")
        let vaultError = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "The secure signature vault failed")
        ).firstMatch
        XCTAssertFalse(vaultError.exists, "The Keychain -34018 error message is visible in Signature Manager.")
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

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable {
                return
            }
            app.swipeUp()
        }
    }

    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
