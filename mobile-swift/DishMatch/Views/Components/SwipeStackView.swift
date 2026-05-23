import SwiftUI

struct SwipeStackView: View {
    let restaurants: [Restaurant]
    let onSwipe: (Restaurant, SwipeDirection) async -> Void
    let onAdvance: (Restaurant) -> Void

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    var body: some View {
        if restaurants.isEmpty {
            emptyState
        } else {
            ZStack {
                // Background peek card
                if restaurants.count > 1 {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                        .frame(height: 520)
                        .scaleEffect(0.96)
                        .offset(y: 10)
                        .zIndex(0)
                }

                // Top card — .id() forces a fresh view (and fresh @State offset)
                // whenever the top restaurant changes, so the incoming card
                // starts at offset = .zero instead of inheriting the fly-out position.
                RestaurantCardView(
                    restaurant: restaurants[0],
                    onSwipeLeft: {
                        let top = restaurants[0]
                        onAdvance(top)
                        Task { await onSwipe(top, .no) }
                    },
                    onSwipeRight: {
                        let top = restaurants[0]
                        onAdvance(top)
                        Task { await onSwipe(top, .yes) }
                    }
                )
                .id(restaurants[0].id)
                .zIndex(1)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(theme.primary)
            Text("You've seen all restaurants!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.text)
            Text("Wait for your group or view results.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
        }
        .padding(40)
    }
}
