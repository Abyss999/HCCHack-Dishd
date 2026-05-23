import SwiftUI

struct MatchOverlay: View {
    let restaurant: Restaurant
    let onContinue: () -> Void

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            ConfettiView()
            VStack(spacing: 24) {
                Text("🎉 It's a Match!")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    Text("Everyone agreed on")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                    Text(restaurant.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(theme.primary)
                        .multilineTextAlignment(.center)
                }

                if let urlStr = restaurant.photoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color(hex: "#1a1a1a")
                        }
                    }
                    .frame(width: 200, height: 140)
                    .cornerRadius(16)
                }

                Button(action: onContinue) {
                    Text("See Results")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            .padding(32)
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Confetti

private struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let speed: CGFloat
    let drift: CGFloat
    let rotation: Double
}

private struct ConfettiView: View {
    private static let colors: [Color] = [
        Color(hex: "#d97757"),
        Color(hex: "#f5a76d"),
        Color(hex: "#c7622a"),
        Color(hex: "#e8a885"),
        Color(hex: "#ffffff")
    ]

    @State private var particles: [Particle] = (0..<60).map { _ in
        Particle(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: -0.3...0),
            color: colors.randomElement()!,
            size: CGFloat.random(in: 6...14),
            speed: CGFloat.random(in: 0.003...0.008),
            drift: CGFloat.random(in: -0.002...0.002),
            rotation: Double.random(in: 0...360)
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                for p in particles {
                    let rect = CGRect(
                        x: p.x * size.width,
                        y: p.y * size.height,
                        width: p.size,
                        height: p.size * 0.6
                    )
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(p.color.opacity(0.85))
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                for i in particles.indices {
                    particles[i].y += 1.4
                    particles[i].x += particles[i].drift * 200
                }
            }
        }
    }
}
