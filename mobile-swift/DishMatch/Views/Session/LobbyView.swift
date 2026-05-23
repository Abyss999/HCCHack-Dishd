import SwiftUI

struct LobbyView: View {
    let sessionId: UUID
    @Binding var path: NavigationPath
    let onLeave: (() -> Void)?

    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @StateObject private var ws = WebSocketService()
    @State private var showLeaveAlert = false
    @State private var showEndAlert = false
    @State private var isEndingSession = false

    private var session: Session? { sessionVM.session }
    private var isHost: Bool { session?.hostUserId == authStore.user?.id }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    // Header row
                    HStack {
                        Button { showLeaveAlert = true } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 32, height: 32)
                        }
                        Spacer()
                        if isHost {
                            Button("End") { showEndAlert = true }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.pass)
                        }
                    }
                    .padding(.top, 16)

                    // Title section
                    VStack(spacing: 6) {
                        Text("Invite Friends")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(theme.text)
                        Text("Share this code — others can join any time")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                        if let label = session?.locationLabel, !label.isEmpty {
                            HStack(spacing: 4) {
                                Text("📍")
                                    .font(.system(size: 13))
                                Text(label)
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 8)

                    // Session code
                    if let code = session?.code {
                        CodeDisplayView(code: code)
                    }

                    // Start Swiping button
                    PrimaryButton(
                        title: "Start Swiping →",
                        isLoading: isEndingSession,
                        isDisabled: false
                    ) {
                        path.append(SessionRoute.swipe(sessionId))
                    }

                    // Members card — driven directly by sessionVM.session.members so WS
                    // updates (onMemberJoined writes back to sessionVM.session) are reflected
                    // without a separate local @State copy.
                    if session?.soloMode == true {
                        VStack(spacing: 8) {
                            Text("Solo session — swipe at your own pace.")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(theme.surface)
                        .cornerRadius(12)
                    } else {
                        let currentMembers = session?.members ?? []
                        VStack(alignment: .leading, spacing: 12) {
                            Text("In this session (\(currentMembers.count))")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.text)

                            ForEach(currentMembers) { member in
                                HStack(spacing: 12) {
                                    AvatarView(name: member.name, userId: member.userId)
                                    Text(member.name)
                                        .font(.system(size: 15))
                                        .foregroundColor(theme.text)
                                    if member.userId == session?.hostUserId {
                                        Text("Host")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(theme.primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(theme.chipBg)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(theme.surface)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .alert("Leave Session?", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) { onLeave?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll exit this session and return to home.")
        }
        .alert("End Session?", isPresented: $showEndAlert) {
            Button("End Session", role: .destructive) {
                Task {
                    isEndingSession = true
                    try? await sessionVM.deleteSession(sessionId)
                    onLeave?()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This ends the session for everyone.")
        }
        .task {
            do {
                try await sessionVM.fetchSession(sessionId)
            } catch {
                print("[LobbyView] fetchSession failed: \(error)")
            }
            guard let token = sessionVM.token else { return }
            ws.connect(sessionId: sessionId, token: token)
            // Write new members back into sessionVM.session so @Published triggers a
            // re-render — avoids closure-capture issues with a local @State copy.
            ws.onMemberJoined = { p in
                let newMember = SessionMember(userId: p.userId, name: p.name, joinedAt: Date())
                guard var s = sessionVM.session,
                      !s.members.contains(where: { $0.userId == p.userId }) else { return }
                s.members.append(newMember)
                sessionVM.session = s
            }
            ws.onPhaseChange = { p in
                if p.phase == .results || p.phase == .matched {
                    path.append(SessionRoute.results(sessionId))
                }
            }
        }
        .onDisappear { ws.disconnect() }
    }
}
