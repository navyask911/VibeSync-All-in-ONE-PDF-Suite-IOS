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
    private var entitlementRefreshTask: Task<Set<String>, Never>?
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
        // ContentView can request a refresh from both onAppear and the scene-active
        // callback during launch. Share one StoreKit query across those callers:
        // overlapping Transaction.latest requests can stall the StoreKit test daemon
        // and leave the dashboard's entitlement gate unresolved.
        let refreshTask: Task<Set<String>, Never>
        let ownsRefreshTask: Bool
        if let inFlightTask = entitlementRefreshTask {
            refreshTask = inFlightTask
            ownsRefreshTask = false
        } else {
            let newTask = Task {
                await Self.currentEntitledProductIDs()
            }
            entitlementRefreshTask = newTask
            refreshTask = newTask
            ownsRefreshTask = true
        }

        let activeProducts = await refreshTask.value
        if ownsRefreshTask {
            entitlementRefreshTask = nil
        }
        isProActive = activeProducts.contains(StoreKitBillingConstants.proPassProductID)
        hasResolvedEntitlements = true
    }

    /// Resolves the isolated AdMob UI smoke test as a non-subscriber without
    /// asking StoreKit for entitlement data. This is test-only startup plumbing:
    /// normal launches and production purchase/restore flows still use StoreKit.
    func resolveNonProStateForAdMobSmokeTest() {
        isProActive = false
        hasResolvedEntitlements = true
    }

    func purchaseProPass() async {
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        do {
            let completed = try await purchase(productId: StoreKitBillingConstants.proPassProductID)
            // purchase(productId:) applies the entitlement from the verified
            // purchase transaction itself. Avoid immediately issuing a second
            // StoreKit entitlement query after a successful purchase.
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
            guard transaction.productID == productId else {
                await transaction.finish()
                return KotlinBoolean(bool: false)
            }
            let isActive = transaction.revocationDate == nil
                && (transaction.expirationDate.map { $0 > Date() } ?? true)
            await transaction.finish()
            await self.applyVerifiedPurchaseEntitlement(isActive: isActive)
            return KotlinBoolean(bool: isActive)
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

    @MainActor
    private func applyVerifiedPurchaseEntitlement(isActive: Bool) {
        isProActive = isActive
        hasResolvedEntitlements = true
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
        // This app sells one auto-renewable Pro Pass. Query its latest signed
        // transaction directly instead of draining the global currentEntitlements
        // sequence; the latter can remain suspended in the local StoreKit test
        // environment and prevent the dashboard from resolving its ad state.
        let productID = StoreKitBillingConstants.proPassProductID
        guard let verification = await Transaction.latest(for: productID) else {
            return []
        }
        guard case .verified(let transaction) = verification,
              transaction.productID == productID,
              transaction.revocationDate == nil else {
            return []
        }

        if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
            // A renewed subscription remains entitled while App Store reports
            // subscribed or in its billing grace period.
            guard let status = await transaction.subscriptionStatus,
                  status.state == .subscribed || status.state == .inGracePeriod else {
                return []
            }
        }

        return [productID]
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
