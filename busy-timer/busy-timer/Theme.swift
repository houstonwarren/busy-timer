import SwiftUI

/// The app's design language: Bauhaus. Paper ground, ink structure, and two
/// colors that always mean the same thing — red is time (the clock bar, the
/// pace, the current set), blue is reps you've done (the dot grid, the
/// counts). Blue never appears before a workout starts, so the timer screen
/// feels like a reward. Geometry is hard-edged: square steppers, boxed
/// segmented controls, thin rules instead of cards. Reference:
/// mockups/final-bauhaus.png.
enum Theme {
    static let paper = Color(red: 0.969, green: 0.957, blue: 0.925)
    static let ink = Color(red: 0.078, green: 0.078, blue: 0.078)
    /// Time: clock bar, pace seconds, current-set dots, brand periods.
    static let red = Color(red: 0.886, green: 0.271, blue: 0.176)
    /// Done reps: dot grid fill, rep counts. Timer and history only.
    static let blue = Color(red: 0.176, green: 0.373, blue: 0.886)
    /// Secondary text.
    static let grey = Color(red: 0.541, green: 0.529, blue: 0.486)
    /// Empty track behind the clock bar.
    static let track = Color(red: 0.890, green: 0.875, blue: 0.824)

    /// Display numerals and headline words: geometric Futura.
    static func display(_ size: CGFloat) -> Font {
        .custom("Futura-Medium", size: size)
    }
}

// MARK: - Text styles

extension View {
    /// Small uppercase tracked label ("TARGET REPS", "NEXT SET · 2 REPS").
    func label(color: Color = Theme.ink) -> some View {
        font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .kerning(2.2)
            .foregroundStyle(color)
    }

    /// Standard screen backdrop.
    func paperBackground() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }
}

/// Thin ink rule dividing sections.
struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.ink)
            .frame(height: 1.5)
    }
}

/// Status word with the brand's red period: "working." "ready." "done."
struct StatusWord: View {
    let word: String

    var body: some View {
        HStack(spacing: 0) {
            Text(word)
                .font(Theme.display(19))
                .foregroundStyle(Theme.ink)
            Text(".")
                .font(Theme.display(19))
                .foregroundStyle(Theme.red)
        }
    }
}

// MARK: - Buttons

/// Filled ink bar, paper text, optional red dot: the primary action.
struct InkBarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var showDot = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            if showDot {
                Circle()
                    .fill(Theme.red)
                    .frame(width: 13, height: 13)
            }
            configuration.label
                .font(.system(size: 15, weight: .semibold))
                .textCase(.uppercase)
                .kerning(2.5)
        }
        .foregroundStyle(Theme.paper)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 19)
        .background(isEnabled ? Theme.ink : Theme.ink.opacity(0.25))
        .contentShape(Rectangle())
        .opacity(configuration.isPressed ? 0.8 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined bar, ink text: the secondary action.
struct OutlineBarButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .textCase(.uppercase)
            .kerning(2.5)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 19)
            .background(Theme.paper)
            .border(Theme.ink, width: 1.5)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined square − / + stepper flanking the big target number.
struct SquareStepButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 52, height: 52)
                .border(Theme.ink, width: 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Boxed segmented control

/// Hard-edged segmented picker: one outer border, cells split by rules,
/// the selected cell filled ink with paper text.
struct SegmentedBox<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                Button {
                    selection = item
                } label: {
                    Text(title(item))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(item == selection ? Theme.paper : Theme.ink)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .frame(minWidth: 52)
                        .background(item == selection ? Theme.ink : Theme.paper)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < items.count - 1 {
                    Rectangle()
                        .fill(Theme.ink)
                        .frame(width: 1.5)
                }
            }
        }
        .fixedSize()
        .border(Theme.ink, width: 1.5)
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}
