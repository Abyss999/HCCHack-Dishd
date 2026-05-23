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
    @State private var showCreateSheet = false
    @State private var soloSheetMode = false
    @State private var startInLobby = false

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
                        ZStack {
                            VStack(spacing: 6) {
                                Text("DishMatch")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(theme.text)
                                Text("Swipe together, eat together")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.textSecondary)
                            }
                            HStack {
                                Spacer()
                                Button {
                                    let resolved = themeStore.resolved(system: systemScheme)
                                    themeStore.setMode(resolved == .dark ? .light : .dark)
                                } label: {
                                    Image(systemName: themeStore.resolved(system: systemScheme) == .dark ? "sun.max" : "moon")
                                        .font(.system(size: 18))
                                        .foregroundColor(theme.textSecondary)
                                        .frame(width: 36, height: 36)
                                }
                            }
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
                                soloSheetMode = false
                                showCreateSheet = true
                            }
                        }
                        .padding(20)
                        .background(theme.surface)
                        .cornerRadius(16)

                        // Solo mode
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Solo Swipe")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(theme.text)
                            Text("Swipe alone and get your personal top pick.")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)

                            PrimaryButton(title: "Start Solo Session", variant: .secondary, isLoading: homeVM.isLoading) {
                                soloSheetMode = true
                                showCreateSheet = true
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
        .task { await homeVM.fetchPastSessions() }
        .onChange(of: activeSession) { s in
            if s == nil { Task { await homeVM.fetchPastSessions() } }
        }
        .onChange(of: homeVM.createdSession) { s in
            if let s {
                startInLobby = s.soloMode != true  // lobby only for group sessions
                activeSession = s
            }
        }
        .onChange(of: homeVM.joinedSession) { s in
            if let s {
                startInLobby = false  // joining → skip lobby
                activeSession = s
            }
        }
        .fullScreenCover(item: $activeSession) { session in
            SessionNavigator(
                sessionId: session.id,
                sessionVM: sessionVM,
                isSolo: session.soloMode == true,
                startInLobby: startInLobby
            )
            .environmentObject(authStore)
            .environmentObject(themeStore)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateSessionSheet(homeVM: homeVM, soloMode: soloSheetMode)
                .environmentObject(themeStore)
                .environmentObject(authStore)
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

    private var pastSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.text)

            VStack(spacing: 8) {
                ForEach(homeVM.pastSessions.prefix(8)) { session in
                    Button {
                        activeSession = session
                    } label: {
                        HStack(spacing: 12) {
                            // Status indicator
                            Circle()
                                .fill(statusColor(session.status))
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(session.code)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(theme.primary)
                                    if session.soloMode == true {
                                        Text("SOLO")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(theme.textSecondary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(theme.chipBg)
                                            .cornerRadius(4)
                                    }
                                }
                                Text(session.locationLabel ?? "No location")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(statusLabel(session.status))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(statusColor(session.status))
                                Text(shortDate(session.createdAt))
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textSecondary)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.textTertiary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(theme.bg)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(theme.surface)
        .cornerRadius(16)
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .lobby: return theme.textSecondary
        case .swiping: return theme.primary
        case .results: return Color.blue
        case .matched: return Color.green
        }
    }

    private func statusLabel(_ status: SessionStatus) -> String {
        switch status {
        case .lobby: return "Lobby"
        case .swiping: return "Swiping"
        case .results: return "Results"
        case .matched: return "Matched"
        }
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
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
