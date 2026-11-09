import Foundation
import StoreKit
import StoreKitTest
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

        let editSignButton = app.descendants(matching: .any)
            .matching(identifier: "tool_edit_sign")
            .firstMatch
        scrollToElement(editSignButton, in: app)
        XCTAssertTrue(editSignButton.waitForExistence(timeout: 10), "Edit & Sign dashboard card did not appear.")
        editSignButton.tap()
        let editSignPDFImporter = app.buttons["signature_pdf_import_button"]
        XCTAssertTrue(
            editSignPDFImporter.waitForExistence(timeout: 10),
            "Edit & Sign did not open Signature Manager with its PDF importer."
        )
        app.navigationBars.buttons.firstMatch.tap()

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


    func testImagesToPDFDashboardOpensPickerAndCreatesValidPDF() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--images-to-pdf-renderer-smoke-test"]
        app.launch()

        let imageToPDFCard = app.descendants(matching: .any)
            .matching(identifier: "tool_images_to_pdf")
            .firstMatch
        scrollToElement(imageToPDFCard, in: app)
        XCTAssertTrue(imageToPDFCard.waitForExistence(timeout: 15), "Image to PDF dashboard card did not appear.")
        imageToPDFCard.tap()

        XCTAssertTrue(app.navigationBars["Image to PDF"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "images_to_pdf_photos_picker").firstMatch.exists,
            "Image to PDF is missing its PhotosPicker entry point."
        )
        XCTAssertTrue(app.buttons["images_to_pdf_create_button"].exists, "Create PDF action is missing.")

        let result = app.staticTexts["images_to_pdf_status"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), "The image-to-PDF renderer did not report a result.")
        XCTAssertTrue(
            result.label.contains("IMAGE_TO_PDF_TEST_PASSED"),
            "Image-to-PDF renderer failed to create a valid PDF: \(result.label)"
        )
        XCTAssertTrue(result.label.contains("pages=1"), "The renderer did not produce exactly one page.")
        XCTAssertTrue(result.label.contains("bytes="), "The renderer did not report a non-empty PDF size.")
    }

    func testTranslationViewShowsOCRImportAndLanguageControls() throws {
        let app = XCUIApplication()
        app.launch()

        let translationCard = app.buttons["tool_translation_scan"]
        scrollToElement(translationCard, in: app)
        XCTAssertTrue(translationCard.waitForExistence(timeout: 15), "Translation Scan dashboard card did not appear.")
        translationCard.tap()

        XCTAssertTrue(app.navigationBars["Scan & Translate"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Translate scanned documents"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["translation_import_button"].exists, "PDF import action is missing.")
        XCTAssertTrue(app.buttons["translation_camera_button"].exists, "Camera image input is missing.")
        XCTAssertTrue(app.buttons["translation_photo_library_button"].exists, "Photo Library image input is missing.")
        XCTAssertTrue(app.buttons["translation_translate_button"].exists, "Translate action is missing.")
        XCTAssertTrue(app.textViews["translation_original_input"].exists, "Editable original-text area is missing.")
        XCTAssertTrue(app.buttons["translation_swap_languages"].exists, "Source/target language swap is missing.")

        attachScreenshot(named: "screenshot_translation", from: app)
    }

    func testTranslationExportsGenerateValidTemporaryFiles() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--translation-export-smoke-test"]
        app.launch()

        let result = app.staticTexts["translation_export_smoke_result"]
        XCTAssertTrue(
            result.waitForExistence(timeout: 20),
            "The app did not report a result for the translation export smoke test."
        )
        XCTAssertTrue(
            result.label.contains("TRANSLATION_EXPORT_TEST_PASSED"),
            "TXT/PDF export did not create readable temporary files: \(result.label)"
        )
        XCTAssertTrue(result.label.contains("txtBytes="), "The TXT file size was not reported.")
        XCTAssertTrue(result.label.contains("pdfPages="), "The PDF document was not validated.")
    }

    @MainActor
    func testStoreKitLocalSubscriptionGrantsProAndRemovesDashboardAds() async throws {
        guard let storeKitURL = Bundle(for: Self.self).url(
            forResource: "StoreKitConfig",
            withExtension: "storekit"
        ) else {
            XCTFail("StoreKitConfig.storekit was not bundled with the UI tests.")
            return
        }

        let session = try SKTestSession(contentsOf: storeKitURL)
        try session.resetToDefaultState()
        try session.clearTransactions()
        session.disableDialogs = true

        // Create the purchase through StoreKitTest, then verify its persisted
        // transaction state before launching the app. The test environment is
        // shared, but Transaction.latest can remain suspended in this hosted
        // simulator process; allTransactions() is StoreKitTest's direct oracle.
        if #available(iOS 17.0, *) {
            _ = try await session.buyProduct(identifier: "vibesync_pro_1y", options: [])
        } else {
            try session.buyProduct(productIdentifier: "vibesync_pro_1y")
        }
        let hasActiveTestPurchase = session.allTransactions().contains { transaction in
            transaction.productIdentifier == "vibesync_pro_1y"
                && transaction.state == .purchased
                && transaction.cancelDate == nil
                && (transaction.expirationDate.map { $0 > Date() } ?? true)
        }
        XCTAssertTrue(
            hasActiveTestPurchase,
            "StoreKitTest did not record a purchased, unexpired vibesync_pro_1y transaction."
        )

        let app = XCUIApplication()
        defer {
            app.terminate()
            session.clearTransactions()
        }
        app.launchArguments = [
            "--storekit-entitlement-smoke-test",
            "--storekit-test-entitlement-active"
        ]
        app.launch()

        let result = app.staticTexts["storekit_entitlement_smoke_result"]
        XCTAssertTrue(result.waitForExistence(timeout: 15), "StoreKit entitlement smoke test did not start.")
        let entitlementResolved = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label CONTAINS %@ OR label CONTAINS %@",
                "STOREKIT_ENTITLEMENT_TEST_PASSED",
                "STOREKIT_ENTITLEMENT_TEST_FAILED"
            ),
            object: result
        )
        await fulfillment(of: [entitlementResolved], timeout: 45)
        XCTAssertTrue(
            result.label.contains("STOREKIT_ENTITLEMENT_TEST_PASSED"),
            "StoreKit 2 did not expose the verified Pro Pass entitlement: \(result.label)"
        )
        XCTAssertTrue(
            app.staticTexts["dashboard_ads_removed"].waitForExistence(timeout: 15),
            "The dashboard should hide ads after the StoreKit entitlement is verified."
        )
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "dashboard_banner_ad").firstMatch.exists,
            "A premium subscriber must not receive a dashboard banner."
        )

        let proAction = app.buttons["dashboard_action_vibesync_pdf_pro"]
        XCTAssertTrue(proAction.waitForExistence(timeout: 15), "The dashboard Pro action is missing.")
        proAction.tap()
        XCTAssertTrue(
            app.staticTexts["pro_active_state"].waitForExistence(timeout: 15),
            "The paywall did not show the active Pro subscription."
        )
    }

    @MainActor
    func testAdMobInitializesWithConfiguredSimulatorTestApplicationID() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--admob-initialization-smoke-test"]
        app.launch()

        let result = app.staticTexts["admob_initialization_smoke_result"]
        XCTAssertTrue(result.waitForExistence(timeout: 30), "AdMob initialization did not report a result.")
        XCTAssertTrue(
            result.label.contains("ADMOB_INITIALIZATION_TEST_PASSED"),
            "AdMob did not initialize with the configured simulator test app ID: \(result.label)"
        )
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "dashboard_banner_ad").firstMatch.waitForExistence(timeout: 15),
            "The dashboard banner slot is missing for a non-Pro user."
        )
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
