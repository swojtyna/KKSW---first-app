import SwiftUI

// MARK: - Buttons

struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = 44
    var iconSize: CGFloat = 18
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(width: size, height: size)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemIcon: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.dduHeadline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.brandViolet)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .shadow(color: Color.brandViolet.opacity(0.35), radius: 16, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemIcon: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.dduHeadline)
            }
            .foregroundStyle(Color.brandViolet)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.brandVioletTint)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.dduBody)
                .foregroundStyle(Color.brandViolet)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chips & tiles

struct DesignChip: View {
    let text: String
    var isActive: Bool = false
    var isSoft: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, Theme.Spacing.sm)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
    }

    private var background: Color {
        if isActive { return .brandViolet }
        if isSoft { return .brandVioletTint }
        return Color(.tertiarySystemFill)
    }

    private var foreground: Color {
        if isActive { return .white }
        if isSoft { return .brandVioletInk }
        return .textPrimary
    }
}

struct AppTileIcon: View {
    let gradient: LinearGradient
    let symbol: String
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(gradient)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            Text(symbol)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Grouped lists

struct SectionLabel: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.dduFootnote)
                .foregroundStyle(Color.textSecondary)
                .kerning(0.2)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandViolet)
            }
        }
        .padding(.horizontal, Theme.Spacing.xxxl)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}

struct GroupedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.surfaceElevGrouped)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, Theme.Spacing.lg)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 8)
    }
}

struct GroupedListRow<Trailing: View>: View {
    let title: String
    var detail: String?
    var leading: (() -> AnyView)?
    @ViewBuilder var trailing: Trailing
    var isLast: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let leading { leading() }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.dduBody)
                    .foregroundStyle(Color.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.dduFootnote)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.separator)
                    .frame(height: 0.5)
                    .padding(.leading, leading != nil ? 60 : Theme.Spacing.lg)
            }
        }
    }
}

// MARK: - Tab bar

struct DesignTabBar<SelectionValue: Hashable, Content: TabContent>: View where Content.TabValue == SelectionValue {
    @Binding var selection: SelectionValue
    private let content: Content

    init(selection: Binding<SelectionValue>, @TabContentBuilder<SelectionValue> content: () -> Content) {
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        TabView(selection: $selection) {
            content
        }
    }
}

struct DesignToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(Color.brandViolet)
    }
}

// MARK: - Mock apps (used by Blocked/Stats previews + empty-state tiles)

enum MockApp: Hashable {
    case instagram, tiktok, x, reddit, youtube, games, shopping

    var name: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .x: return "X"
        case .reddit: return "reddit.com"
        case .youtube: return "YouTube"
        case .games: return "Gry"
        case .shopping: return "Shopping"
        }
    }

    var tag: String {
        switch self {
        case .reddit: return "Strona"
        case .games, .shopping: return "Kategoria"
        default: return "Aplikacja"
        }
    }

    var symbol: String {
        switch self {
        case .instagram: return "📷"
        case .tiktok: return "♪"
        case .x: return "𝕏"
        case .reddit: return "r"
        case .youtube: return "▶"
        case .games: return "🎮"
        case .shopping: return "🛍"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .instagram:
            return LinearGradient(
                colors: [Color(red: 0.513, green: 0.227, blue: 0.706),
                         Color(red: 0.992, green: 0.114, blue: 0.114),
                         Color(red: 0.988, green: 0.690, blue: 0.271)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .tiktok, .x:
            return LinearGradient(colors: [.black, .black], startPoint: .top, endPoint: .bottom)
        case .reddit:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.271, blue: 0.0),
                                           Color(red: 1.0, green: 0.271, blue: 0.0)],
                                  startPoint: .top, endPoint: .bottom)
        case .youtube:
            return LinearGradient(colors: [.red, .red], startPoint: .top, endPoint: .bottom)
        case .games:
            return LinearGradient(colors: [.brandViolet, .brandVioletInk],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .shopping:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.584, blue: 0.0),
                                           Color(red: 1.0, green: 0.231, blue: 0.188)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static let sample: [MockApp] = [.instagram, .tiktok, .x, .reddit, .youtube, .games, .shopping]
}
