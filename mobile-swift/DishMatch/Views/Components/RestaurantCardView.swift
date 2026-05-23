import SwiftUI

struct RestaurantCardView: View {
    let restaurant: Restaurant
    let onSwipeLeft:  () -> Void
    let onSwipeRight: () -> Void

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @State private var offset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero

    private let swipeThreshold: CGFloat = 80

    private var totalOffsetX: CGFloat { offset.width + dragTranslation.width }
    private var rotationDegrees: Double { Double(totalOffsetX / 200) * 18 }
    private var likeProgress: CGFloat { min(max(totalOffsetX / swipeThreshold, 0), 1) }
    private var passProgress: CGFloat { min(max(-totalOffsetX / swipeThreshold, 0), 1) }

    var body: some View {
        ZStack {
            cardContent
            likeOverlay
            passOverlay
        }
        // No inner .frame(maxWidth: .infinity) — SwipeStackView pins us to an explicit
        // (capped) width. Letting both sides claim "infinity" was the source of the card
        // expanding past the screen mid-swipe.
        .clipped()
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .rotationEffect(.degrees(rotationDegrees))
        .offset(x: totalOffsetX,
                y: (offset.height + dragTranslation.height) * 0.15)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: dragTranslation)
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    let x = value.translation.width
                    if x > swipeThreshold {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            offset = CGSize(width: 600, height: value.translation.height)
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSwipeRight() }
                    } else if x < -swipeThreshold {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            offset = CGSize(width: -600, height: value.translation.height)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSwipeLeft() }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            offset = .zero
                        }
                    }
                }
        )
    }

    // MARK: Card body

    @ViewBuilder private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo — fixed height (not maxHeight) so AsyncImage's intrinsic size
            // never inflates the row past the card frame.
            ZStack(alignment: .bottomLeading) {
                if let urlStr = restaurant.photoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                        default:
                            theme.surface
                        }
                    }
                } else {
                    ZStack {
                        theme.surface
                        Image(systemName: "fork.knife")
                            .font(.system(size: 40))
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }
            .frame(height: 280)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(restaurant.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    if let tier = restaurant.priceTier {
                        Text(tier)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.primary)
                            .fixedSize()
                    }
                }

                if let address = restaurant.address {
                    Label(address, systemImage: "mappin.circle")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                if let desc = restaurant.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .padding(.top, 2)
                }

                HStack(spacing: 6) {
                    if let rating = restaurant.rating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(restaurant.cuisineTags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(theme.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(theme.chipBg)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            offset = CGSize(width: -600, height: 0)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSwipeLeft() }
                    } label: {
                        Label("Pass", systemImage: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.pass)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.pass.opacity(0.4), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            offset = CGSize(width: 600, height: 0)
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSwipeRight() }
                    } label: {
                        Label("Like", systemImage: "heart.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.like)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(theme.cardBg)
        }
    }

    // MARK: Overlays

    @ViewBuilder private var likeOverlay: some View {
        Color(hex: "#4caf50").opacity(0.35 * likeProgress)
            .cornerRadius(16)
            .overlay(alignment: .topLeading) {
                Text("LIKE")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(Color(hex: "#4caf50"))
                    .padding(12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#4caf50"), lineWidth: 3))
                    .rotationEffect(.degrees(-15))
                    .padding(.top, 40)
                    .padding(.leading, 20)
                    .opacity(likeProgress)
            }
    }

    @ViewBuilder private var passOverlay: some View {
        Color(hex: "#ef5350").opacity(0.35 * passProgress)
            .cornerRadius(16)
            .overlay(alignment: .topTrailing) {
                Text("PASS")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(Color(hex: "#ef5350"))
                    .padding(12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#ef5350"), lineWidth: 3))
                    .rotationEffect(.degrees(15))
                    .padding(.top, 40)
                    .padding(.trailing, 20)
                    .opacity(passProgress)
            }
    }
}
