//
//  Theme.swift
//  DeluluDetox — Design tokens (iOS 26)
//

import SwiftUI

enum Theme {

    // MARK: - Spacing (4pt grid)
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16   // ★ default gutter
        static let xl: CGFloat  = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let section: CGFloat = 48
    }

    // MARK: - Corner radii (continuous)
    enum Radius {
        static let xs: CGFloat = 6    // chip
        static let sm: CGFloat = 10   // button
        static let md: CGFloat = 14   // field
        static let lg: CGFloat = 18   // ★ card
        static let xl: CGFloat = 24   // hero
        static let full: CGFloat = 999 // pill
    }

    // MARK: - Shadow (elevation)
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static let card = Shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        static let cardElev = Shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
        static let sheet = Shadow(color: .black.opacity(0.14), radius: 40, x: 0, y: 20)
    }

    // MARK: - Legacy aliases (TODO: migrate callers to Color.* / Font.ddu* direct)
    // OnboardingView, DenialView, HomeView still reference these. Remove after migration.
    static var accent: Color { .brandViolet }
    static var background: Color { .surfaceBg }
    static var primaryText: Color { .textPrimary }
    static var secondaryText: Color { .textSecondary }
    static var tertiaryText: Color { .textTertiary }
}

// MARK: - Color tokens

extension Color {
    // Brand
    static let brandViolet = Color("BrandViolet")      // #7C3AED / #9B6BF4 dark
    static let brandVioletTint = Color("BrandVioletTint")
    static let brandVioletInk = Color("BrandVioletInk")
    static let brandAmber = Color("BrandAmber")        // #FF9F0A
    static let brandAmberTint = Color("BrandAmberTint")
    static let brandAmberInk = Color("BrandAmberInk")

    // Surfaces — prefer these over raw systemBackground
    static let surfaceBg = Color(uiColor: .systemBackground)
    static let surfaceElev = Color(uiColor: .secondarySystemBackground)
    static let surfaceGrouped = Color(uiColor: .systemGroupedBackground)

    // Text
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)
}

// MARK: - Typography (iOS 26 text styles)

extension Font {
    // Map do systemowych text styles + Dynamic Type
    static let dduLargeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    static let dduTitle1 = Font.system(.title, design: .default, weight: .bold)
    static let dduTitle2 = Font.system(.title2, design: .default, weight: .bold)
    static let dduTitle3 = Font.system(.title3, design: .default, weight: .semibold)
    static let dduHeadline = Font.system(.headline)
    static let dduBody = Font.system(.body)
    static let dduCallout = Font.system(.callout)
    static let dduSubheadline = Font.system(.subheadline)
    static let dduFootnote = Font.system(.footnote)
    static let dduCaption1 = Font.system(.caption)
    static let dduCaption2 = Font.system(.caption2)
    static let dduMono = Font.system(.caption, design: .monospaced).weight(.medium)
}

// MARK: - View modifiers

extension View {
    func dduCard() -> some View {
        self
            .padding(Theme.Spacing.lg)
            .background(Color.surfaceElev, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: Theme.Shadow.card.x, y: Theme.Shadow.card.y)
    }

    func dduGlass(_ material: Material = .regular) -> some View {
        self
            .background(material, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
    }
}
