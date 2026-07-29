import SwiftUI

/// The app's design language: "clear air" — warm paper, deep ink, one pine
/// accent, and big serif numerals. The brand is simplicity: twenty minutes
/// of burpees, nothing to buy, nothing else to decide. The look should read
/// like a well-set page, not a gym poster.
enum Theme {
    /// App-wide background: warm paper.
    static let paper = Color(red: 0.961, green: 0.945, blue: 0.910)
    /// Card surface.
    static let card = Color.white
    /// Primary text and numerals: green-cast near-black.
    static let ink = Color(red: 0.106, green: 0.133, blue: 0.110)
    /// The one accent: CTA, key numbers, live progress.
    static let pine = Color(red: 0.173, green: 0.369, blue: 0.310)
    /// Caution / stopped early.
    static let clay = Color(red: 0.753, green: 0.471, blue: 0.298)
    /// Destructive.
    static let rust = Color(red: 0.663, green: 0.263, blue: 0.227)
    /// Breath-field tints (the home screen marquee).
    static let air = Color(red: 0.725, green: 0.812, blue: 0.859)
    static let sage = Color(red: 0.796, green: 0.863, blue: 0.784)

    static let hairline = Color.black.opacity(0.08)
    static let textSecondary = ink.opacity(0.55)
    static let textFaint = ink.opacity(0.38)

    /// Big display numerals and headlines (timer, rep counts).
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .serif)
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

    /// White card container on the paper background.
    func card(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
            )
    }

    /// Standard screen backdrop.
    func paperBackground() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }
}

// MARK: - Buttons

/// Full-width high-emphasis button: pine fill, paper text.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(isEnabled ? Theme.paper : Theme.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? Theme.pine : Theme.ink.opacity(0.08))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Full-width low-emphasis button: white fill, tinted text.
struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Selection chip

/// A selectable pill used for the type and batch pickers.
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.pine : Theme.textSecondary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Theme.pine.opacity(0.10) : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Theme.pine.opacity(0.5) : Theme.hairline,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}
