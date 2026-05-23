import SwiftUI

struct RestaurantCardView: View {
    let restaurant: Restaurant
    let onSwipeLeft:  () -> Void
    let onSwipeRight: () -> Void
    // Houston-only: pass sessionId + sessionVM to enable the personalized-fit section.
    var sessionId: UUID? = nil
    var sessionVM: SessionViewModel? = nil

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @State private var offset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero

    // Personalized-fit state
    @State private var fitExpanded = false
    @State private var fit: PersonalizedFit?
    @State private var fitLoading = false

    private let swipeThreshold: CGFloat = 80

    private var totalOffsetX: CGFloat { offset.width + dragTranslation.width }
    private var rotationDegrees: Double { Double(totalOffsetX / 200) * 18 }
    private var likeProgress: CGFloat { min(max(totalOffsetX / swipeThreshold, 0), 1) }
    private var passProgress: CGFloat { min(max(-totalOffsetX / swipeThreshold, 0), 1) }

    // Only show the section for Houston seed restaurants
    private var isHouston: Bool { restaurant.isSeed == true }

    var body: some View {
        ZStack {
            cardContent
            likeOverlay
            passOverlay
        }
        .clipped()                              // hard-clip so AsyncImage / long names can't push past the card edge
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
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
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

                // Personalized-fit section (Houston only)
                if isHouston && sessionId != nil {
                    fitSection
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

    // MARK: Personalized fit section

    @ViewBuilder private var fitSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header — always visible
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    fitExpanded.toggle()
                }
                if fitExpanded && fit == nil && !fitLoading {
                    Task { await loadFit() }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("✨ Why this fits you")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.primary)
                    Spacer()
                    Image(systemName: fitExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.primary.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.primary.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Expanded content
            if fitExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if fitLoading && fit == nil {
                        HStack(spacing: 8) {
                            ProgressView().tint(theme.primary).scaleEffect(0.7)
                            Text("Personalizing…")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.vertical, 6)
                    } else if let fit = fit {
                        fitContent(fit)
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder private func fitContent(_ fit: PersonalizedFit) -> some View {
        // Personalized reason
        Text(fit.personalizedReason)
            .font(.system(size: 12))
            .foregroundColor(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

        // Eligible items
        if !fit.eligibleItems.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(fit.eligibleItems.prefix(4)) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(theme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(item.name)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(theme.text)
                                ForEach(item.tags.prefix(2), id: \.self) { tag in
                                    Text(tagEmoji(tag) + tag)
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.primary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(theme.primary.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                            if let quote = item.reviewQuote, let source = item.reviewSource {
                                Text("\"\(quote)\" \u{2014} \(source)")
                                    .font(.system(size: 10, design: .default))
                                    .foregroundColor(theme.textTertiary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }

        // Budget fit
        HStack(spacing: 4) {
            Image(systemName: budgetFitIcon(fit.budgetFit))
                .font(.system(size: 11))
                .foregroundColor(budgetFitColor(fit.budgetFit))
            Text(budgetFitLabel(fit.budgetFit))
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
        }

        // Headline vibe quote
        if let q = fit.headlineQuote {
            Text("\"\(q.text)\" \u{2014} \(q.source)")
                .font(.system(size: 11, design: .default).italic())
                .foregroundColor(theme.textTertiary)
                .lineLimit(3)
        }
    }

    // MARK: Helpers

    private func loadFit() async {
        guard let sid = sessionId, let svm = sessionVM else { return }
        fitLoading = true
        defer { fitLoading = false }
        fit = try? await svm.fetchPersonalizedFit(restaurantId: restaurant.id, sessionId: sid)
    }

    func prefetchFit() {
        guard isHouston, sessionId != nil, fit == nil, !fitLoading else { return }
        Task { await loadFit() }
    }

    private func tagEmoji(_ tag: String) -> String {
        switch tag {
        case "vegan", "plant-based": return "🌱 "
        case "gluten-free": return "🌾 "
        case "dairy-free": return "🥛 "
        case "halal": return "☪️ "
        case "kosher": return "✡️ "
        default: return ""
        }
    }

    private func budgetFitIcon(_ fit: String) -> String {
        switch fit {
        case "match": return "checkmark.circle.fill"
        case "over": return "exclamationmark.triangle.fill"
        case "under": return "chevron.down.circle.fill"
        default: return "minus.circle"
        }
    }

    private func budgetFitColor(_ fit: String) -> Color {
        switch fit {
        case "match": return .green
        case "over": return .orange
        default: return theme.textTertiary
        }
    }

    private func budgetFitLabel(_ fit: String) -> String {
        switch fit {
        case "match": return "Within your budget"
        case "over": return "Above your budget"
        case "under": return "Below your budget"
        default: return "Budget not set"
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
