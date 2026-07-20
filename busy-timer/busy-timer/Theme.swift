import SwiftUI

/// The app's design language: a dark "night gym" palette — near-black ink,
/// graphite surfaces, and a single electric volt accent — with heavy rounded
/// numerals and uppercase tracked labels.
enum Theme {
    /// App-wide background.
    static let ink = Color(red: 0.047, green: 0.055, blue: 0.071)
    /// Elevated card surface.
    static let surface = Color(red: 0.090, green: 0.104, blue: 0.133)
    /// Brighter surface for selected chips and pressed states.
    static let surfaceBright = Color(red: 0.137, green: 0.153, blue: 0.192)
    /// The one hot accent. Used sparingly: the CTA, the live ring, key numbers.
    static let volt = Color(red: 0.824, green: 0.969, blue: 0.282)
    /// Countdown / caution.
    static let amber = Color(red: 1.0, green: 0.706, blue: 0.329)
    /// Destructive.
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.37)

    static let cardStroke = Color.white.opacity(0.07)
    static let textSecondary = Color.white.opacity(0.55)
    static let textFaint = Color.white.opacity(0.40)

    /// Big display numerals (timer, rep counts).
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}

// MARK: - Text styles

extension View {
    /// Small uppercase tracked label used above cards and big numbers.
    func overline(color: Color = Theme.textFaint) -> some View {
        font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .kerning(1.6)
            .foregroundStyle(color)
    }

    /// Graphite card container.
    func card(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    )
            )
    }

    /// Standard screen backdrop.
    func inkBackground() -> some View {
        background(Theme.ink.ignoresSafeArea())
    }
}

// MARK: - Buttons

/// Full-width high-emphasis button: volt fill, black text.
struct VoltButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(isEnabled ? .black : Theme.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isEnabled ? Theme.volt : Theme.surface)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Full-width low-emphasis button: graphite fill, tinted text.
struct GhostButtonStyle: ButtonStyle {
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Selection chip

/// A selectable pill used for the type and duration pickers.
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? Theme.surfaceBright : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.white.opacity(0.16) : .clear,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}
