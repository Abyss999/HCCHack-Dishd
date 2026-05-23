import SwiftUI

struct ChipView: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? theme.chipBg : Color.clear)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? theme.chipBorder : theme.border, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
