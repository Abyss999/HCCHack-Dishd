import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeStore: ThemeStore
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @StateObject private var sessionVM: SessionViewModel
    @StateObject private var homeVM: HomeViewModel
    @State private var joinCode = ""
    @State private var activeSession: Session?

    init() {
        let svm = SessionViewModel()
        _sessionVM = StateObject(wrappedValue: svm)
        _homeVM = StateObject(wrappedValue: HomeViewModel(sessionVM: svm))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 6) {
                            Text("DishMatch")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(theme.text)
                            Text("Swipe together, eat together")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.top, 24)

                        // Create session
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Start a Session")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(theme.text)
                            Text("Create a new group and invite friends with a 4-digit code.")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)

                            PrimaryButton(title: "Create Session", isLoading: homeVM.isLoading) {
                                Task { await homeVM.createSession() }
                            }
                        }
                        .padding(20)
                        .background(theme.surface)
                        .cornerRadius(16)

                        // Join session
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Join a Session")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(theme.text)

                            HStack(spacing: 10) {
                                TextField("4-digit code", text: $joinCode)
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .textCase(.uppercase)
                                    .autocapitalization(.allCharacters)
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.asciiCapable)
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(theme.inputBg)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.inputBorder))
                                    .cornerRadius(10)
                                    .foregroundColor(theme.text)
                                    .onChange(of: joinCode) { val in
                                        if val.count > 4 { joinCode = String(val.prefix(4)) }
                                        if val.count == 4 {
                                            Task { await homeVM.joinSession(code: val) }
                                        }
                                    }

                                PrimaryButton(title: "Join", isDisabled: joinCode.count < 4) {
                                    Task { await homeVM.joinSession(code: joinCode) }
                                }
                                .frame(width: 80)
                            }
                        }
                        .padding(20)
                        .background(theme.surface)
                        .cornerRadius(16)

                        // How it works
                        howItWorksSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: homeVM.createdSession) { s in
            if let s { activeSession = s }
        }
        .onChange(of: homeVM.joinedSession) { s in
            if let s { activeSession = s }
        }
        .fullScreenCover(item: $activeSession) { session in
            SessionNavigator(sessionId: session.id, sessionVM: sessionVM)
                .environmentObject(authStore)
                .environmentObject(themeStore)
        }
        .alert("Error", isPresented: .init(
            get: { homeVM.errorMessage != nil },
            set: { if !$0 { homeVM.errorMessage = nil } }
        )) {
            Button("OK") { homeVM.errorMessage = nil }
        } message: {
            Text(homeVM.errorMessage ?? "")
        }
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.text)
            ForEach([
                ("1", "Create or join a session"),
                ("2", "Swipe yes/no on nearby restaurants"),
                ("3", "Get an instant match or Top 3")
            ], id: \.0) { num, tip in
                HStack(spacing: 12) {
                    Text(num)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.primary)
                        .frame(width: 24, height: 24)
                        .background(theme.chipBg)
                        .clipShape(Circle())
                    Text(tip)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(20)
        .background(theme.surface)
        .cornerRadius(16)
    }
}
