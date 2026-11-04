import Foundation
import Shared
import SwiftUI
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

    @State private var isImportingPDF = false
    @State private var isExportingPDF = false
    @State private var selectedPDFData: Data?
    @State private var selectedPDFName = "document"
    @State private var pageCount: Int?
    @State private var exportDocument: PDFExportDocument?
    @State private var exportFileName = "document-copy"
    @State private var statusMessage = "Choose a PDF to view its page count."
    @State private var errorMessage: String?

    init() {
        IosPlatformProviders.shared.install()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.tint)

                Text("VibeSync All in ONE PDF Suite")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(sharedModuleStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("shared_module_status")

                Button {
                    isImportingPDF = true
                } label: {
                    Label("Choose PDF", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                if let pageCount {
                    Text("\(pageCount) pages")
                        .font(.headline)
                        .accessibilityIdentifier("pdf_page_count")
                }

                Button {
                    prepareExportCopy()
                } label: {
                    Label("Export a copy", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(selectedPDFData == nil || pageCount == nil)

                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("VibeSync")
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
            let count = Int(IosPlatformProviders.shared.pdfPageCount(data: data as NSData))
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
                data: selectedPDFData as NSData,
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
