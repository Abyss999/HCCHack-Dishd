import SwiftUI

struct ContentCoordinator: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme

    var body: some View {
        Group {
            if authStore.isLoading {
                SplashView()
            } else if authStore.isAuthenticated {
                RootTabView()
            } else {
                AuthNavigator()
            }
        }
        .preferredColorScheme(preferredScheme)
        .task { await authStore.restoreSession() }
    }

    private var preferredScheme: ColorScheme? {
        switch themeStore.mode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0a0a0a").ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: "#d97757"))
                Text("DishMatch")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Auth navigator

enum AuthRoute: Hashable { case signup }

struct AuthNavigator: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            LoginView(path: $path)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .signup:
                        SignupView(path: $path)
                    }
                }
        }
    }
}

// MARK: - Session navigator

enum SessionRoute: Hashable {
    case swipe(UUID)
    case results(UUID)
}

struct SessionNavigator: View {
    let sessionId: UUID
    @ObservedObject var sessionVM: SessionViewModel
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            LobbyView(sessionId: sessionId, path: $path)
                .environmentObject(sessionVM)
                .navigationDestination(for: SessionRoute.self) { route in
                    switch route {
                    case .swipe(let id):
                        SwipeView(sessionId: id, path: $path)
                            .environmentObject(sessionVM)
                            .id(id)
                    case .results(let id):
                        ResultsView(sessionId: id)
                            .environmentObject(sessionVM)
                    }
                }
        }
    }
}
