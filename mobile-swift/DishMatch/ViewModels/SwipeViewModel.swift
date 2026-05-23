import Foundation
import UIKit

@MainActor
final class SwipeViewModel: ObservableObject {
    @Published var swipeCount = 0
    @Published var memberProgress: [UUID: Int] = [:]
    @Published var matchedRestaurant: Restaurant?
    @Published var showMatch = false
    @Published var navigateToResults = false

    let sessionId: UUID
    private(set) var sessionVM: SessionViewModel?
    let ws = WebSocketService()

    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    var restaurants: [Restaurant] { sessionVM?.restaurants ?? [] }
    var canSeeResults: Bool { swipeCount >= 5 }

    func bind(sessionVM: SessionViewModel) {
        guard self.sessionVM == nil else { return }
        self.sessionVM = sessionVM
        setupWS()
    }

    func load() async {
        do {
            try await sessionVM?.fetchRestaurants(sessionId: sessionId)
        } catch {
            print("[SwipeViewModel] fetchRestaurants failed: \(error)")
        }
    }

    func swipe(restaurant: Restaurant, direction: SwipeDirection) async {
        do {
            try await sessionVM?.submitSwipe(
                sessionId: sessionId,
                restaurantId: restaurant.id,
                direction: direction
            )
            swipeCount += 1
        } catch {
            print("[SwipeViewModel] submitSwipe failed: \(error)")
        }
    }

    private func setupWS() {
        guard let token = sessionVM?.token else { return }
        ws.connect(sessionId: sessionId, token: token)

        ws.onSwipeProgress = { [weak self] p in
            self?.memberProgress[p.userId] = p.swipeCount
        }
        ws.onInstantMatch = { [weak self] p in
            self?.matchedRestaurant = p.restaurant
            self?.showMatch = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        ws.onPhaseChange = { [weak self] p in
            if p.phase == .results || p.phase == .matched {
                self?.navigateToResults = true
            }
        }
        ws.onTop3Ready = { [weak self] _ in
            self?.navigateToResults = true
        }
    }
}
