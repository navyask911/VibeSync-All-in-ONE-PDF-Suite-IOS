import Foundation
import Security
import UIKit

/// Stores signature PNG data as Keychain generic-password items.
/// The account field is the signature identifier; the Keychain label is the
/// human-readable identifier shown in the manager. Data is protected by the
/// device Keychain and never written to an unencrypted file.
final class SignatureVault {
    struct SavedSignature: Identifiable, Equatable {
        let id: String
    }

    enum VaultError: LocalizedError {
        case emptyIdentifier
        case duplicateIdentifier
        case keychain(OSStatus)
        case imageEncodingFailed

        var errorDescription: String? {
            switch self {
            case .emptyIdentifier:
                return "Enter a non-empty signature name."
            case .duplicateIdentifier:
                return "A signature with that name already exists."
            case .keychain(let status):
                return "The secure signature vault failed (Keychain status \(status))."
            case .imageEncodingFailed:
                return "The signature image could not be encoded."
            }
        }
    }

    private let service = "com.vibesync.toolkit.pdf.signatures"
    private let accountPrefix = "signature."

    func saveSignature(_ image: UIImage, named identifier: String) throws {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw VaultError.emptyIdentifier }
        guard let pngData = image.pngData() else { throw VaultError.imageEncodingFailed }

        var item = baseQuery(account: account(for: normalized))
        item[kSecAttrLabel as String] = normalized
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        item[kSecValueData as String] = pngData

        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem {
            throw VaultError.duplicateIdentifier
        }
        guard status == errSecSuccess else {
            throw VaultError.keychain(status)
        }
    }

    func loadSignature(named identifier: String) throws -> UIImage? {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        var query = baseQuery(account: account(for: normalized))
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
        guard let data = result as? Data else { return nil }
        return UIImage(data: data)
    }

    /// Lists identifiers and Keychain labels only; encrypted image bytes are not returned.
    func listSignatures() throws -> [SavedSignature] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw VaultError.keychain(status) }

        let items = result as? [[String: Any]] ?? []
        return items.compactMap { item in
            guard
                let account = item[kSecAttrAccount as String] as? String,
                account.hasPrefix(accountPrefix)
            else { return nil }
            let identifier = String(account.dropFirst(accountPrefix.count))
            guard !identifier.isEmpty else { return nil }
            return SavedSignature(id: identifier)
        }
        .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    /// Renames the Keychain account and label without moving or exposing the PNG payload.
    @discardableResult
    func renameSignature(from oldIdentifier: String, to newIdentifier: String) throws -> Bool {
        let oldName = oldIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let newName = newIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldName.isEmpty, !newName.isEmpty, oldName != newName else { return false }

        let oldQuery = baseQuery(account: account(for: oldName))
        let newQuery = baseQuery(account: account(for: newName))
        if itemExists(query: newQuery) { return false }

        let attributes: [String: Any] = [
            kSecAttrAccount as String: account(for: newName),
            kSecAttrLabel as String: newName,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(oldQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound || status == errSecDuplicateItem { return false }
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
        return true
    }

    @discardableResult
    func deleteSignature(named identifier: String) throws -> Bool {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let status = SecItemDelete(baseQuery(account: account(for: normalized)) as CFDictionary)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
        return true
    }

    private func account(for identifier: String) -> String {
        accountPrefix + identifier
    }

    // The app's default access group is granted by VibeSyncIOS.entitlements.
    // Accessibility is an item attribute (set on add/update), not a SecItemCopyMatching
    // search predicate; lookups therefore inherit the stored item's access policy.
    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func itemExists(query: [String: Any]) -> Bool {
        var lookup = query
        lookup[kSecReturnAttributes as String] = false
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(lookup as CFDictionary, nil) == errSecSuccess
    }
}
