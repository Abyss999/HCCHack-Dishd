import Foundation
import UIKit

@MainActor
final class SwipeViewModel: ObservableObject {
    @Published private(set) var swipedIds: Set<UUID> = []
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

    var swipeCount: Int { swipedIds.count }
    var canSeeResults: Bool { swipedIds.count >= 5 }

    var visibleRestaurants: [Restaurant] {
        let all = sessionVM?.restaurants ?? []
        return all.filter { !swipedIds.contains($0.id) }
    }

    func markSwiped(_ restaurant: Restaurant) {
        swipedIds.insert(restaurant.id)
    }

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
            let ack = try await sessionVM?.submitSwipe(
                sessionId: sessionId,
                restaurantId: restaurant.id,
                direction: direction
            )
            if let r = ack?.instantMatch {
                matchedRestaurant = r
                showMatch = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
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
