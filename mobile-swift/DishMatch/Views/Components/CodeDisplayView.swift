import SwiftUI

struct CodeDisplayView: View {
    let code: String

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @State private var copied = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = code.uppercased()
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    HStack(spacing: 10) {
                        ForEach(Array(code.uppercased().enumerated()), id: \.offset) { _, char in
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(theme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(theme.primary.opacity(0.4), lineWidth: 1.5)
                                    )
                                    .frame(width: 60, height: 72)
                                Text(String(char))
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .foregroundColor(theme.primary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                ShareLink(item: "Join my Dishd session! Code: \(code.uppercased())") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(theme.primary)
                        .frame(width: 44, height: 44)
                }
            }

            if copied {
                Text("Copied!")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.primary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: copied)
    }
}
