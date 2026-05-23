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
            // GeometryReader gives us an exact width to pin the card to, so AsyncImage's
            // intrinsic size + spring animations can't ever make it visually wider than
            // the SwipeView container.
            GeometryReader { geo in
                // Hard cap so a transient layout pass can't ever inflate the card past the
                // device width minus the parent's padding. 380pt comfortably fits the
                // narrowest iPhone (iPhone SE @ 320pt minus padding) and clamps tablets.
                let w = min(geo.size.width, 380)
                ZStack {
                    if restaurants.count > 1 {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            )
                            .frame(width: w, height: 520)
                            .scaleEffect(0.96)
                            .offset(y: 10)
                            .zIndex(0)
                    }

                    // Top card — .id() forces a fresh @State on the new restaurant.
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
                    .frame(width: w, height: 520)
                    .id(restaurants[0].id)
                    .zIndex(1)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .frame(height: 540)   // explicit so the GeometryReader has a deterministic size
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
