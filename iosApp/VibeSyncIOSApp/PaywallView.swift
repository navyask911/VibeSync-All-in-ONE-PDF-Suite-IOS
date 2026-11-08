import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var billingProvider: StoreKitBillingProvider

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(VibeSyncColors.crimsonPrimary)
                        Text("Upgrade to VibeSync PDF Pro")
                            .vibeSyncStyle(.titleLarge)
                            .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                        Text("Unlock the complete, ad-free VibeSync experience.")
                            .vibeSyncStyle(.bodyMedium)
                            .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Watermark-free exports", systemImage: "checkmark.seal.fill")
                        Label("100% ad-free experience", systemImage: "nosign")
                        Label("Custom watermarks", systemImage: "textformat")
                        Label("Premium PDF tools", systemImage: "lock.open.fill")
                    }
                    .font(VibeSyncTypography.bodyLarge)
                    .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VibeSyncColors.surfaceVariant(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    if billingProvider.isProActive {
                        Label("Pro Pass Active — ads are removed", systemImage: "checkmark.circle.fill")
                            .font(VibeSyncTypography.titleMedium)
                            .foregroundStyle(VibeSyncColors.successGreen)
                            .accessibilityIdentifier("pro_active_state")
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(billingProvider.product?.displayPrice ?? "Price provided by the App Store")
                                .font(VibeSyncTypography.titleLarge.weight(.bold))
                                .foregroundStyle(VibeSyncColors.textPrimary(for: colorScheme))
                            Text("Annual auto-renewing subscription. Manage or cancel anytime in your Apple Account settings.")
                                .vibeSyncStyle(.bodyMedium)
                                .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                        }

                        Button {
                            Task { await billingProvider.purchaseProPass() }
                        } label: {
                            HStack {
                                if billingProvider.isLoading {
                                    ProgressView().tint(VibeSyncColors.white)
                                }
                                Text("Subscribe to Pro Pass")
                                    .font(VibeSyncTypography.labelLarge)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VibeSyncColors.crimsonPrimary)
                        .disabled(billingProvider.isLoading || billingProvider.product == nil)
                        .accessibilityIdentifier("pro_purchase_button")
                    }

                    Button {
                        Task { await billingProvider.restoreProPass() }
                    } label: {
                        Text("Restore Purchases")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .disabled(billingProvider.isLoading)
                    .accessibilityIdentifier("pro_restore_button")

                    if let statusMessage = billingProvider.statusMessage {
                        Text(statusMessage)
                            .vibeSyncStyle(.bodyMedium)
                            .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                            .accessibilityIdentifier("pro_billing_status")
                    }

                    Text("Subscriptions are billed through the App Store. The price and renewal terms are shown in the system purchase confirmation.")
                        .font(.footnote)
                        .foregroundStyle(VibeSyncColors.textSecondary(for: colorScheme))
                }
                .padding(20)
            }
            .background(VibeSyncColors.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("VibeSync PDF Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("pro_paywall_close")
                }
            }
        }
        .task {
            await billingProvider.configure()
        }
    }
}
