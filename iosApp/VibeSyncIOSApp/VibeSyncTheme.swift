import SwiftUI

/// VibeSync's native palette, copied from the Android Compose design system.
enum VibeSyncColors {
    static let crimsonPrimary = Color(vibeSyncHex: 0xD32F2F)
    static let crimsonDark = Color(vibeSyncHex: 0xC62828)
    static let crimsonLight = Color(vibeSyncHex: 0xEF5350)
    static let rubyDeep = Color(vibeSyncHex: 0x8E0000)
    static let rubyAccent = Color(vibeSyncHex: 0xB71C1C)
    static let white = Color(vibeSyncHex: 0xFFFFFF)
    static let lightSurface = Color(vibeSyncHex: 0xFFFBFB)

    static let backgroundDark = Color(vibeSyncHex: 0x120808)
    static let surfaceDark = Color(vibeSyncHex: 0x1E0E0E)
    static let surfaceVariantDark = Color(vibeSyncHex: 0x2C1414)
    static let backgroundLight = Color(vibeSyncHex: 0xFFFBFB)
    static let surfaceLight = Color(vibeSyncHex: 0xFFFFFF)
    static let surfaceVariantLight = Color(vibeSyncHex: 0xFBEBEB)

    static let textPrimaryDark = Color(vibeSyncHex: 0xFFF1F1)
    static let textSecondaryDark = Color(vibeSyncHex: 0xE2BABA)
    static let textPrimaryLight = Color(vibeSyncHex: 0x1E0707)
    static let textSecondaryLight = Color(vibeSyncHex: 0x7A4A4A)

    static let dangerRed = Color(vibeSyncHex: 0xD32F2F)
    static let successGreen = Color(vibeSyncHex: 0x10B981)
    static let warningAmber = Color(vibeSyncHex: 0xF59E0B)

    /// Compose's Material color roles switch between Crimson and Crimson Light in dark mode.
    static func primary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? crimsonLight : crimsonPrimary
    }

    static func secondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? rubyAccent : rubyDeep
    }

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? backgroundDark : backgroundLight
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? surfaceDark : surfaceLight
    }

    static func surfaceVariant(for scheme: ColorScheme) -> Color {
        scheme == .dark ? surfaceVariantDark : surfaceVariantLight
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? textPrimaryDark : textPrimaryLight
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? textSecondaryDark : textSecondaryLight
    }
}

private extension Color {
    init(vibeSyncHex: UInt32) {
        self.init(
            .sRGB,
            red: Double((vibeSyncHex >> 16) & 0xFF) / 255,
            green: Double((vibeSyncHex >> 8) & 0xFF) / 255,
            blue: Double(vibeSyncHex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Android FontFamily.Default resolves to Roboto. The matching Roboto variable font
/// is bundled with the iOS target so the same family is used on both platforms.
enum VibeSyncTypography {
    private static let familyName = "Roboto-Regular"

    private static func font(size: CGFloat, weight: Font.Weight) -> Font {
        .custom(familyName, size: size, relativeTo: .body).weight(weight)
    }

    static let headlineLarge = font(size: 28, weight: .bold)
    static let headlineMedium = font(size: 22, weight: .semibold)
    static let titleLarge = font(size: 18, weight: .bold)
    static let titleMedium = font(size: 16, weight: .medium)
    static let bodyLarge = font(size: 15, weight: .regular)
    static let bodyMedium = font(size: 13, weight: .regular)
    static let labelLarge = font(size: 14, weight: .semibold)
}

/// Exact Compose typography roles, including the specified extra line height and tracking.
enum VibeSyncTextRole {
    case headlineLarge
    case headlineMedium
    case titleLarge
    case titleMedium
    case bodyLarge
    case bodyMedium
    case labelLarge
}

extension Text {
    @ViewBuilder
    func vibeSyncStyle(_ role: VibeSyncTextRole) -> some View {
        switch role {
        case .headlineLarge:
            self.font(VibeSyncTypography.headlineLarge).lineSpacing(6).tracking(-0.5)
        case .headlineMedium:
            self.font(VibeSyncTypography.headlineMedium).lineSpacing(6)
        case .titleLarge:
            self.font(VibeSyncTypography.titleLarge).lineSpacing(6)
        case .titleMedium:
            self.font(VibeSyncTypography.titleMedium).lineSpacing(6)
        case .bodyLarge:
            self.font(VibeSyncTypography.bodyLarge).lineSpacing(7)
        case .bodyMedium:
            self.font(VibeSyncTypography.bodyMedium).lineSpacing(5)
        case .labelLarge:
            self.font(VibeSyncTypography.labelLarge).lineSpacing(6).tracking(0.5)
        }
    }
}
