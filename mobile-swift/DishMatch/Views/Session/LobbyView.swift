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
    @State private var members: [SessionMember] = []
    @State private var showLeaveAlert = false

    private var session: Session? { sessionVM.session }
    private var isHost: Bool { session?.hostUserId == authStore.user?.id }
    private var canStart: Bool { members.count >= 1 }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    // Header row with leave button
                    HStack {
                        Button { showLeaveAlert = true } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 32, height: 32)
                        }
                        Spacer()
                    }
                    .padding(.top, 16)

                    // Title
                    VStack(spacing: 6) {
                        Text("Session Lobby")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(theme.text)
                        Text("Tap the code to copy · tap ↑ to share")
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

                    // Session code + share
                    if let code = session?.code {
                        CodeDisplayView(code: code)
                    }

                    // Members list
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Members (\(members.count))")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.text)
                            Spacer()
                            if !canStart && isHost {
                                Text("Need 2+ to start")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textTertiary)
                            }
                        }

                        ForEach(members) { member in
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

                    // Start button (host only)
                    if isHost {
                        PrimaryButton(
                            title: "Start Swiping",
                            isLoading: sessionVM.isLoading,
                            isDisabled: !canStart
                        ) {
                            Task {
                                try? await sessionVM.startSwiping(sessionId)
                                path.append(SessionRoute.swipe(sessionId))
                            }
                        }
                    } else {
                        Text("Waiting for the host to start...")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                            .padding(.vertical, 16)
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
        .task {
            members = sessionVM.session?.members ?? []
            do {
                try await sessionVM.fetchSession(sessionId)
                members = sessionVM.session?.members ?? []
            } catch {
                print("[LobbyView] fetchSession failed: \(error)")
            }
            guard let token = sessionVM.token else { return }
            ws.connect(sessionId: sessionId, token: token)
            ws.onMemberJoined = { p in
                let m = SessionMember(userId: p.userId, name: p.name, joinedAt: Date())
                if !members.contains(where: { $0.userId == p.userId }) {
                    members.append(m)
                }
            }
            ws.onPhaseChange = { p in
                if p.phase == .swiping {
                    path.append(SessionRoute.swipe(sessionId))
                }
            }
        }
        .onDisappear { ws.disconnect() }
    }
}
