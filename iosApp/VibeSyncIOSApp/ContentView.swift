import Foundation
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
            .onAppear {
                IosPlatformProviders.shared.install()
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--pdf-engine-smoke-test") {
                    runPdfEngineSmokeTest()
                }
                if arguments.contains("--signature-vault-smoke-test") {
                    runSignatureVaultSmokeTest()
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
        case "tool_signature_manager":
            NavigationLink {
                SignatureManagerView()
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
            isImportingPDF = true
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

            selectedPDFData = data
            selectedPDFName = url.deletingPathExtension().lastPathComponent
            pageCount = count
            presentNotice(title: "PDF opened", message: "\(selectedPDFName) contains \(count) \(count == 1 ? "page" : "pages").")
        } catch {
            selectedPDFData = nil
            pageCount = nil
            presentNotice(title: "Could not open PDF", message: error.localizedDescription)
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
