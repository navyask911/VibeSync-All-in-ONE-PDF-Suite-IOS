import Foundation
import MLKitTranslate

enum MLKitTranslationError: LocalizedError {
    case unsupportedLanguage(String)
    case emptyInput
    case identicalLanguages
    case emptyTranslation

    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let code):
            return "The language code '\(code)' is not supported by ML Kit Translation."
        case .emptyInput:
            return "Enter or extract text before translating."
        case .identicalLanguages:
            return "Choose different source and target languages."
        case .emptyTranslation:
            return "ML Kit returned an empty translation."
        }
    }
}

/// Google ML Kit translation runs locally after its language models have been downloaded.
/// The first use needs a network connection; cellular downloads are disabled by default.
struct MLKitTranslationEngine {
    func translate(
        _ text: String,
        from sourceLanguageCode: String,
        to targetLanguageCode: String
    ) async throws -> String {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw MLKitTranslationError.emptyInput }
        guard sourceLanguageCode != targetLanguageCode else {
            throw MLKitTranslationError.identicalLanguages
        }
        guard
            let sourceLanguage = TranslateLanguage.fromLanguageTag(sourceLanguageCode),
            let targetLanguage = TranslateLanguage.fromLanguageTag(targetLanguageCode)
        else {
            let unsupported = TranslateLanguage.fromLanguageTag(sourceLanguageCode) == nil
                ? sourceLanguageCode
                : targetLanguageCode
            throw MLKitTranslationError.unsupportedLanguage(unsupported)
        }

        let options = TranslatorOptions(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        let translator = Translator.translator(options: options)
        let conditions = ModelDownloadConditions(
            allowsCellularAccess: false,
            allowsBackgroundDownloading: true
        )

        // Translation must wait until the source and target models are ready on-device.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            translator.downloadModelIfNeeded(with: conditions) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String, Error>) in
            translator.translate(input) { translatedText, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let translatedText,
                          !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(returning: translatedText)
                } else {
                    continuation.resume(throwing: MLKitTranslationError.emptyTranslation)
                }
            }
        }
    }
}
