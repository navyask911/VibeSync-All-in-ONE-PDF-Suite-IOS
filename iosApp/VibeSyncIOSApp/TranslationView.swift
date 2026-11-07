import PDFKit
import SwiftUI
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
    @State private var isShowingModelConsent = false
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
        .navigationTitle("Translation Scan")
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
        .tint(VibeSyncColors.primary(for: colorScheme))
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Translate scanned documents")
                .vibeSyncStyle(.titleLarge)
                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
            Text("Import a PDF to extract its text with Vision OCR, or type/paste text below. Choose languages and translate privately on this device.")
                .vibeSyncStyle(.bodyMedium)
                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
        }
    }

    private var pdfImportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Extract text from PDF", systemImage: "doc.text.viewfinder")
                .vibeSyncStyle(.titleMedium)
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
                ShareLink(item: translatedText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(VibeSyncTypography.labelLarge)
                }
                .accessibilityIdentifier("translation_share_result")
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

    private func importPDF(_ result: Result<URL, Error>) {
        Task { @MainActor in
            isProcessing = true
            translatedText = ""
            extractionWarning = nil
            statusMessage = "Opening PDF…"
            do {
                let url = try result.get()
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
