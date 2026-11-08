import Foundation
import PDFKit
import Shared
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct PDFExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct OpenedPDFDocument {
    let data: Data
    let fileName: String
}

private struct DashboardTool: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var isImportingPDF = false
    @State private var isExportingPDF = false
    @State private var selectedPDFData: Data?
    @State private var selectedPDFName = "document"
    @State private var pageCount: Int?
    @State private var exportDocument: PDFExportDocument?
    @State private var exportFileName = "document-copy"
    @State private var noticeTitle = "VibeSync"
    @State private var noticeMessage = ""
    @State private var isShowingNotice = false
    @State private var pdfEngineSmokeResult: String?
    @State private var signatureVaultSmokeResult: String?
    @State private var openedPDFForViewing: OpenedPDFDocument?
    @State private var isShowingPDFViewer = false
    @State private var searchTestPDF: OpenedPDFDocument?
    @State private var mlKitTranslationSmokeResult: String?
    @State private var ocrEngineSmokeResult: String?
    @State private var signatureEmbeddingSmokeResult: String?
    @State private var translationExportSmokeResult: String?

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var dashboardTools: [DashboardTool] {
        [
            DashboardTool(id: "tool_view_read", title: "View & Read", subtitle: "Continuous scroll and 400% zoom", symbol: "book.closed", tint: VibeSyncColors.crimsonPrimary),
            DashboardTool(id: "tool_edit_sign", title: "Edit & Sign", subtitle: "Pen, highlighter, and e-signature", symbol: "pencil.tip.crop.circle", tint: VibeSyncColors.rubyAccent),
            DashboardTool(id: "tool_document_scanner", title: "Document Scanner", subtitle: "Scan documents to PDF", symbol: "doc.viewfinder", tint: VibeSyncColors.crimsonPrimary),
            DashboardTool(id: "tool_split_document", title: "Split Document", subtitle: "Extract custom page ranges", symbol: "scissors", tint: VibeSyncColors.crimsonDark),
            DashboardTool(id: "tool_merge_documents", title: "Merge Documents", subtitle: "Combine PDF files", symbol: "arrow.triangle.merge", tint: VibeSyncColors.rubyDeep),
            DashboardTool(id: "tool_images_to_pdf", title: "Images to PDF", subtitle: "Create a PDF from photos", symbol: "photo.badge.plus", tint: VibeSyncColors.rubyAccent),
            DashboardTool(id: "tool_extract_images", title: "Extract Images", subtitle: "Save embedded images", symbol: "photo", tint: VibeSyncColors.crimsonLight),
            DashboardTool(id: "tool_encrypt_protect", title: "Encrypt & Protect", subtitle: "Password-protect a PDF", symbol: "lock.shield", tint: VibeSyncColors.rubyDeep),
            DashboardTool(id: "tool_batch_scan", title: "Batch scan", subtitle: "Capture multiple pages in one session", symbol: "doc.text.viewfinder", tint: VibeSyncColors.crimsonPrimary),
            DashboardTool(id: "tool_book_split", title: "Book Split", subtitle: "Split book scans into pages", symbol: "book.pages", tint: VibeSyncColors.rubyAccent),
            DashboardTool(id: "tool_id_card", title: "ID Card Composer", subtitle: "Put card front and back on one A4 page", symbol: "person.text.rectangle", tint: VibeSyncColors.crimsonDark),
            DashboardTool(id: "tool_id_photo", title: "ID Photo Maker", subtitle: "Prepare passport and ID photos", symbol: "person.crop.rectangle", tint: VibeSyncColors.rubyDeep),
            DashboardTool(id: "tool_translation_scan", title: "Translation Scan", subtitle: "Recognize and translate a document", symbol: "character.bubble", tint: VibeSyncColors.rubyAccent),
            DashboardTool(id: "tool_manual_crop", title: "Manual Crop", subtitle: "Crop and straighten captured images", symbol: "crop.rotate", tint: VibeSyncColors.crimsonPrimary),
            DashboardTool(id: "tool_signature_manager", title: "Signature Manager", subtitle: "Manage and place saved signatures", symbol: "signature", tint: VibeSyncColors.rubyAccent),
            DashboardTool(id: "tool_vault", title: "Vault", subtitle: "Keep private PDF files protected", symbol: "lock.fill", tint: VibeSyncColors.rubyDeep)
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dashboardHeader

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        privacyBanner
                        heroBanner

                        if let signatureVaultSmokeResult {
                            Text(signatureVaultSmokeResult)
                                .vibeSyncStyle(.bodyMedium)
                                .foregroundStyle(signatureVaultSmokeResult.contains("SIGNATURE_VAULT_TEST_PASSED")
                                                 ? VibeSyncColors.successGreen
                                                 : VibeSyncColors.dangerRed)
                                .accessibilityIdentifier("signature_vault_smoke_result")
                        }

                        if let ocrEngineSmokeResult {
                            Text(ocrEngineSmokeResult)
                                .vibeSyncStyle(.bodyMedium)
                                .foregroundStyle(ocrEngineSmokeResult.contains("OCR_ENGINE_TEST_PASSED")
                                                 ? VibeSyncColors.successGreen
                                                 : VibeSyncColors.dangerRed)
                                .accessibilityIdentifier("ocr_engine_smoke_result")
                        }

                        if let signatureEmbeddingSmokeResult {
                            Text(signatureEmbeddingSmokeResult)
                                .vibeSyncStyle(.bodyMedium)
                                .foregroundStyle(signatureEmbeddingSmokeResult.contains("SIGNATURE_EMBEDDING_TEST_PASSED")
                                                 ? VibeSyncColors.successGreen
                                                 : VibeSyncColors.dangerRed)
                                .accessibilityIdentifier("signature_embedding_smoke_result")
                        }

                        if let translationExportSmokeResult {
                            Text(translationExportSmokeResult)
                                .vibeSyncStyle(.bodyMedium)
                                .foregroundStyle(translationExportSmokeResult.contains("TRANSLATION_EXPORT_TEST_PASSED")
                                                 ? VibeSyncColors.successGreen
                                                 : VibeSyncColors.dangerRed)
                                .accessibilityIdentifier("translation_export_smoke_result")
                        }

                        if let mlKitTranslationSmokeResult {
                            Text(mlKitTranslationSmokeResult)
                                .vibeSyncStyle(.bodyMedium)
                                .foregroundStyle(mlKitTranslationSmokeResult.contains("MLKIT_TRANSLATION_TEST_PASSED")
                                                 ? VibeSyncColors.successGreen
                                                 : VibeSyncColors.dangerRed)
                                .accessibilityIdentifier("mlkit_translation_smoke_result")
                        }

                        if let pdfEngineSmokeResult {
                            Text(pdfEngineSmokeResult)
                                .vibeSyncStyle(.bodyMedium)
                                .foregroundStyle(pdfEngineSmokeResult.contains("PDF_ENGINE_TEST_PASSED")
                                                 ? VibeSyncColors.successGreen
                                                 : VibeSyncColors.dangerRed)
                                .accessibilityIdentifier("pdf_engine_smoke_result")
                        }

                        Text("Core toolkit")
                            .vibeSyncStyle(.labelLarge)
                            .foregroundStyle(VibeSyncColors.primary(for: colorScheme))
                            .padding(.top, 2)
                            .accessibilityIdentifier("dashboard_core_toolkit")

                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(dashboardTools) { tool in
                                toolCard(tool)
                            }
                        }

                        if let pageCount {
                            pdfLoadedPanel(pageCount: pageCount)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 112)
                }
                .background(VibeSyncColors.background(for: colorScheme))
            }
            .background(VibeSyncColors.background(for: colorScheme).ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                openPDFButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .fileImporter(
                isPresented: $isImportingPDF,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                importSelectedPDF(result)
            }
            .fileExporter(
                isPresented: $isExportingPDF,
                document: exportDocument,
                contentType: .pdf,
                defaultFilename: exportFileName
            ) { result in
                switch result {
                case .success:
                    presentNotice(title: "PDF exported", message: "Your PDF copy was saved successfully.")
                case .failure(let error):
                    presentNotice(title: "Export failed", message: error.localizedDescription)
                }
            }
            .alert(noticeTitle, isPresented: $isShowingNotice) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(noticeMessage)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingPDFViewer) {
                if let openedPDFForViewing {
                    PdfViewerView(pdfData: openedPDFForViewing.data, fileName: openedPDFForViewing.fileName)
                }
            }
            .onAppear {
                IosPlatformProviders.shared.install()
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--pdf-engine-smoke-test") {
                    runPdfEngineSmokeTest()
                }
                if arguments.contains("--signature-vault-smoke-test") {
                    runSignatureVaultSmokeTest()
                }
                if arguments.contains("--pdf-viewer-search-test") {
                    searchTestPDF = makeSearchTestPDF()
                }
                if arguments.contains("--ocr-engine-smoke-test") {
                    runOcrEngineSmokeTest()
                }
                if arguments.contains("--signature-embedding-smoke-test") {
                    runSignatureEmbeddingSmokeTest()
                }
                if arguments.contains("--pdf-viewer-ocr-test") {
                    searchTestPDF = makeScannedSearchTestPDF()
                }
                if arguments.contains("--mlkit-translation-smoke-test") {
                    runMLKitTranslationSmokeTest()
                }
                if arguments.contains("--translation-export-smoke-test") {
                    runTranslationExportSmokeTest()
                }
            }
        }
        .tint(VibeSyncColors.primary(for: colorScheme))
    }

    private var dashboardHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(VibeSyncColors.crimsonPrimary)
                    .frame(width: 36, height: 36)
                    .background(VibeSyncColors.surfaceVariant(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("VibeSync All in ONE PDF Suite")
                    .font(VibeSyncTypography.titleMedium.weight(.bold))
                    .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .accessibilityIdentifier("dashboard_brand_title")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            HStack(spacing: 0) {
                quickAction(symbol: "shield.lefthalf.filled", label: "Privacy & Terms", tint: VibeSyncColors.successGreen) {
                    presentNotice(
                        title: "Privacy & Data Safety",
                        message: "PDF rendering, document processing and signature storage are designed to run locally on this device. Documents are not uploaded to a cloud service."
                    )
                }
                quickAction(symbol: "globe", label: "Language", tint: VibeSyncColors.primary(for: colorScheme)) {
                    presentNotice(title: "Language", message: "Language selection will be added in a later iOS phase.")
                }
                quickAction(symbol: "crown.fill", label: "VibeSync PDF Pro", tint: VibeSyncColors.primary(for: colorScheme)) {
                    presentNotice(title: "VibeSync PDF Pro", message: "Pro subscription management will be added in a later iOS phase.")
                }
                quickAction(symbol: "folder", label: "Choose PDF folder", tint: VibeSyncColors.primary(for: colorScheme)) {
                    presentNotice(title: "PDF folder", message: "Folder discovery is not part of this iOS dashboard phase. Use Open PDF to choose a document.")
                }
                quickAction(symbol: "arrow.clockwise", label: "Rescan", tint: VibeSyncColors.primary(for: colorScheme)) {
                    presentNotice(title: "Dashboard", message: "The dashboard is up to date.")
                }
                quickAction(symbol: "doc.badge.plus", label: "Open document", tint: VibeSyncColors.primary(for: colorScheme)) {
                    isImportingPDF = true
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
        }
        .background(VibeSyncColors.surface(for: colorScheme))
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    private func quickAction(
        symbol: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("dashboard_action_\(label.replacingOccurrences(of: " ", with: "_").lowercased())")
    }

    private var privacyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 52 / 255, green: 211 / 255, blue: 153 / 255))
                .frame(width: 28, height: 28)
                .background(Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255).opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("All files stay on your device. No cloud upload.")
                    .font(VibeSyncTypography.bodyMedium.weight(.bold))
                    .foregroundStyle(Color(red: 236 / 255, green: 253 / 255, blue: 245 / 255))
                    .lineSpacing(3)

                Text("Your PDFs are processed locally on this phone.")
                    .font(.custom("Roboto-Regular", size: 11))
                    .foregroundStyle(Color(red: 167 / 255, green: 243 / 255, blue: 208 / 255))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 4 / 255, green: 33 / 255, blue: 23 / 255).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(VibeSyncColors.successGreen.opacity(0.5), lineWidth: 1)
        }
        .accessibilityIdentifier("dashboard_privacy_banner")
    }

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("100% on-device PDF suite")
                .font(VibeSyncTypography.titleMedium.weight(.bold))
                .foregroundStyle(VibeSyncColors.white)

            Text("Local PDF processing, document scanning, and encrypted tools.")
                .font(VibeSyncTypography.bodyMedium)
                .foregroundStyle(VibeSyncColors.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(VibeSyncColors.crimsonDark)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("dashboard_hero_banner")
    }

    @ViewBuilder
    private func toolCard(_ tool: DashboardTool) -> some View {
        switch tool.id {
        case "tool_id_card":
            NavigationLink {
                IdCardComposerView()
            } label: {
                toolCardContent(tool)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(tool.id)
        case "tool_edit_sign", "tool_signature_manager":
            NavigationLink {
                SignatureManagerView()
            } label: {
                toolCardContent(tool)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(tool.id)
        case "tool_translation_scan":
            NavigationLink {
                TranslationView()
            } label: {
                toolCardContent(tool)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(tool.id)
        default:
            Button {
                handleToolSelection(tool)
            } label: {
                toolCardContent(tool)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(tool.id)
        }
    }

    private func toolCardContent(_ tool: DashboardTool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: tool.symbol)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(tool.tint)
                .frame(width: 40, height: 40)
                .background(tool.tint.opacity(0.15))
                .clipShape(Circle())

            Spacer().frame(height: 10)

            Text(tool.title)
                .vibeSyncStyle(.labelLarge)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 2)

            Text(tool.subtitle)
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(VibeSyncColors.surfaceVariant(for: colorScheme).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private var openPDFButton: some View {
        Button {
            isImportingPDF = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                Text("Open PDF")
                    .font(VibeSyncTypography.labelLarge)
            }
            .foregroundStyle(VibeSyncColors.white)
            .padding(.horizontal, 18)
            .frame(height: 50)
            .background(VibeSyncColors.crimsonPrimary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard_open_pdf_fab")
    }

    private func pdfLoadedPanel(pageCount: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 24))
                .foregroundStyle(VibeSyncColors.primary(for: colorScheme))
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedPDFName)
                    .vibeSyncStyle(.titleMedium)
                    .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                Text("\(pageCount) \(pageCount == 1 ? "page" : "pages") loaded")
                    .vibeSyncStyle(.bodyMedium)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
            }
            Spacer()
            Button("Export a copy") {
                prepareExportCopy()
            }
            .font(VibeSyncTypography.labelLarge)
            .buttonStyle(.bordered)
            .tint(VibeSyncColors.primary(for: colorScheme))
            .accessibilityIdentifier("dashboard_export_pdf_copy")
        }
        .padding(14)
        .background(VibeSyncColors.surfaceVariant(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("pdf_loaded_panel")
    }

    private func handleToolSelection(_ tool: DashboardTool) {
        switch tool.id {
        case "tool_view_read":
            if let searchTestPDF {
                openPDFForReading(searchTestPDF)
            } else {
                isImportingPDF = true
            }
        case "tool_edit_sign":
            presentNotice(title: tool.title, message: "PDF annotation and editing tools will be connected in a later iOS phase.")
        case "tool_images_to_pdf":
            presentNotice(title: tool.title, message: "Image-to-PDF conversion will be connected in a later iOS phase.")
        case "tool_vault":
            presentNotice(title: tool.title, message: "Signature images are stored securely in the iOS Keychain. Open Signature Manager to manage saved signatures.")
        case "tool_translation_scan":
            presentNotice(title: tool.title, message: "OCR and translation are intentionally not included in this iOS phase.")
        default:
            presentNotice(title: tool.title, message: "This tool's iOS workflow will be connected in a later phase.")
        }
    }

    private func presentNotice(title: String, message: String) {
        noticeTitle = title
        noticeMessage = message
        isShowingNotice = true
    }

    private func importSelectedPDF(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccessResource = url.startAccessingSecurityScopedResource()
            defer {
                if didAccessResource {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let count = Int(IosPlatformProviders.shared.pdfPageCount(data: data))
            guard count > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let openedDocument = OpenedPDFDocument(data: data, fileName: url.lastPathComponent)
            selectedPDFData = data
            selectedPDFName = url.deletingPathExtension().lastPathComponent
            pageCount = count
            openPDFForReading(openedDocument)
        } catch {
            selectedPDFData = nil
            pageCount = nil
            presentNotice(title: "Could not open PDF", message: error.localizedDescription)
        }
    }

    private func openPDFForReading(_ document: OpenedPDFDocument) {
        openedPDFForViewing = document
        selectedPDFData = document.data
        selectedPDFName = document.fileName
        pageCount = PDFDocument(data: document.data)?.pageCount
        isShowingPDFViewer = true
    }

    private func makeSearchTestPDF() -> OpenedPDFDocument? {
        let pageBounds = CGRect(x: 0, y: 0, width: 595.2756, height: 841.8898)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { context in
            context.beginPage()
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 27, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            NSString(string: "VibeSync Searchable Sample")
                .draw(at: CGPoint(x: 54, y: 70), withAttributes: titleAttributes)
            NSString(string: "This document contains selectable digital text.")
                .draw(at: CGPoint(x: 54, y: 132), withAttributes: bodyAttributes)
            NSString(string: "VibeSync Search Match — result one")
                .draw(at: CGPoint(x: 54, y: 220), withAttributes: bodyAttributes)
            NSString(string: "VibeSync Search Match — result two")
                .draw(at: CGPoint(x: 54, y: 330), withAttributes: bodyAttributes)
            NSString(string: "Search uses PDFKit and does not require OCR for digital PDFs.")
                .draw(at: CGPoint(x: 54, y: 440), withAttributes: bodyAttributes)
        }
        guard !data.isEmpty else { return nil }
        return OpenedPDFDocument(data: data, fileName: "VibeSync-Search-Sample.pdf")
    }

    private func runTranslationExportSmokeTest() {
        do {
            let sampleText = "VibeSync Translation Export"
            let textData = try TranslationExportFactory.makeData(for: sampleText, format: .text)
            let textURL = try TranslationExportFactory.writeTemporaryFile(data: textData, fileExtension: "txt")
            defer { try? FileManager.default.removeItem(at: textURL) }

            let reopenedText = try Data(contentsOf: textURL)
            guard
                FileManager.default.fileExists(atPath: textURL.path),
                String(data: reopenedText, encoding: .utf8) == sampleText
            else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let pdfData = try TranslationExportFactory.makeData(for: sampleText, format: .pdf)
            let pdfURL = try TranslationExportFactory.writeTemporaryFile(data: pdfData, fileExtension: "pdf")
            defer { try? FileManager.default.removeItem(at: pdfURL) }

            guard
                FileManager.default.fileExists(atPath: pdfURL.path),
                let pdfDocument = PDFDocument(url: pdfURL),
                pdfDocument.pageCount > 0,
                pdfDocument.page(at: 0) != nil
            else {
                throw CocoaError(.fileReadCorruptFile)
            }

            translationExportSmokeResult = "TRANSLATION_EXPORT_TEST_PASSED txtBytes=\(reopenedText.count) pdfBytes=\(pdfData.count) pdfPages=\(pdfDocument.pageCount)"
        } catch {
            translationExportSmokeResult = "TRANSLATION_EXPORT_TEST_FAILED \(error.localizedDescription)"
        }
    }

    private func runMLKitTranslationSmokeTest() {
        Task { @MainActor in
            do {
                let translated = try await MLKitTranslationEngine().translate(
                    "Hello world",
                    from: "en",
                    to: "es"
                )
                guard translated.localizedCaseInsensitiveContains("hola") else {
                    throw NSError(
                        domain: "VibeSyncMLKitTranslationSmokeTest",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Expected a Spanish translation containing 'Hola'; got: \(translated)"]
                    )
                }
                mlKitTranslationSmokeResult = "MLKIT_TRANSLATION_TEST_PASSED \(translated)"
            } catch {
                mlKitTranslationSmokeResult = "MLKIT_TRANSLATION_TEST_FAILED \(error.localizedDescription)"
            }
        }
    }

    private func makeScannedSearchTestPDF() -> OpenedPDFDocument? {
        do {
            return OpenedPDFDocument(
                data: try makeScannedTextPDF(),
                fileName: "VibeSync-Scanned-OCR.pdf"
            )
        } catch {
            return nil
        }
    }

    private func makeScannedTextPDF() throws -> Data {
        let imageSize = CGSize(width: 1800, height: 520)
        let image = UIGraphicsImageRenderer(size: imageSize).image { renderer in
            renderer.cgContext.setFillColor(UIColor.white.cgColor)
            renderer.cgContext.fill(CGRect(origin: .zero, size: imageSize))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 180, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            NSString(string: "HELLO WORLD")
                .draw(at: CGPoint(x: 100, y: 155), withAttributes: attributes)
        }

        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { context in
            context.beginPage()
            image.draw(in: CGRect(x: 50, y: 290, width: 512, height: 148))
        }
        guard !data.isEmpty else { throw CocoaError(.fileWriteUnknown) }
        return data
    }

    private func runOcrEngineSmokeTest() {
        Task { @MainActor in
            do {
                let data = try makeScannedTextPDF()
                guard let document = PDFDocument(data: data),
                      let page = document.page(at: 0),
                      (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw NSError(
                        domain: "VibeSyncOcrSmokeTest",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "The OCR fixture must contain no embedded PDF text."]
                    )
                }

                let observations = try await OcrEngine.recognize(page: page)
                let recognizedText = observations.map(\.text).joined(separator: " ").uppercased()
                guard recognizedText.contains("HELLO"), recognizedText.contains("WORLD") else {
                    throw NSError(
                        domain: "VibeSyncOcrSmokeTest",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Vision did not recognize HELLO WORLD. OCR returned: \(recognizedText)"]
                    )
                }
                ocrEngineSmokeResult = "OCR_ENGINE_TEST_PASSED \(recognizedText)"
            } catch {
                ocrEngineSmokeResult = "OCR_ENGINE_TEST_FAILED \(error.localizedDescription)"
            }
        }
    }

    private func runSignatureEmbeddingSmokeTest() {
        do {
            let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
            let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
            let originalData = renderer.pdfData { context in
                context.beginPage()
                NSString(string: "Signature embedding test document")
                    .draw(at: CGPoint(x: 50, y: 70), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
                        .foregroundColor: UIColor.black
                    ])
            }
            guard let document = PDFDocument(data: originalData),
                  let page = document.page(at: 0) else {
                throw PDFSignatureEmbeddingError.invalidPage
            }

            let signatureSize = CGSize(width: 360, height: 140)
            let signatureImage = UIGraphicsImageRenderer(size: signatureSize).image { renderer in
                let context = renderer.cgContext
                context.setStrokeColor(UIColor.black.cgColor)
                context.setLineWidth(9)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.move(to: CGPoint(x: 25, y: 100))
                context.addCurve(
                    to: CGPoint(x: 330, y: 45),
                    control1: CGPoint(x: 80, y: 5),
                    control2: CGPoint(x: 220, y: 130)
                )
                context.strokePath()
            }

            let annotation = try PDFSignatureEmbedder.addSignature(
                image: signatureImage,
                to: document,
                pageIndex: 0,
                center: CGPoint(x: 310, y: 350),
                width: 150,
                rotationDegrees: 12
            )
            guard page.annotations.contains(where: { $0 === annotation }),
                  annotation.shouldPrint else {
                throw PDFSignatureEmbeddingError.invalidPlacement
            }

            let flattenedData = try PDFSignatureEmbedder.flattenedData(from: document)
            guard flattenedData.count > originalData.count,
                  let reopened = PDFDocument(data: flattenedData),
                  reopened.pageCount == 1 else {
                throw PDFSignatureEmbeddingError.flatteningFailed
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("VibeSync-Signature-Embedding-\(UUID().uuidString)")
                .appendingPathExtension("pdf")
            defer { try? FileManager.default.removeItem(at: outputURL) }
            try flattenedData.write(to: outputURL, options: .atomic)
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let outputSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard outputSize > originalData.count else {
                throw PDFSignatureEmbeddingError.flatteningFailed
            }

            signatureEmbeddingSmokeResult = "SIGNATURE_EMBEDDING_TEST_PASSED bytes=\(outputSize)"
        } catch {
            signatureEmbeddingSmokeResult = "SIGNATURE_EMBEDDING_TEST_FAILED \(error.localizedDescription)"
        }
    }

    private func prepareExportCopy() {
        guard let selectedPDFData else { return }

        let suggestedName = selectedPDFName.isEmpty ? "document-copy.pdf" : "\(selectedPDFName)-copy.pdf"
        guard
            let stagedURI = IosPlatformProviders.shared.stageExportCopy(
                data: selectedPDFData,
                suggestedFileName: suggestedName
            ),
            let stagedURL = URL(string: stagedURI)
        else {
            presentNotice(title: "Export failed", message: "The PDF copy could not be prepared for export.")
            return
        }

        do {
            let stagedData = try Data(contentsOf: stagedURL)
            exportDocument = PDFExportDocument(data: stagedData)
            exportFileName = (suggestedName as NSString).deletingPathExtension
            isExportingPDF = true
        } catch {
            presentNotice(title: "Export failed", message: error.localizedDescription)
        }
    }

    /// Test-only end-to-end PDFKit creation and the real shared iOS PdfEngine parser.
    private func runPdfEngineSmokeTest() {
        do {
            let imageSize = CGSize(width: 160, height: 90)
            let dummyImage = UIGraphicsImageRenderer(size: imageSize).image { renderer in
                renderer.cgContext.setFillColor(UIColor.white.cgColor)
                renderer.cgContext.fill(CGRect(origin: .zero, size: imageSize))
                renderer.cgContext.setFillColor(UIColor.systemBlue.cgColor)
                renderer.cgContext.fill(CGRect(x: 16, y: 16, width: 128, height: 58))
            }

            let pageBounds = CGRect(x: 0, y: 0, width: 595.2756, height: 841.8898)
            let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
            let pdfData = renderer.pdfData { context in
                context.beginPage()
                dummyImage.draw(in: CGRect(x: 48, y: 48, width: 240, height: 135))
            }
            guard !pdfData.isEmpty else {
                throw CocoaError(.fileWriteUnknown)
            }

            let pdfURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("VibeSync-PdfEngine-Smoke-\(UUID().uuidString)")
                .appendingPathExtension("pdf")
            defer { try? FileManager.default.removeItem(at: pdfURL) }

            try pdfData.write(to: pdfURL, options: .atomic)
            let attributes = try FileManager.default.attributesOfItem(atPath: pdfURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard fileSize > 0 else {
                throw CocoaError(.fileWriteUnknown)
            }

            let pageCount = Int(IosPlatformProviders.shared.pdfPageCount(data: pdfData))
            guard pageCount == 1 else {
                throw NSError(
                    domain: "VibeSyncPdfEngineSmokeTest",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "PdfEngine reported \(pageCount) pages for a one-page PDF."]
                )
            }

            pdfEngineSmokeResult = "PDF_ENGINE_TEST_PASSED bytes=\(fileSize) pages=\(pageCount)"
        } catch {
            pdfEngineSmokeResult = "PDF_ENGINE_TEST_FAILED \(error.localizedDescription)"
        }
    }

    /// Test-only real Keychain round trip. The temporary item is always removed.
    private func runSignatureVaultSmokeTest() {
        let identifier = "__vibesync_ci_signature_smoke__\(UUID().uuidString)"
        let vault = SignatureVault()

        do {
            let size = CGSize(width: 48, height: 24)
            let sample = UIGraphicsImageRenderer(size: size).image { renderer in
                renderer.cgContext.setFillColor(UIColor.white.cgColor)
                renderer.cgContext.fill(CGRect(origin: .zero, size: size))
                renderer.cgContext.setStrokeColor(UIColor.systemBlue.cgColor)
                renderer.cgContext.setLineWidth(3)
                renderer.cgContext.move(to: CGPoint(x: 4, y: 18))
                renderer.cgContext.addLine(to: CGPoint(x: 44, y: 6))
                renderer.cgContext.strokePath()
            }

            try vault.saveSignature(sample, named: identifier)
            defer { try? vault.deleteSignature(named: identifier) }

            guard
                let loadedImage = try vault.loadSignature(named: identifier),
                let loadedPNG = loadedImage.pngData(),
                !loadedPNG.isEmpty,
                try vault.listSignatures().contains(where: { $0.id == identifier })
            else {
                throw NSError(
                    domain: "VibeSyncSignatureVaultSmokeTest",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "The saved signature could not be loaded from Keychain."]
                )
            }

            signatureVaultSmokeResult = "SIGNATURE_VAULT_TEST_PASSED"
        } catch {
            signatureVaultSmokeResult = "SIGNATURE_VAULT_TEST_FAILED \(error.localizedDescription)"
        }
    }
}
