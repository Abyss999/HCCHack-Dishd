import SwiftUI

// MARK: - Skeleton card shown while restaurants are loading

struct SkeletonCardView: View {
    let width: CGFloat
    let height: CGFloat
    let theme: AppTheme
    @State private var shimmerX: CGFloat = -1

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 0) {
                theme.surfaceLight
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4).fill(theme.surfaceLight).frame(width: 180, height: 22)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4).fill(theme.surfaceLight).frame(width: 40, height: 16)
                    }
                    RoundedRectangle(cornerRadius: 4).fill(theme.surfaceLight).frame(width: 140, height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(theme.surfaceLight).frame(maxWidth: .infinity).frame(height: 28)
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8).fill(theme.surfaceLight).frame(width: 60, height: 24)
                        }
                        Spacer()
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.07), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: UnitPoint(x: shimmerX - 0.5, y: 0),
                endPoint: UnitPoint(x: shimmerX + 0.5, y: 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(16)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmerX = 1.5
            }
        }
    }
}

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
        // Fill the full frame so every card is identical in size regardless of content.
        VStack(alignment: .leading, spacing: 0) {
            // Photo — GeometryReader pins image to the card's actual pixel width so
            // scaledToFill never overflows sideways regardless of the image's aspect ratio.
            GeometryReader { geo in
                ZStack {
                    if let urlStr = restaurant.photoUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: 280)
                                    .clipped()
                            default:
                                theme.surface
                                    .frame(width: geo.size.width, height: 280)
                            }
                        }
                        .frame(width: geo.size.width, height: 280)
                    } else {
                        ZStack {
                            theme.surface
                            Image(systemName: "fork.knife")
                                .font(.system(size: 40))
                                .foregroundColor(theme.textTertiary)
                        }
                        .frame(width: geo.size.width, height: 280)
                    }
                }
            }
            .frame(height: 280)
            .clipped()

            // Info — stretches to fill whatever height remains in the card frame.
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

                let displayDesc = restaurant.description ?? restaurant.vibeBlurb
                let isAiDesc = restaurant.description == nil && restaurant.vibeBlurb != nil
                if let desc = displayDesc, !desc.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        if isAiDesc {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                                .foregroundColor(theme.primary.opacity(0.7))
                                .padding(.top, 1)
                        }
                    }
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

                // Pushes buttons to the bottom of the info section regardless of how
                // much content is above — keeps card height visually identical across cards.
                Spacer(minLength: 0)

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.cardBg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
