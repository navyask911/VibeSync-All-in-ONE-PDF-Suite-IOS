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

    func testPDFViewerSearchFindsAndNavigatesDigitalText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--pdf-viewer-search-test"]
        app.launch()

        let readerCard = app.buttons["tool_view_read"]
        XCTAssertTrue(readerCard.waitForExistence(timeout: 15), "View & Read card did not appear.")
        readerCard.tap()

        let searchField = app.textFields["pdf_viewer_search_field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 15), "PDFKit reader did not appear.")
        XCTAssertTrue(app.staticTexts["View & Read"].exists, "Reader title is missing.")

        searchField.tap()
        searchField.typeText("VibeSync Search Match")

        let searchButton = app.buttons["pdf_viewer_search_submit"]
        let searchReady = NSPredicate(format: "isEnabled == true")
        expectation(for: searchReady, evaluatedWith: searchButton)
        waitForExpectations(timeout: 10)
        searchButton.tap()

        let resultCount = app.staticTexts["pdf_viewer_search_count"]
        let twoMatches = NSPredicate(format: "label == %@", "1 of 2 matches")
        expectation(for: twoMatches, evaluatedWith: resultCount)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["pdf_viewer_next_match"].isEnabled, "Next should be enabled when two matches exist.")

        app.buttons["pdf_viewer_next_match"].tap()
        XCTAssertEqual(resultCount.label, "2 of 2 matches", "Next did not focus the second PDF text match.")

        app.buttons["pdf_viewer_previous_match"].tap()
        XCTAssertEqual(resultCount.label, "1 of 2 matches", "Previous did not return to the first PDF text match.")

        Thread.sleep(forTimeInterval: 1)
        attachScreenshot(named: "screenshot_viewer", from: app)
    }

    func testVisionOcrRecognizesTextInImageOnlyPdf() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ocr-engine-smoke-test"]
        app.launch()

        let result = app.staticTexts["ocr_engine_smoke_result"]
        XCTAssertTrue(result.waitForExistence(timeout: 60), "Vision OCR engine did not report a test result.")
        XCTAssertTrue(
            result.label.contains("OCR_ENGINE_TEST_PASSED"),
            "Vision OCR failed to read the raster-only PDF: \(result.label)"
        )
        XCTAssertTrue(result.label.contains("HELLO"), "OCR result did not contain HELLO.")
        XCTAssertTrue(result.label.contains("WORLD"), "OCR result did not contain WORLD.")
    }

    func testPdfViewerSearchFindsTextInScannedPdfWithVisionOcr() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--pdf-viewer-ocr-test"]
        app.launch()

        let readerCard = app.buttons["tool_view_read"]
        XCTAssertTrue(readerCard.waitForExistence(timeout: 15), "View & Read card did not appear.")
        readerCard.tap()

        let searchField = app.textFields["pdf_viewer_search_field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 15), "PDFKit reader did not appear.")
        searchField.tap()
        searchField.typeText("HELLO WORLD")
        app.buttons["pdf_viewer_search_submit"].tap()

        let resultCount = app.staticTexts["pdf_viewer_search_count"]
        let found = NSPredicate(format: "label == %@", "1 of 1 matches")
        expectation(for: found, evaluatedWith: resultCount)
        waitForExpectations(timeout: 60)
        XCTAssertTrue(app.buttons["pdf_viewer_next_match"].isEnabled)
    }

    func testSignatureEmbeddingAddsStampAndProducesLargerFlattenedPdf() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--signature-embedding-smoke-test"]
        app.launch()

        let result = app.staticTexts["signature_embedding_smoke_result"]
        XCTAssertTrue(result.waitForExistence(timeout: 20), "Signature embedding did not report a test result.")
        XCTAssertTrue(
            result.label.contains("SIGNATURE_EMBEDDING_TEST_PASSED"),
            "PDFKit signature embedding failed: \(result.label)"
        )
        XCTAssertTrue(result.label.contains("bytes="), "The flattened PDF size was not reported.")
    }

    func testTranslationViewShowsOCRImportAndLanguageControls() throws {
        let app = XCUIApplication()
        app.launch()

        let translationCard = app.buttons["tool_translation_scan"]
        scrollToElement(translationCard, in: app)
        XCTAssertTrue(translationCard.waitForExistence(timeout: 15), "Translation Scan dashboard card did not appear.")
        translationCard.tap()

        XCTAssertTrue(app.staticTexts["Translate scanned documents"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["translation_import_button"].exists, "PDF import action is missing.")
        XCTAssertTrue(app.buttons["translation_translate_button"].exists, "Translate action is missing.")
        XCTAssertTrue(app.textViews["translation_original_input"].exists, "Editable original-text area is missing.")
        XCTAssertTrue(app.buttons["translation_swap_languages"].exists, "Source/target language swap is missing.")

        attachScreenshot(named: "screenshot_translation", from: app)
    }

    func testMLKitDownloadsModelsAndTranslatesEnglishToSpanish() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mlkit-translation-smoke-test"]
        app.launch()

        let result = app.staticTexts["mlkit_translation_smoke_result"]
        XCTAssertTrue(
            result.waitForExistence(timeout: 240),
            "ML Kit model initialization/download and translation did not finish within four minutes."
        )
        XCTAssertTrue(
            result.label.contains("MLKIT_TRANSLATION_TEST_PASSED"),
            "ML Kit English-to-Spanish translation failed: \(result.label)"
        )
        XCTAssertTrue(
            result.label.localizedCaseInsensitiveContains("hola"),
            "The Spanish translation should contain 'Hola': \(result.label)"
        )
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
