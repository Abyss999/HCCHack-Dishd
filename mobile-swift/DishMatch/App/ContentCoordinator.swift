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
    let isSolo: Bool
    /// When true, open straight into ResultsView instead of SwipeView. Used by the
    /// History tab when re-opening a session that already reached results/matched.
    let openAtResults: Bool
    @ObservedObject var sessionVM: SessionViewModel
    @State private var path = NavigationPath()
    @Environment(\.dismiss) private var dismiss

    init(sessionId: UUID, sessionVM: SessionViewModel, isSolo: Bool = false, openAtResults: Bool = false) {
        self.sessionId = sessionId
        self.sessionVM = sessionVM
        self.isSolo = isSolo
        self.openAtResults = openAtResults
    }

    var body: some View {
        NavigationStack(path: $path) {
            // Root: SwipeView for live sessions, ResultsView for finished ones.
            Group {
                if openAtResults {
                    ResultsView(sessionId: sessionId, path: $path, onClose: { dismiss() }, sessionVM: sessionVM)
                        .environmentObject(sessionVM)
                        .id(sessionId)
                } else {
                    SwipeView(sessionId: sessionId, path: $path, onLeave: { dismiss() })
                        .environmentObject(sessionVM)
                        .id(sessionId)
                }
            }
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .swipe(let id):
                    SwipeView(sessionId: id, path: $path, onLeave: { dismiss() })
                        .environmentObject(sessionVM)
                        .id(id)
                case .results(let id):
                    // onClose must dismiss the *cover*, not pop the nav back to the
                    // stale SwipeView (which would re-run its .task and end up
                    // showing the NYC mock list).
                    ResultsView(sessionId: id, path: $path, onClose: { dismiss() }, sessionVM: sessionVM)
                        .environmentObject(sessionVM)
                }
            }
        }
    }
}
