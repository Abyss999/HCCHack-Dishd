import SwiftUI

struct SwipeStackView: View {
    let restaurants: [Restaurant]
    let onSwipe: (Restaurant, SwipeDirection) async -> Void
    let onAdvance: (Restaurant) -> Void
    // Houston prefetch: optional — nil for non-Houston sessions
    var sessionId: UUID? = nil
    var sessionVM: SessionViewModel? = nil

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    // Tracks which restaurant IDs have already had a prefetch fired so we
    // don't re-fire on every re-render.
    @State private var prefetchedIds: Set<UUID> = []

    var body: some View {
        if restaurants.isEmpty {
            emptyState
        } else {
            // GeometryReader gives us an exact width to pin the card to, so AsyncImage's
            // intrinsic size + spring animations can't ever make it visually wider than
            // the SwipeView container.
            GeometryReader { geo in
                let cardWidth = min(geo.size.width - 32, 380.0)
                ZStack {
                    if restaurants.count > 1 {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            )
                            .frame(width: cardWidth, height: 520)
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
                        },
                        sessionId: sessionId,
                        sessionVM: sessionVM
                    )
                    .frame(width: cardWidth)
                    .id(restaurants[0].id)
                    .zIndex(1)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .frame(height: 540)   // explicit so the GeometryReader has a deterministic size
            .onChange(of: restaurants.first?.id) { _ in
                prefetchTopCard()
            }
            .onAppear {
                prefetchTopCard()
            }
        }
    }

    private func prefetchTopCard() {
        guard let top = restaurants.first,
              top.isSeed == true,
              let sid = sessionId,
              let svm = sessionVM,
              !prefetchedIds.contains(top.id)
        else { return }

        prefetchedIds.insert(top.id)
        Task {
            _ = try? await svm.fetchPersonalizedFit(restaurantId: top.id, sessionId: sid)
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
