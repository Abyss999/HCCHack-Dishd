import SwiftUI

struct SwipeView: View {
    let sessionId: UUID
    @Binding var path: NavigationPath
    let onLeave: (() -> Void)?

    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @StateObject private var vm: SwipeViewModel
    @State private var showLeaveAlert = false
    @State private var showEndAlert = false

    private var isHost: Bool { sessionVM.session?.hostUserId == authStore.user?.id }

    init(sessionId: UUID, path: Binding<NavigationPath>, onLeave: (() -> Void)? = nil) {
        self.sessionId = sessionId
        self._path = path
        self.onLeave = onLeave
        self._vm = StateObject(wrappedValue: SwipeViewModel(sessionId: sessionId))
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { showLeaveAlert = true } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Swiping")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.text)
                        if let code = sessionVM.session?.code {
                            Button {
                                UIPasteboard.general.string = code
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 10))
                                    Text(code)
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                }
                                .foregroundColor(theme.primary)
                            }
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Text("\(vm.swipeCount) swiped")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                        if isHost {
                            Button("End") { showEndAlert = true }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.pass)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Progress bar
                ProgressBarView(progress: vm.swipeCount > 0 ? Double(vm.swipeCount) / 10.0 : 0)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                // Card stack — skeleton shown while loading, cards once ready
                SwipeStackView(
                    restaurants: vm.visibleRestaurants,
                    isLoading: vm.isLoadingRestaurants,
                    onSwipe: { restaurant, direction in
                        await vm.swipe(restaurant: restaurant, direction: direction)
                    },
                    onAdvance: { restaurant in
                        vm.markSwiped(restaurant)
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                // See results pill
                if vm.canSeeResults {
                    Button {
                        path.append(SessionRoute.results(sessionId))
                    } label: {
                        Text("See Results →")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(theme.primary)
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Leave Session?", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) { onLeave?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your swipes will be saved but you'll exit this session.")
        }
        .alert("End Session?", isPresented: $showEndAlert) {
            Button("End for Everyone", role: .destructive) {
                Task { try? await sessionVM.deleteSession(sessionId); onLeave?() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This ends the session and shows results for all members.")
        }
        .task {
            vm.bind(sessionVM: sessionVM)
            await vm.load()
        }
        .onChange(of: vm.navigateToResults) { navigate in
            // navigateToResults is a one-shot flag (guarded in the VM). Push once.
            if navigate { path.append(SessionRoute.results(sessionId)) }
        }
        .fullScreenCover(isPresented: $vm.showMatch) {
            if let r = vm.matchedRestaurant {
                MatchOverlay(restaurant: r) {
                    vm.showMatch = false
                    vm.requestNavigateToResults()
                }
            }
        }
    }
}
