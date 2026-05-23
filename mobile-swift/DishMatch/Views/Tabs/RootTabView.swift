import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @State private var selection: Int = 1  // 0=History, 1=Home (default), 2=Profile

    var body: some View {
        TabView(selection: $selection) {
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(0)
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(1)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(2)
        }
        .tint(theme.primary)
    }
}
