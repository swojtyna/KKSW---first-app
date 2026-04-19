import SwiftUI

struct ThemeShowcaseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header

                section(title: "Colors · Brand", subtitle: "Żyją w Assets.xcassets z wariantami Any/Dark.") {
                    VStack(spacing: Theme.Spacing.md) {
                        colorRow(name: "brandViolet", color: .brandViolet, spec: "#7C3AED · primary accent")
                        colorRow(name: "brandVioletTint", color: .brandVioletTint, spec: "violet @ 12%/20%")
                        colorRow(name: "brandVioletInk", color: .brandVioletInk, spec: "#4B228F · on-tint text")
                        colorRow(name: "brandAmber", color: .brandAmber, spec: "#FF9F0A · secondary")
                        colorRow(name: "brandAmberTint", color: .brandAmberTint, spec: "amber @ 15%/25%")
                        colorRow(name: "brandAmberInk", color: .brandAmberInk, spec: "#B76A00 · on-tint text")
                    }
                }

                section(title: "Colors · Surfaces / Text", subtitle: "System semantic — dark mode auto.") {
                    VStack(spacing: Theme.Spacing.md) {
                        colorRow(name: "surfaceBg", color: .surfaceBg, spec: "systemBackground")
                        colorRow(name: "surfaceElev", color: .surfaceElev, spec: "secondarySystemBackground")
                        colorRow(name: "surfaceGrouped", color: .surfaceGrouped, spec: "systemGroupedBackground")
                        colorRow(name: "textPrimary", color: .textPrimary, spec: ".label")
                        colorRow(name: "textSecondary", color: .textSecondary, spec: ".secondaryLabel")
                        colorRow(name: "textTertiary", color: .textTertiary, spec: ".tertiaryLabel")
                        colorRow(name: "separator", color: .separator, spec: ".separator")
                    }
                }

                section(title: "Typography", subtitle: "System text styles → Dynamic Type auto.") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        typeRow(name: "dduLargeTitle", font: .dduLargeTitle, sample: "Cześć, mistrzu.")
                        typeRow(name: "dduTitle1", font: .dduTitle1, sample: "Twoje święte wojny")
                        typeRow(name: "dduTitle2", font: .dduTitle2, sample: "Dni robocze · 9–17")
                        typeRow(name: "dduTitle3", font: .dduTitle3, sample: "Blokady społecznościówek")
                        typeRow(name: "dduHeadline", font: .dduHeadline, sample: "Aktualny streak · 7 dni")
                        typeRow(name: "dduBody", font: .dduBody, sample: "Nie, nie odblokujesz tego wcześniej.")
                        typeRow(name: "dduCallout", font: .dduCallout, sample: "Dziś też nie zawal.")
                        typeRow(name: "dduSubheadline", font: .dduSubheadline, sample: "Sobota, 18 kwietnia — dzień 7.")
                        typeRow(name: "dduFootnote", font: .dduFootnote, sample: "23 sesje w tym miesiącu.")
                        typeRow(name: "dduCaption1", font: .dduCaption1, sample: "AKTUALNY STREAK")
                        typeRow(name: "dduCaption2", font: .dduCaption2, sample: "HOT")
                        typeRow(name: "dduMono", font: .dduMono, sample: "22:37")
                    }
                }

                section(title: "Spacing", subtitle: "4pt grid — wielokrotności 4.") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        spacingRow(name: "xs", value: Theme.Spacing.xs, note: "4pt")
                        spacingRow(name: "sm", value: Theme.Spacing.sm, note: "8pt")
                        spacingRow(name: "md", value: Theme.Spacing.md, note: "12pt")
                        spacingRow(name: "lg ★", value: Theme.Spacing.lg, note: "16pt · default gutter")
                        spacingRow(name: "xl", value: Theme.Spacing.xl, note: "20pt")
                        spacingRow(name: "xxl", value: Theme.Spacing.xxl, note: "24pt")
                        spacingRow(name: "xxxl", value: Theme.Spacing.xxxl, note: "32pt")
                        spacingRow(name: "section", value: Theme.Spacing.section, note: "48pt")
                    }
                }

                section(title: "Corner radii", subtitle: "Zawsze continuous — Apple squircle.") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.md), count: 3), spacing: Theme.Spacing.md) {
                        radiusCard(name: "xs", radius: Theme.Radius.xs, note: "chip")
                        radiusCard(name: "sm", radius: Theme.Radius.sm, note: "button")
                        radiusCard(name: "md", radius: Theme.Radius.md, note: "field")
                        radiusCard(name: "lg ★", radius: Theme.Radius.lg, note: "card")
                        radiusCard(name: "xl", radius: Theme.Radius.xl, note: "hero")
                        radiusCard(name: "full", radius: Theme.Radius.full, note: "pill")
                    }
                }

                section(title: "Elevation", subtitle: "Karta cienia — stosowane przez .dduCard().") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.md), count: 3), spacing: Theme.Spacing.md) {
                        shadowCard(name: "card", shadow: Theme.Shadow.card, spec: "r:12 y:4 · 6%")
                        shadowCard(name: "cardElev ★", shadow: Theme.Shadow.cardElev, spec: "r:24 y:8 · 8%")
                        shadowCard(name: "sheet", shadow: Theme.Shadow.sheet, spec: "r:40 y:20 · 14%")
                    }
                }

                section(title: "Materials · Liquid Glass", subtitle: "Natywne Material — bez custom blur.") {
                    ZStack {
                        LinearGradient(
                            colors: [.brandViolet, .brandAmber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        VStack(spacing: Theme.Spacing.md) {
                            materialPill(name: ".ultraThinMaterial", material: .ultraThinMaterial)
                            materialPill(name: ".thinMaterial", material: .thinMaterial)
                            materialPill(name: ".regularMaterial", material: .regularMaterial)
                            materialPill(name: ".thickMaterial", material: .thickMaterial)
                        }
                        .padding(Theme.Spacing.xxl)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .frame(height: 280)
                }

                section(title: "Modifiers", subtitle: "dduCard() · dduGlass(_:)") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("dduCard()")
                                .font(.dduHeadline)
                                .foregroundStyle(Color.textPrimary)
                            Text("Padding 16 + surfaceElev + radius 18 + card shadow.")
                                .font(.dduFootnote)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dduCard()

                        HStack(spacing: Theme.Spacing.md) {
                            Text("ultraThin")
                                .font(.dduFootnote)
                                .foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .dduGlass(.ultraThinMaterial)

                            Text("regular")
                                .font(.dduFootnote)
                                .foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .dduGlass(.regularMaterial)

                            Text("thick")
                                .font(.dduFootnote)
                                .foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .dduGlass(.thickMaterial)
                        }
                        .padding(Theme.Spacing.lg)
                        .background(
                            LinearGradient(colors: [.brandViolet, .brandAmber], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        )
                    }
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Color.surfaceGrouped.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("01 · FOUNDATIONS")
                .font(.dduMono)
                .foregroundStyle(Color.brandViolet)
                .textCase(.uppercase)

            Text("Tokens.")
                .font(.dduLargeTitle)
                .foregroundStyle(Color.textPrimary)

            Text("Design tokens mapowane 1:1 na SwiftUI. iOS 26 only.")
                .font(.dduCallout)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Section shell

    private func section<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title.uppercased())
                    .font(.dduMono)
                    .foregroundStyle(Color.textSecondary)

                if let subtitle {
                    Text(subtitle)
                        .font(.dduFootnote)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            content()
        }
    }

    // MARK: - Rows

    private func colorRow(name: String, color: Color, spec: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(Color.separator, lineWidth: 0.5)
                )
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.dduMono)
                    .foregroundStyle(Color.brandViolet)
                Text(spec)
                    .font(.dduFootnote)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Color.surfaceElev, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    private func typeRow(name: String, font: Font, sample: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(name)
                .font(.dduMono)
                .foregroundStyle(Color.brandViolet)
            Text(sample)
                .font(font)
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Color.surfaceElev, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    private func spacingRow(name: String, value: CGFloat, note: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(name)
                .font(.dduMono)
                .foregroundStyle(Color.brandViolet)
                .frame(width: 72, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.brandVioletTint)
                    .frame(height: 24)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.brandViolet)
                    .frame(width: value, height: 24)
            }

            Text(note)
                .font(.dduFootnote)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 140, alignment: .trailing)
        }
    }

    private func radiusCard(name: String, radius: CGFloat, note: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.brandViolet)
                .frame(width: 72, height: 72)
                .overlay(
                    Text("\(Int(radius))")
                        .font(.dduMono)
                        .foregroundStyle(.white)
                )

            VStack(spacing: 2) {
                Text(name)
                    .font(.dduMono)
                    .foregroundStyle(Color.brandViolet)
                Text(note)
                    .font(.dduCaption2)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(Color.surfaceElev, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    private func shadowCard(name: String, shadow: Theme.Shadow, spec: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color.surfaceElev)
                .frame(height: 72)
                .dduShadow(shadow)
                .padding(Theme.Spacing.md)

            Text(name)
                .font(.dduMono)
                .foregroundStyle(Color.brandViolet)

            Text(spec)
                .font(.dduCaption2)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.surfaceElev.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    private func materialPill(name: String, material: Material) -> some View {
        Text(name)
            .font(.dduFootnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .background(material, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5))
    }
}

#Preview("Light") {
    ThemeShowcaseView().preferredColorScheme(.light)
}

#Preview("Dark") {
    ThemeShowcaseView().preferredColorScheme(.dark)
}
