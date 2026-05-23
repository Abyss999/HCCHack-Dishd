import SwiftUI
import UIKit

struct SwipeStackView: View {
    let restaurants: [Restaurant]
    let isLoading: Bool
    let onSwipe: (Restaurant, SwipeDirection) async -> Void
    let onAdvance: (Restaurant) -> Void

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    // Derived once from stable screen bounds — no GeometryReader, no mid-animation fluctuation.
    // The -40 accounts for SwipeView's .padding(.horizontal, 20).
    private var cardW: CGFloat { min(UIScreen.main.bounds.width - 40, 360) }
    private var cardH: CGFloat { min(UIScreen.main.bounds.height * 0.65, 490) }

    var body: some View {
        Group {
            if isLoading {
                skeletonStack
            } else if restaurants.isEmpty {
                emptyState
            } else {
                cardStack
            }
        }
        .frame(height: cardH + 20)
    }

    private var cardStack: some View {
        ZStack(alignment: .top) {
            if restaurants.count > 1 {
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
                    .frame(width: cardW, height: cardH)
                    .scaleEffect(0.96)
                    .offset(y: 10)
                    .zIndex(0)
            }
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
            .frame(width: cardW, height: cardH)
            .id(restaurants[0].id)
            .zIndex(1)
        }
        .frame(height: cardH + 20, alignment: .top)
    }

    private var skeletonStack: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
                .frame(width: cardW, height: cardH)
                .scaleEffect(0.96)
                .offset(y: 10)
                .zIndex(0)
            SkeletonCardView(width: cardW, height: cardH, theme: theme)
                .zIndex(1)
        }
        .frame(height: cardH + 20, alignment: .top)
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
