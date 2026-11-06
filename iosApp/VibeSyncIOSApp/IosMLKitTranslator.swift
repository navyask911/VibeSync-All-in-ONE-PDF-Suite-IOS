import Foundation
import NaturalLanguage
import MLKitTranslate

/// On-device Google ML Kit translator. The caller presents its model-download disclosure
/// before invoking this method; downloads are restricted to Wi-Fi.
final class IosMLKitTranslator {
    enum TranslationError: LocalizedError {
        case emptyText
        case unsupportedLanguage(String)
        case sameLanguage
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .emptyText:
                return "Enter or recognize text before translating."
            case .unsupportedLanguage(let code):
                return "ML Kit does not support the language code \(code)."
            case .sameLanguage:
                return "Choose different source and target languages."
            case .emptyResult:
                return "ML Kit returned an empty translation."
            }
        }
    }

    func translate(
        text: String,
        sourceLanguageCode: String?,
        targetLanguageCode: String
    ) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { throw TranslationError.emptyText }

        let sourceTag = Self.mlKitLanguageTag(sourceLanguageCode ?? Self.detectLanguage(in: trimmedText))
        let targetTag = Self.mlKitLanguageTag(targetLanguageCode)
        guard
            let source = TranslateLanguage.fromLanguageTag(sourceTag),
            let target = TranslateLanguage.fromLanguageTag(targetTag)
        else {
            let invalid = TranslateLanguage.fromLanguageTag(sourceTag) == nil ? sourceTag : targetTag
            throw TranslationError.unsupportedLanguage(invalid)
        }
        guard source != target else { throw TranslationError.sameLanguage }

        let options = TranslatorOptions(sourceLanguage: source, targetLanguage: target)
        let translator = Translator.translator(options: options)
        let conditions = ModelDownloadConditions(
            allowsCellularAccess: false,
            allowsBackgroundDownloading: true
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            translator.downloadModelIfNeeded(with: conditions) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        let translated = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            translator.translate(trimmedText) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(throwing: TranslationError.emptyResult)
                }
            }
        }
        return translated
    }

    static func detectLanguage(in text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "en"
    }

    private static func mlKitLanguageTag(_ tag: String) -> String {
        let normalized = tag.replacingOccurrences(of: "_", with: "-").lowercased()
        switch normalized {
        case "iw", "iw-il": return "he"
        case "he", "he-il": return "he"
        case "fil", "tl-ph": return "tl"
        case "zh-cn", "zh-sg", "zh-hans": return "zh"
        case "zh-tw", "zh-hk", "zh-hant": return "zh"
        default:
            return normalized.split(separator: "-").first.map(String.init) ?? normalized
        }
    }
}
