import SwiftUI

struct SwipeView: View {
    let sessionId: UUID
    @Binding var path: NavigationPath

    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @StateObject private var vm: SwipeViewModel

    init(sessionId: UUID, path: Binding<NavigationPath>) {
        self.sessionId = sessionId
        self._path = path
        self._vm = StateObject(wrappedValue: SwipeViewModel(sessionId: sessionId))
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Swiping")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.text)
                    Spacer()
                    Text("\(vm.swipeCount) swiped")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Progress bar
                ProgressBarView(progress: vm.swipeCount > 0 ? Double(vm.swipeCount) / 10.0 : 0)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                // Card stack
                if sessionVM.isLoading {
                    Spacer()
                    ProgressView().tint(theme.primary)
                    Spacer()
                } else {
                    SwipeStackView(
                        restaurants: vm.visibleRestaurants,
                        onSwipe: { restaurant, direction in
                            await vm.swipe(restaurant: restaurant, direction: direction)
                        },
                        onAdvance: { restaurant in
                            vm.markSwiped(restaurant)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

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
        .task {
            vm.bind(sessionVM: sessionVM)
            await vm.load()
        }
        .onChange(of: vm.navigateToResults) { navigate in
            if navigate { path.append(SessionRoute.results(sessionId)) }
        }
        .fullScreenCover(isPresented: $vm.showMatch) {
            if let r = vm.matchedRestaurant {
                MatchOverlay(restaurant: r) {
                    vm.showMatch = false
                    path.append(SessionRoute.results(sessionId))
                }
            }
        }
    }
}
