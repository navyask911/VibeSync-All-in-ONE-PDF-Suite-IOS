import Combine
import Foundation
import Shared
import StoreKit

enum StoreKitBillingConstants {
    static let proPassProductID = "vibesync_pro_1y"
}

enum StoreKitBillingError: LocalizedError {
    case unverifiedTransaction(String)

    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction(let reason):
            return "The App Store transaction could not be verified: \(reason)"
        }
    }
}

@MainActor
final class StoreKitBillingProvider: NSObject, ObservableObject, BillingProvider {
    static let shared = StoreKitBillingProvider()

    @Published private(set) var product: Product?
    @Published private(set) var isProActive = false
    @Published private(set) var hasResolvedEntitlements = false
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage: String?

    private var didConfigure = false
    private var transactionUpdatesTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func configure() async {
        guard !didConfigure else {
            await refreshEntitlements()
            return
        }
        didConfigure = true
        isLoading = true
        defer { isLoading = false }

        do {
            product = try await Product.products(for: [StoreKitBillingConstants.proPassProductID]).first
            if product == nil {
                statusMessage = "VibeSync PDF Pro is not currently available in the App Store."
            }
        } catch {
            statusMessage = "Could not load the Pro Pass product: \(error.localizedDescription)"
        }

        await refreshEntitlements()
        startTransactionUpdates()
    }

    func refreshEntitlements() async {
        let activeProducts = await Self.currentEntitledProductIDs()
        isProActive = activeProducts.contains(StoreKitBillingConstants.proPassProductID)
        hasResolvedEntitlements = true
    }

    func purchaseProPass() async {
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        do {
            let completed = try await purchase(productId: StoreKitBillingConstants.proPassProductID)
            await refreshEntitlements()
            if completed.boolValue && isProActive {
                statusMessage = "VibeSync PDF Pro is active. Ads are removed."
            } else {
                statusMessage = "The purchase was cancelled or is awaiting App Store approval."
            }
        } catch {
            statusMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restoreProPass() async {
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        do {
            let restored = try await restorePurchases()
            await refreshEntitlements()
            statusMessage = restored.contains(StoreKitBillingConstants.proPassProductID) && isProActive
                ? "Your VibeSync PDF Pro subscription has been restored."
                : "No active VibeSync PDF Pro subscription was found for this Apple Account."
        } catch {
            statusMessage = "Could not restore purchases: \(error.localizedDescription)"
        }
    }

    nonisolated func isEntitled(productId: String) async throws -> KotlinBoolean {
        KotlinBoolean(bool: await Self.currentEntitledProductIDs().contains(productId))
    }

    nonisolated func purchase(productId: String) async throws -> KotlinBoolean {
        guard let product = try await Product.products(for: [productId]).first else {
            return KotlinBoolean(bool: false)
        }

        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try Self.verifiedTransaction(verification)
            await transaction.finish()
            await self.refreshEntitlements()
            return KotlinBoolean(bool: await self.isEntitled(productId: productId).boolValue)
        case .pending, .userCancelled:
            return KotlinBoolean(bool: false)
        @unknown default:
            return KotlinBoolean(bool: false)
        }
    }

    nonisolated func restorePurchases() async throws -> Set<String> {
        // AppStore.sync is called only after the customer explicitly taps Restore Purchases.
        try await AppStore.sync()
        let restored = await Self.currentEntitledProductIDs()
        await self.refreshEntitlements()
        return restored
    }

    private func startTransactionUpdates() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else {
                    continue
                }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    private nonisolated static func currentEntitledProductIDs() async -> Set<String> {
        var productIDs = Set<String>()
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else {
                continue
            }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }
            productIDs.insert(transaction.productID)
        }
        return productIDs
    }

    private nonisolated static func verifiedTransaction(
        _ result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw StoreKitBillingError.unverifiedTransaction(error.localizedDescription)
        }
    }
}
