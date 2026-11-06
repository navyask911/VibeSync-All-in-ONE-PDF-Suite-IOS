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

struct ContentView: View {
    private let sharedModuleStatus = KmpCheck.shared.isWorking()

    @Environment(\.colorScheme) private var colorScheme
    @State private var isImportingPDF = false
    @State private var isExportingPDF = false
    @State private var selectedPDFData: Data?
    @State private var selectedPDFName = "document"
    @State private var pageCount: Int?
    @State private var exportDocument: PDFExportDocument?
    @State private var exportFileName = "document-copy"
    @State private var statusMessage = "Choose a PDF to view its page count."
    @State private var errorMessage: String?
    @State private var pdfEngineSmokeResult: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 48, weight: .regular))
                            .foregroundStyle(VibeSyncColors.primary(for: colorScheme))

                        Text("VibeSync All in ONE PDF Suite")
                            .vibeSyncStyle(.headlineMedium)
                            .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                            .multilineTextAlignment(.center)

                        Text(sharedModuleStatus)
                            .vibeSyncStyle(.bodyMedium)
                            .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                            .accessibilityIdentifier("shared_module_status")

                        if let pdfEngineSmokeResult {
                            Text(pdfEngineSmokeResult)
                                .vibeSyncStyle(.bodyMedium)
                                .foregroundStyle(pdfEngineSmokeResult.contains("PDF_ENGINE_TEST_PASSED")
                                                 ? VibeSyncColors.successGreen
                                                 : VibeSyncColors.dangerRed)
                                .accessibilityIdentifier("pdf_engine_smoke_result")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    NavigationLink {
                        IdCardComposerView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(VibeSyncColors.primary(for: colorScheme))
                                .frame(width: 48, height: 48)
                                .background(VibeSyncColors.white.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("ID Card Composer")
                                    .vibeSyncStyle(.titleMedium)
                                    .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                                Text("Put card front and back on one A4 page")
                                    .vibeSyncStyle(.bodyMedium)
                                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                            }

                            Spacer(minLength: 4)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VibeSyncColors.primary(for: colorScheme))
                        }
                        .padding(14)
                        .background(VibeSyncColors.surfaceVariant(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tool_id_card")

                    NavigationLink {
                        SignatureManagerView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "signature")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(VibeSyncColors.primary(for: colorScheme))
                                .frame(width: 48, height: 48)
                                .background(VibeSyncColors.white.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Signature Manager")
                                    .vibeSyncStyle(.titleMedium)
                                    .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                                Text("Draw, save and manage signatures")
                                    .vibeSyncStyle(.bodyMedium)
                                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                            }

                            Spacer(minLength: 4)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VibeSyncColors.primary(for: colorScheme))
                        }
                        .padding(14)
                        .background(VibeSyncColors.surfaceVariant(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tool_signature_manager")

                    Divider()

                    Text("PDF")
                        .vibeSyncStyle(.titleLarge)
                        .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))

                    Button {
                        isImportingPDF = true
                    } label: {
                        Label("Choose PDF", systemImage: "doc.badge.plus")
                            .font(VibeSyncTypography.labelLarge)
                            .lineSpacing(6)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VibeSyncColors.primary(for: colorScheme))

                    if let pageCount {
                        Text("\(pageCount) pages")
                            .vibeSyncStyle(.titleMedium)
                            .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                            .accessibilityIdentifier("pdf_page_count")
                    }

                    Button {
                        prepareExportCopy()
                    } label: {
                        Label("Export a copy", systemImage: "square.and.arrow.up")
                            .font(VibeSyncTypography.labelLarge)
                            .lineSpacing(6)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(VibeSyncColors.primary(for: colorScheme))
                    .disabled(selectedPDFData == nil || pageCount == nil)

                    Text(statusMessage)
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))

                    if let errorMessage {
                        Text(errorMessage)
                            .vibeSyncStyle(.bodyMedium)
                            .foregroundStyle(VibeSyncColors.dangerRed)
                    }
                }
                .padding(20)
            }
            .background(VibeSyncColors.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("VibeSync")
            .navigationBarTitleDisplayMode(.large)
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
                    statusMessage = "PDF copy saved successfully."
                    errorMessage = nil
                case .failure(let error):
                    statusMessage = "The PDF copy was not saved."
                    errorMessage = error.localizedDescription
                }
            }
        }
        .tint(VibeSyncColors.primary(for: colorScheme))
        .onAppear {
            IosPlatformProviders.shared.install()
            if ProcessInfo.processInfo.arguments.contains("--pdf-engine-smoke-test") {
                runPdfEngineSmokeTest()
            }
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
            statusMessage = "PDF loaded. You can export an unchanged copy."
            errorMessage = nil
        } catch {
            selectedPDFData = nil
            pageCount = nil
            statusMessage = "Choose a readable PDF to continue."
            errorMessage = error.localizedDescription
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
            errorMessage = "The PDF copy could not be prepared for export."
            return
        }

        do {
            let stagedData = try Data(contentsOf: stagedURL)
            exportDocument = PDFExportDocument(data: stagedData)
            exportFileName = (suggestedName as NSString).deletingPathExtension
            errorMessage = nil
            isExportingPDF = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
