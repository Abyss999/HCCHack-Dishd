import Foundation

actor MessageSessionService {
    private let api = APIClient.shared
    private let token: String

    init(token: String) {
        self.token = token
    }

    func createSession(lat: Double, lng: Double) async throws -> Session {
        struct Body: Encodable { let locationLat: Double; let locationLng: Double }
        return try await api.post("/sessions", body: Body(locationLat: lat, locationLng: lng), token: token)
    }

    func joinSession(code: String) async throws -> Session {
        let found: Session = try await api.get("/sessions/\(code.uppercased())", token: token)
        return try await joinSessionById(sessionId: found.id)
    }

    func joinSessionById(sessionId: UUID) async throws -> Session {
        struct Empty: Encodable {}
        return try await api.post("/sessions/\(sessionId)/join", body: Empty(), token: token)
    }

    func fetchRestaurants(sessionId: UUID) async throws -> [Restaurant] {
        return try await api.get("/restaurants?session_id=\(sessionId)", token: token)
    }

    func submitSwipe(sessionId: UUID, restaurantId: UUID, direction: SwipeDirection) async throws -> SwipeAck {
        return try await api.post(
            "/sessions/\(sessionId)/swipe",
            body: SwipeRequest(restaurantId: restaurantId, direction: direction),
            token: token
        )
    }

    func fetchResults(sessionId: UUID) async throws -> [SessionResult] {
        struct Out: Decodable { let top: [SessionResult] }
        let out: Out = try await api.get("/sessions/\(sessionId)/results", token: token)
        return out.top
    }
}
