import Foundation
import GoogleMobileAds
import Shared
import SwiftUI
import UIKit

enum AdMobConfiguration {
    static var applicationID: String {
        Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
    }

    static var bannerUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_AD_UNIT_ID") as? String ?? ""
    }

    static var interstitialUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "ADMOB_INTERSTITIAL_AD_UNIT_ID") as? String ?? ""
    }

    static func isConfigured(_ value: String) -> Bool {
        value.hasPrefix("ca-app-pub-") && !value.contains("REPLACE_WITH")
    }

    static var hasBannerUnitID: Bool { isConfigured(bannerUnitID) }
}

@MainActor
final class AdMobProvider: NSObject, ObservableObject, AdProvider {
    static let shared = AdMobProvider()

    @Published private(set) var isInitialized = false

    private override init() {
        super.init()
    }

    func initialize() async -> Bool {
        guard AdMobConfiguration.isConfigured(AdMobConfiguration.applicationID) else {
            return KotlinBoolean(bool: false)
        }
        guard !isInitialized else { return KotlinBoolean(bool: true) }

        MobileAds.shared.start()
        isInitialized = true
        return KotlinBoolean(bool: true)
    }

    nonisolated func showInterstitial(placementId: String) async throws -> KotlinBoolean {
        let proIsActive = await MainActor.run {
            StoreKitBillingProvider.shared.isProActive
        }
        let sdkIsInitialized = await MainActor.run {
            AdMobProvider.shared.isInitialized
        }
        guard !proIsActive, sdkIsInitialized else {
            return KotlinBoolean(bool: false)
        }

        let unitID = AdMobConfiguration.isConfigured(placementId)
            ? placementId
            : AdMobConfiguration.interstitialUnitID
        guard AdMobConfiguration.isConfigured(unitID) else {
            return KotlinBoolean(bool: false)
        }

        let ad = try await InterstitialAd.load(with: unitID, request: Request())
        guard let viewController = await MainActor.run(body: { Self.topViewController() }) else {
            return KotlinBoolean(bool: false)
        }
        await MainActor.run {
            ad.present(from: viewController)
        }
        return KotlinBoolean(bool: true)
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var current = root
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }
}

struct AdMobBannerView: View {
    let adUnitID: String
    let isInitialized: Bool

    var body: some View {
        GeometryReader { geometry in
            let adSize = largeAnchoredAdaptiveBanner(width: geometry.size.width)
            AdMobBannerContainer(adUnitID: adUnitID, adSize: adSize, isInitialized: isInitialized)
                .frame(width: adSize.size.width, height: adSize.size.height)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 76)
    }
}

private struct AdMobBannerContainer: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize
    let isInitialized: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        if isInitialized {
            banner.load(Request())
            context.coordinator.didLoad = true
        }
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        guard isInitialized, !context.coordinator.didLoad else { return }
        uiView.load(Request())
        context.coordinator.didLoad = true
    }

    final class Coordinator {
        var didLoad = false
    }
}
