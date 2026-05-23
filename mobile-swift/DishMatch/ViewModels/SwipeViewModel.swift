import Foundation
import UIKit

@MainActor
final class SwipeViewModel: ObservableObject {
    @Published private(set) var swipedIds: Set<UUID> = []
    @Published var memberProgress: [UUID: Int] = [:]
    @Published var matchedRestaurant: Restaurant?
    @Published var showMatch = false
    @Published var navigateToResults = false
    @Published var isLoadingRestaurants = true
    private var didNavigateToResults = false
    private var didShowMatch = false

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
        isLoadingRestaurants = true
        defer { isLoadingRestaurants = false }
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { [sessionId, sessionVM] in
                    try await sessionVM?.fetchRestaurants(sessionId: sessionId)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                    throw CancellationError()
                }
                _ = try await group.next()
                group.cancelAll()
            }
        } catch {
            print("[SwipeViewModel] fetchRestaurants failed or timed out: \(error). Falling back to mocks.")
            // Detach so this survives a parent .task cancellation (e.g. SwipeView re-mount).
            let sid = sessionId
            let svm = sessionVM
            Task.detached {
                do {
                    try await svm?.fetchRestaurants(sessionId: sid, mock: true)
                } catch {
                    print("[SwipeViewModel] mock fallback also failed: \(error)")
                }
            }
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
                triggerMatch(r)
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
            self?.triggerMatch(p.restaurant)
        }
        ws.onPhaseChange = { [weak self] p in
            if p.phase == .results || p.phase == .matched {
                self?.requestNavigateToResults()
            }
        }
        ws.onTop3Ready = { [weak self] _ in
            self?.requestNavigateToResults()
        }
    }

    func triggerMatch(_ restaurant: Restaurant) {
        guard !didShowMatch else { return }
        didShowMatch = true
        matchedRestaurant = restaurant
        showMatch = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func requestNavigateToResults() {
        guard !didNavigateToResults else { return }
        didNavigateToResults = true
        navigateToResults = true
    }
}
