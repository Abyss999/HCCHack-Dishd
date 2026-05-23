import SwiftUI

enum ButtonVariant { case primary, secondary, ghost }

struct PrimaryButton: View {
    let title: String
    var variant: ButtonVariant = .primary
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(labelColor)
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(labelColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .cornerRadius(12)
            .opacity(isDisabled || isLoading ? 0.5 : 1)
        }
        .disabled(isDisabled || isLoading)
    }

    private var bgColor: Color {
        switch variant {
        case .primary:   return theme.primary
        case .secondary: return .clear
        case .ghost:     return .clear
        }
    }

    private var labelColor: Color {
        switch variant {
        case .primary:   return .white
        case .secondary: return theme.primary
        case .ghost:     return theme.textSecondary
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:   return .clear
        case .secondary: return theme.primary
        case .ghost:     return theme.border
        }
    }
}
