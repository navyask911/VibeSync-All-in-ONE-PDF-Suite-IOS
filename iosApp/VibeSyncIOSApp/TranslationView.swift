import PDFKit
import Shared
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private struct TranslationLanguage: Identifiable {
    let code: String
    let name: String
    var id: String { code }
}

struct TranslationView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let translator = IosMLKitTranslator()
    @State private var isImporting = false
    @State private var isProcessing = false
    @State private var isTranslating = false
    @State private var showModelConsent = false
    @State private var sourceLanguage = "auto"
    @State private var targetLanguage = "es"
    @State private var originalText = ""
    @State private var translatedText = ""
    @State private var selectedFileName = ""
    @State private var statusMessage = "Choose an image or PDF to extract text."
    @State private var errorMessage: String?

    private let languages: [TranslationLanguage] = [
        .init(code: "en", name: "English"), .init(code: "es", name: "Spanish"),
        .init(code: "de", name: "German"), .init(code: "fr", name: "French"),
        .init(code: "it", name: "Italian"), .init(code: "pt", name: "Portuguese"),
        .init(code: "ru", name: "Russian"), .init(code: "zh", name: "Chinese"),
        .init(code: "ja", name: "Japanese"), .init(code: "ko", name: "Korean"),
        .init(code: "ar", name: "Arabic"), .init(code: "he", name: "Hebrew"),
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Extract text from photos and PDF pages with Apple Vision, then translate it on-device.")
                    .vibeSyncStyle(.bodyMedium)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))

                Button {
                    isImporting = true
                } label: {
                    Label("Choose image or PDF", systemImage: "doc.viewfinder")
                        .font(VibeSyncTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(VibeSyncColors.primary(for: colorScheme))
                .disabled(isProcessing || isTranslating)
                .accessibilityIdentifier("translation_import_button")

                if !selectedFileName.isEmpty {
                    Label(selectedFileName, systemImage: "doc.text")
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("From")
                            .vibeSyncStyle(.labelLarge)
                            .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                        Picker("Source language", selection: $sourceLanguage) {
                            Text("Auto-detect").tag("auto")
                            ForEach(languages) { language in
                                Text(language.name).tag(language.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("translation_source_picker")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .foregroundStyle(VibeSyncColors.secondary(for: colorScheme))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("To")
                            .vibeSyncStyle(.labelLarge)
                            .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                        Picker("Target language", selection: $targetLanguage) {
                            ForEach(languages) { language in
                                Text(language.name).tag(language.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("translation_target_picker")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(VibeSyncColors.surfaceVariant(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Extracted text")
                        .vibeSyncStyle(.titleMedium)
                        .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                    TextEditor(text: $originalText)
                        .frame(minHeight: 150)
                        .padding(6)
                        .background(VibeSyncColors.surface(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("translation_original_text")
                }

                Button {
                    showModelConsent = true
                } label: {
                    HStack {
                        if isProcessing || isTranslating {
                            ProgressView().tint(VibeSyncColors.white)
                        } else {
                            Image(systemName: "translate")
                        }
                        Text(isTranslating ? "Translating…" : "Translate")
                            .font(VibeSyncTypography.labelLarge)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(VibeSyncColors.primary(for: colorScheme))
                .disabled(originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          sourceLanguage == targetLanguage || isProcessing || isTranslating)
                .accessibilityIdentifier("translation_run")

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Translation")
                            .vibeSyncStyle(.titleMedium)
                            .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                        Spacer()
                        Button {
                            UIPasteboard.general.string = translatedText
                            statusMessage = "Translation copied."
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(VibeSyncTypography.labelLarge)
                        }
                        .disabled(translatedText.isEmpty)
                    }
                    TextEditor(text: $translatedText)
                        .frame(minHeight: 150)
                        .padding(6)
                        .background(VibeSyncColors.surface(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("translation_result_text")
                }

                Text(statusMessage)
                    .vibeSyncStyle(.bodyMedium)
                    .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                    .accessibilityIdentifier("translation_status")

                if let errorMessage {
                    Text(errorMessage)
                        .vibeSyncStyle(.bodyMedium)
                        .foregroundStyle(VibeSyncColors.dangerRed)
                }
            }
            .padding(16)
        }
        .background(VibeSyncColors.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle("OCR & Translate")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            importDocument(result)
        }
        .alert("Download translation models?", isPresented: $showModelConsent) {
            Button("Download & translate") {
                Task { await translateText() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Google ML Kit translates on this device. It may download language models of about 30 MB each. Downloads are restricted to Wi-Fi. Once downloaded, translation works offline.")
        }
    }

    private func importDocument(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasScope { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            let isPDF = url.pathExtension.lowercased() == "pdf"
            selectedFileName = url.lastPathComponent
            originalText = ""
            translatedText = ""
            errorMessage = nil
            isProcessing = true
            statusMessage = "Recognizing text with Apple Vision…"

            Task {
                do {
                    let recognized = try await recognize(data: data, isPDF: isPDF)
                    originalText = recognized
                    statusMessage = recognized.isEmpty
                        ? "No readable text was found in the selected file."
                        : "Text extraction complete. Review the text, then translate."
                    if recognized.isEmpty {
                        errorMessage = "Try a sharper image or a PDF with a higher-resolution scan."
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    statusMessage = "Text extraction failed."
                }
                isProcessing = false
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "The selected file could not be opened."
        }
    }

    private func recognize(data: Data, isPDF: Bool) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            if isPDF {
                guard let document = PDFDocument(data: data), document.pageCount > 0 else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                guard !document.isLocked else {
                    throw NSError(
                        domain: "VibeSyncOCR",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Unlock this password-protected PDF before OCR."]
                    )
                }

                var pageTexts: [String] = []
                for index in 0..<document.pageCount {
                    guard let page = document.page(at: index) else { continue }
                    let bounds = page.bounds(for: .mediaBox).standardized
                    let scale = min(2.0, 1800.0 / max(bounds.width, 1), 2400.0 / max(bounds.height, 1))
                    let image = page.thumbnail(
                        of: CGSize(width: bounds.width * scale, height: bounds.height * scale),
                        for: .mediaBox
                    )
                    guard let imageData = image.pngData() else { continue }
                    let text = IosPlatformProviders.shared.recognizeText(
                        data: imageData as NSData,
                        languageTag: nil
                    )
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        pageTexts.append(text)
                    }
                }
                return pageTexts.joined(separator: "\n\n")
            }

            guard let image = UIImage(data: data), let imageData = image.pngData() else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return IosPlatformProviders.shared.recognizeText(
                data: imageData as NSData,
                languageTag: nil
            )
        }.value
    }

    @MainActor
    private func translateText() async {
        let text = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "Extract or enter text before translating."
            return
        }
        isTranslating = true
        errorMessage = nil
        statusMessage = "Preparing on-device language models…"
        do {
            let source = sourceLanguage == "auto" ? nil : sourceLanguage
            translatedText = try await translator.translate(
                text: text,
                sourceLanguageCode: source,
                targetLanguageCode: targetLanguage
            )
            statusMessage = "Translation complete. Your text stayed on this device."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Translation failed. Connect to Wi-Fi to download missing models."
        }
        isTranslating = false
    }
}
