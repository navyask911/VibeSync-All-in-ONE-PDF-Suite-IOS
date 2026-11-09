import PDFKit
import PhotosUI
import Shared
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct TranslationLanguageOption: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let all: [TranslationLanguageOption] = [
        .init(code: "en", name: "English"), .init(code: "es", name: "Spanish"),
        .init(code: "de", name: "German"), .init(code: "fr", name: "French"),
        .init(code: "it", name: "Italian"), .init(code: "pt", name: "Portuguese"),
        .init(code: "ru", name: "Russian"), .init(code: "zh", name: "Chinese"),
        .init(code: "ja", name: "Japanese"), .init(code: "ko", name: "Korean"),
        .init(code: "ar", name: "Arabic"), .init(code: "iw", name: "Hebrew"),
        .init(code: "hi", name: "Hindi"), .init(code: "bn", name: "Bengali"),
        .init(code: "ur", name: "Urdu"), .init(code: "tr", name: "Turkish"),
        .init(code: "vi", name: "Vietnamese"), .init(code: "th", name: "Thai"),
        .init(code: "id", name: "Indonesian"), .init(code: "nl", name: "Dutch"),
        .init(code: "pl", name: "Polish"), .init(code: "fa", name: "Persian"),
        .init(code: "el", name: "Greek"), .init(code: "cs", name: "Czech"),
        .init(code: "sv", name: "Swedish"), .init(code: "ta", name: "Tamil"),
        .init(code: "te", name: "Telugu"), .init(code: "mr", name: "Marathi"),
        .init(code: "gu", name: "Gujarati"), .init(code: "kn", name: "Kannada"),
        .init(code: "ro", name: "Romanian"), .init(code: "uk", name: "Ukrainian"),
        .init(code: "sw", name: "Swahili"), .init(code: "tl", name: "Filipino")
    ]
}

struct TranslationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("vibesync.translation.model-download-consent")
    private var hasModelDownloadConsent = false

    @State private var originalText = ""
    @State private var translatedText = ""
    @State private var sourceLanguageCode = "auto"
    @State private var targetLanguageCode = "es"
    @State private var isProcessing = false
    @State private var statusMessage = "Import a PDF or enter text to translate on this device."
    @State private var isShowingPDFImporter = false
    @State private var isShowingCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingModelConsent = false
    @State private var isExportingFile = false
    @State private var exportDocument: TranslationFileDocument?
    @State private var exportContentType: UTType = .plainText
    @State private var exportFileName = "translated_text"
    @State private var stagedExportURL: URL?
    @State private var isShowingShareSheet = false
    @State private var shareExportURL: URL?
    @State private var pageProgress = ""
    @State private var extractionWarning: String?

    private let translator = MLKitTranslationEngine()

    private var sourceOptions: [TranslationLanguageOption] {
        [TranslationLanguageOption(code: "auto", name: "Auto detect")] + TranslationLanguageOption.all
    }

    private var sourceLanguageName: String {
        sourceOptions.first { $0.code == sourceLanguageCode }?.name ?? sourceLanguageCode
    }
    private var targetLanguageName: String {
        TranslationLanguageOption.all.first { $0.code == targetLanguageCode }?.name ?? targetLanguageCode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introduction
                pdfImportSection
                imageImportSection
                languageSelection
                originalTextSection

                Button(action: requestTranslation) {
                    HStack(spacing: 9) {
                        if isProcessing {
                            ProgressView().tint(VibeSyncColors.white)
                        } else {
                            Image(systemName: "translate")
                        }
                        Text(isProcessing ? "Preparing on-device translation…" : "Translate on device")
                    }
                    .font(VibeSyncTypography.labelLarge)
                    .foregroundStyle(VibeSyncColors.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VibeSyncColors.crimsonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(
                    isProcessing ||
                    originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    sourceLanguageCode == targetLanguageCode
                )
                .accessibilityIdentifier("translation_translate_button")

                if isProcessing {
                    HStack(spacing: 10) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pageProgress.isEmpty ? "Preparing language models on this device…" : pageProgress)
                                .font(VibeSyncTypography.bodyMedium.weight(.semibold))
                            Text("The first model download needs Wi-Fi. Your text is translated on-device.")
                                .font(VibeSyncTypography.bodyMedium)
                                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VibeSyncColors.surfaceVariant(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("translation_progress")
                }

                if !translatedText.isEmpty {
                    translatedResultSection
                }
                if let extractionWarning {
                    Text(extractionWarning)
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.warningAmber)
                }
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                        .accessibilityIdentifier("translation_status")
                }
            }
            .padding(16)
        }
        .background(VibeSyncColors.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Scan & Translate")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isShowingPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            importPDF(result)
        }
        .alert("Download on-device language models?", isPresented: $isShowingModelConsent) {
            Button("Continue", action: acceptModelDownload)
                .accessibilityIdentifier("translation_model_continue")
            Button("Not now", role: .cancel) {
                statusMessage = "Model download cancelled. No text was uploaded."
            }
            .accessibilityIdentifier("translation_model_cancel")
        } message: {
            Text("The first translation downloads the \(sourceLanguageName) and \(targetLanguageName) language models over Wi-Fi (about 30 MB each). After download, translation runs on this device.")
        }
        .onChange(of: selectedPhoto) { item in
            guard let item else { return }
            Task { await importGalleryImage(item) }
        }
        .sheet(isPresented: $isShowingCamera) {
            TranslationCameraCaptureView(
                onImageCaptured: { image in
                    isShowingCamera = false
                    recognizeImage(image, sourceDescription: "Camera image")
                },
                onCancel: {
                    isShowingCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingShareSheet, onDismiss: cleanupShareExport) {
            if let shareExportURL {
                TranslationShareSheet(activityItems: [shareExportURL])
            }
        }
        .fileExporter(
            isPresented: $isExportingFile,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                statusMessage = "Translation file saved successfully."
            case .failure(let error):
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
            cleanupStagedExport()
        }
        .tint(VibeSyncColors.primary(for: colorScheme))
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Translate scanned documents")
                .vibeSyncStyle(.titleLarge)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
            Text("Import a PDF or image to extract text with Vision OCR, or type/paste text below. Choose languages and translate privately on this device.")
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
        }
    }

    private var pdfImportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Extract text from PDF", systemImage: "doc.text.viewfinder")
                .font(VibeSyncTypography.titleMedium)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
            Text("Digital text is read directly. Image-only scanned pages are processed with the existing Vision OCR engine.")
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
            Button {
                isShowingPDFImporter = true
            } label: {
                Label("Import PDF", systemImage: "doc.badge.plus")
                    .font(VibeSyncTypography.labelLarge)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(VibeSyncColors.primary(for: colorScheme))
            .accessibilityIdentifier("translation_import_button")
        }
        .padding(14)
        .background(VibeSyncColors.surfaceVariant(for: colorScheme).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var imageImportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Scan an image", systemImage: "text.viewfinder")
                .font(VibeSyncTypography.titleMedium)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
            HStack(spacing: 10) {
                Button {
                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                        statusMessage = "Camera is unavailable on this device. Choose Photo Library instead."
                        return
                    }
                    isShowingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .font(VibeSyncTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.bordered)
                .tint(VibeSyncColors.primary(for: colorScheme))
                .disabled(isProcessing || !UIImagePickerController.isSourceTypeAvailable(.camera))
                .accessibilityIdentifier("translation_camera_button")

                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .font(VibeSyncTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.bordered)
                .tint(VibeSyncColors.primary(for: colorScheme))
                .disabled(isProcessing)
                .accessibilityIdentifier("translation_photo_library_button")
            }
            Text("Camera and selected photos are processed with on-device Vision OCR before text is added below.")
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
        }
        .padding(14)
        .background(VibeSyncColors.surfaceVariant(for: colorScheme).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var languageSelection: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text("From")
                    .vibeSyncStyle(.labelLarge)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                Picker("Source language", selection: $sourceLanguageCode) {
                    ForEach(sourceOptions) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VibeSyncColors.surfaceVariant(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityIdentifier("translation_source_picker")
            }

            Button {
                let previousSource = sourceLanguageCode
                sourceLanguageCode = targetLanguageCode
                targetLanguageCode = previousSource
                translatedText = ""
                statusMessage = "Languages changed."
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 42)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Swap languages")
            .accessibilityIdentifier("translation_swap_languages")

            VStack(alignment: .leading, spacing: 5) {
                Text("To")
                    .vibeSyncStyle(.labelLarge)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                Picker("Target language", selection: $targetLanguageCode) {
                    ForEach(TranslationLanguageOption.all) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VibeSyncColors.surfaceVariant(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityIdentifier("translation_target_picker")
            }
        }
    }

    private var originalTextSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Original text")
                    .vibeSyncStyle(.titleMedium)
                    .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                Spacer()
                Button("Clear") {
                    originalText = ""
                    translatedText = ""
                    extractionWarning = nil
                    statusMessage = "Text cleared."
                }
                .font(VibeSyncTypography.labelLarge)
                .disabled(originalText.isEmpty)
                .accessibilityIdentifier("translation_clear_text")
            }

            ZStack(alignment: .topLeading) {
                if originalText.isEmpty {
                    Text("Type or paste text here, or import a PDF above…")
                        .font(VibeSyncTypography.bodyLarge)
                        .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme).opacity(0.75))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $originalText)
                    .font(VibeSyncTypography.bodyLarge)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .accessibilityIdentifier("translation_original_input")
            }
            .frame(minHeight: 150)
            .background(VibeSyncColors.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(VibeSyncColors.secondary(for: colorScheme).opacity(0.22), lineWidth: 1)
            }
        }
    }

    private var translatedResultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Translation")
                    .vibeSyncStyle(.titleMedium)
                    .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                Spacer()
                Menu {
                    Section("Save a copy") {
                        Button {
                            prepareExport(format: .text, destination: .save)
                        } label: {
                            Label("Export TXT", systemImage: "doc.text")
                        }
                        .accessibilityIdentifier("translation_export_txt")

                        Button {
                            prepareExport(format: .pdf, destination: .save)
                        } label: {
                            Label("Export PDF", systemImage: "doc.richtext")
                        }
                        .accessibilityIdentifier("translation_export_pdf")
                    }

                    Section("Share file") {
                        Button {
                            prepareExport(format: .text, destination: .share)
                        } label: {
                            Label("Share TXT", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("translation_share_txt")

                        Button {
                            prepareExport(format: .pdf, destination: .share)
                        } label: {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("translation_share_pdf")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(VibeSyncTypography.labelLarge)
                }
                .accessibilityIdentifier("translation_export_menu")
            }
            Text("\(sourceLanguageName) → \(targetLanguageName)")
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
            Text(translatedText)
                .font(VibeSyncTypography.bodyLarge)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                .padding(12)
                .background(VibeSyncColors.surface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("translation_result_text")
        }
        .padding(14)
        .background(VibeSyncColors.surfaceVariant(for: colorScheme).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func requestTranslation() {
        guard !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Enter text or import a PDF first."
            return
        }
        guard sourceLanguageCode != targetLanguageCode else {
            statusMessage = "Choose different source and target languages."
            return
        }
        if hasModelDownloadConsent {
            translateNow()
        } else {
            isShowingModelConsent = true
        }
    }

    private func acceptModelDownload() {
        hasModelDownloadConsent = true
        translateNow()
    }

    private func translateNow() {
        let input = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sourceLanguageCode == "auto"
            ? Self.detectSourceLanguage(in: input)
            : sourceLanguageCode
        let target = targetLanguageCode
        translatedText = ""
        isProcessing = true
        extractionWarning = nil
        pageProgress = "Preparing the offline language models…"
        statusMessage = "Downloading models if needed, then translating on-device."

        Task { @MainActor in
            do {
                translatedText = try await translator.translate(input, from: source, to: target)
                statusMessage = "Translation complete. Your text was processed on this device."
            } catch {
                statusMessage = error.localizedDescription
            }
            pageProgress = ""
            isProcessing = false
        }
    }

    /// Lightweight script detection mirrors the Android translation flow. Languages sharing
    /// a script can still be selected explicitly in the source picker for better accuracy.
    private static func detectSourceLanguage(in text: String) -> String {
        let scalars = text.unicodeScalars
        func contains(_ range: ClosedRange<UInt32>) -> Bool {
            scalars.contains { range.contains($0.value) }
        }
        if contains(0x0600...0x06FF) { return "ar" }
        if contains(0x0590...0x05FF) { return "iw" }
        if contains(0x0C80...0x0CFF) { return "kn" }
        if contains(0x0B80...0x0BFF) { return "ta" }
        if contains(0x0C00...0x0C7F) { return "te" }
        if contains(0x0A80...0x0AFF) { return "gu" }
        if contains(0x0980...0x09FF) { return "bn" }
        if contains(0x0900...0x097F) { return "hi" }
        if contains(0x3040...0x30FF) { return "ja" }
        if contains(0xAC00...0xD7AF) { return "ko" }
        if contains(0x4E00...0x9FFF) { return "zh" }
        return "en"
    }

    private func recognizeImage(_ image: UIImage, sourceDescription: String) {
        isProcessing = true
        translatedText = ""
        extractionWarning = nil
        pageProgress = "Recognizing text in image…"
        statusMessage = "Running Vision OCR on the selected image."

        Task { @MainActor in
            defer {
                pageProgress = ""
                isProcessing = false
            }
            do {
                let observations = try await OcrEngine.recognize(image: image)
                let recognizedText = observations
                    .sorted { $0.normalizedBounds.midY > $1.normalizedBounds.midY }
                    .map(\.text)
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !recognizedText.isEmpty else {
                    throw NSError(
                        domain: "VibeSyncTranslationOCR",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No readable text was found in the selected image."]
                    )
                }
                originalText = recognizedText
                sourceLanguageCode = "auto"
                statusMessage = "Text extracted from \(sourceDescription). Review it below, then tap Translate."
            } catch {
                statusMessage = "Image OCR failed: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func importGalleryImage(_ item: PhotosPickerItem) async {
        defer { selectedPhoto = nil }
        isProcessing = true
        translatedText = ""
        extractionWarning = nil
        pageProgress = "Loading selected photo…"
        statusMessage = "Opening the selected photo."

        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                throw CocoaError(.fileReadCorruptFile)
            }
            recognizeImage(image, sourceDescription: "Photo Library image")
        } catch {
            isProcessing = false
            pageProgress = ""
            statusMessage = "Could not load the selected image: \(error.localizedDescription)"
        }
    }

    private func prepareExport(format: TranslationExportFormat, destination: TranslationExportDestination) {
        do {
            let data = try TranslationExportFactory.makeData(for: translatedText, format: format)
            guard
                let stagedURI = IosPlatformProviders.shared.stageExportCopy(
                    data: data,
                    suggestedFileName: format.fileName
                ),
                let stagedURL = URL(string: stagedURI),
                stagedURL.isFileURL
            else {
                throw CocoaError(.fileWriteUnknown)
            }

            switch destination {
            case .save:
                let stagedData = try Data(contentsOf: stagedURL)
                stagedExportURL = stagedURL
                exportDocument = TranslationFileDocument(data: stagedData)
                exportContentType = format.contentType
                exportFileName = format.fileNameWithoutExtension
                isExportingFile = true
            case .share:
                shareExportURL = stagedURL
                isShowingShareSheet = true
            }
            statusMessage = "Prepared \(format.fileName) for \(destination == .save ? "saving" : "sharing")."
        } catch {
            statusMessage = "Could not prepare the export: \(error.localizedDescription)"
        }
    }

    private func cleanupStagedExport() {
        if let stagedExportURL {
            try? FileManager.default.removeItem(at: stagedExportURL)
            self.stagedExportURL = nil
        }
        exportDocument = nil
    }

    private func cleanupShareExport() {
        if let shareExportURL {
            try? FileManager.default.removeItem(at: shareExportURL)
            self.shareExportURL = nil
        }
    }

    private func importPDF(_ result: Result<[URL], Error>) {
        Task { @MainActor in
            isProcessing = true
            translatedText = ""
            extractionWarning = nil
            statusMessage = "Opening PDF…"
            do {
                guard let url = try result.get().first else {
                    isProcessing = false
                    statusMessage = "No PDF was selected."
                    return
                }
                let hasSecurityScope = url.startAccessingSecurityScopedResource()
                defer {
                    if hasSecurityScope { url.stopAccessingSecurityScopedResource() }
                }

                let data = try Data(contentsOf: url)
                guard let document = PDFDocument(data: data), document.pageCount > 0 else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                guard !document.isLocked else {
                    throw NSError(
                        domain: "VibeSyncTranslation",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unlock this password-protected PDF before extracting text."]
                    )
                }

                var pageTexts: [String] = []
                var warnings = 0
                for pageIndex in 0..<document.pageCount {
                    guard let page = document.page(at: pageIndex) else { continue }
                    pageProgress = "Reading page \(pageIndex + 1) of \(document.pageCount)…"
                    let embeddedText = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !embeddedText.isEmpty {
                        pageTexts.append(embeddedText)
                    } else {
                        do {
                            let observations = try await OcrEngine.recognize(page: page)
                            let recognized = observations
                                .sorted { $0.normalizedBounds.midY > $1.normalizedBounds.midY }
                                .map(\.text)
                                .joined(separator: "\n")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !recognized.isEmpty { pageTexts.append(recognized) }
                        } catch {
                            warnings += 1
                        }
                    }
                }

                originalText = pageTexts.joined(separator: "\n\n")
                guard !originalText.isEmpty else {
                    throw NSError(
                        domain: "VibeSyncTranslation",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No selectable text or recognizable scanned text was found in this PDF."]
                    )
                }
                if warnings > 0 {
                    extractionWarning = "\(warnings) page(s) could not be read by OCR."
                }
                statusMessage = "Text extracted from \(pageTexts.count) page(s)."
                pageProgress = ""
                isProcessing = false
                requestTranslation()
            } catch {
                pageProgress = ""
                isProcessing = false
                statusMessage = error.localizedDescription
            }
        }
    }
}


enum TranslationExportFormat {
    case text
    case pdf

    var fileName: String {
        switch self {
        case .text: return "translated_text.txt"
        case .pdf: return "translated_text.pdf"
        }
    }

    var fileNameWithoutExtension: String {
        switch self {
        case .text: return "translated_text"
        case .pdf: return "translated_text"
        }
    }

    var contentType: UTType {
        switch self {
        case .text: return .plainText
        case .pdf: return .pdf
        }
    }

    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .pdf: return "pdf"
        }
    }
}

enum TranslationExportDestination: Equatable {
    case save
    case share
}

enum TranslationExportFactory {
    static func makeData(for text: String, format: TranslationExportFormat) throws -> Data {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        switch format {
        case .text:
            return Data(text.utf8)
        case .pdf:
            return makePDFData(for: text)
        }
    }

    static func writeTemporaryFile(data: Data, fileExtension: String) throws -> URL {
        guard !data.isEmpty, ["txt", "pdf"].contains(fileExtension) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VibeSync-translation-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func makePDFData(for text: String) -> Data {
        let pageBounds = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let font = UIFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        let margin: CGFloat = 42
        let lineHeight = font.lineHeight * 1.45
        let availableWidth = pageBounds.width - margin * 2
        let lines = wrappedLines(text, font: font, width: availableWidth)
        let linesPerPage = max(1, Int((pageBounds.height - margin * 2) / lineHeight))

        return renderer.pdfData { context in
            for pageStart in stride(from: 0, to: lines.count, by: linesPerPage) {
                context.beginPage()
                let pageEnd = min(pageStart + linesPerPage, lines.count)
                var y = margin
                for lineIndex in pageStart..<pageEnd {
                    (lines[lineIndex] as NSString).draw(
                        at: CGPoint(x: margin, y: y),
                        withAttributes: attributes
                    )
                    y += lineHeight
                }
            }
        }
    }

    private static func wrappedLines(_ text: String, font: UIFont, width: CGFloat) -> [String] {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var lines: [String] = []

        for paragraph in text.components(separatedBy: .newlines) {
            if paragraph.isEmpty {
                lines.append("")
                continue
            }

            var currentLine = ""
            let words = paragraph.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for word in words {
                let candidate = currentLine.isEmpty ? word : "\(currentLine) \(word)"
                let candidateWidth = (candidate as NSString).size(withAttributes: attributes).width
                if candidateWidth <= width {
                    currentLine = candidate
                    continue
                }

                if !currentLine.isEmpty {
                    lines.append(currentLine)
                    currentLine = ""
                }

                for character in word {
                    let characterText = String(character)
                    let next = currentLine + characterText
                    let nextWidth = (next as NSString).size(withAttributes: attributes).width
                    if nextWidth > width, !currentLine.isEmpty {
                        lines.append(currentLine)
                        currentLine = characterText
                    } else {
                        currentLine = next
                    }
                }
            }
            if !currentLine.isEmpty {
                lines.append(currentLine)
            }
        }

        return lines.isEmpty ? [""] : lines
    }
}

private struct TranslationFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .pdf] }

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

private struct TranslationCameraCaptureView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImageCaptured: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onImageCaptured: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImageCaptured = onImageCaptured
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }
            onImageCaptured(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

private struct TranslationShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
