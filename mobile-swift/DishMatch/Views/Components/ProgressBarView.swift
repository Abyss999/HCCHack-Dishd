import SwiftUI

struct ProgressBarView: View {
    let progress: Double // 0.0 – 1.0
    var height: CGFloat = 6

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.progressBg)
                    .frame(height: height)
                Capsule()
                    .fill(theme.primary)
                    .frame(width: geo.size.width * min(max(progress, 0), 1), height: height)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}
