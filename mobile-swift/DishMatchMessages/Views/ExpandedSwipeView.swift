import SwiftUI

struct ExpandedSwipeView: View {
    let sessionId: UUID
    let sessionCode: String
    let token: String
    var onSendUpdatedMessage: (Session) -> Void
    var onDone: () -> Void

    @State private var restaurants: [Restaurant] = []
    @State private var swipedIds: Set<UUID> = []
    @State private var results: [SessionResult] = []
    @State private var phase: Phase = .loading
    @State private var errorMessage: String?
    @State private var currentSession: Session?

    @Environment(\.colorScheme) var colorScheme

    private var service: MessageSessionService { MessageSessionService(token: token) }

    enum Phase { case loading, swiping, results }

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.039).ignoresSafeArea()

            switch phase {
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color(red: 0.851, green: 0.467, blue: 0.341))
                    Text("Joining session…")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

            case .swiping:
                swipeContent

            case .results:
                ExpandedResultsView(results: results, sessionCode: sessionCode, onDone: onDone)
            }

            if let errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
        .task { await loadSession() }
    }

    @ViewBuilder
    private var swipeContent: some View {
        let primary = Color(red: 0.851, green: 0.467, blue: 0.341)
        let visible = restaurants.filter { !swipedIds.contains($0.id) }

        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dishd")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Code: \(sessionCode)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(swipedIds.count)/\(restaurants.count) swiped")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Button("Done") { onDone() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            SwipeStackView(
                restaurants: visible,
                onSwipe: { restaurant, direction in
                    await submitSwipe(restaurant: restaurant, direction: direction)
                },
                onAdvance: { restaurant in
                    swipedIds.insert(restaurant.id)
                }
            )
            .environmentObject(ThemeStore())
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            if swipedIds.count >= 5 {
                Button("See Results") {
                    Task { await loadResults() }
                }
                .buttonStyle(.borderedProminent)
                .tint(primary)
                .padding(.bottom, 20)
            }
        }
    }

    private func loadSession() async {
        phase = .loading
        do {
            _ = try? await service.joinSessionById(sessionId: sessionId)
            restaurants = try await service.fetchRestaurants(sessionId: sessionId)
            phase = .swiping
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitSwipe(restaurant: Restaurant, direction: SwipeDirection) async {
        do {
            _ = try await service.submitSwipe(
                sessionId: sessionId,
                restaurantId: restaurant.id,
                direction: direction
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadResults() async {
        do {
            results = try await service.fetchResults(sessionId: sessionId)
            phase = .results
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
