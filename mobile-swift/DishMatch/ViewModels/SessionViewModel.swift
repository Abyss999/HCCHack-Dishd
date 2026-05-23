import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var session: Session?
    @Published var restaurants: [Restaurant] = []
    @Published var results: [SessionResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let auth: AuthStore

    init(api: APIClient = .shared, auth: AuthStore = .shared) {
        self.api = api
        self.auth = auth
    }

    var token: String? { auth.accessToken }

    func createSession(lat: Double, lng: Double) async throws -> Session {
        isLoading = true; defer { isLoading = false }
        let body = CreateSessionBody(locationLat: lat, locationLng: lng)
        let s: Session = try await api.post("/sessions", body: body, token: token)
        session = s
        return s
    }

    func joinSession(code: String) async throws -> Session {
        isLoading = true; defer { isLoading = false }
        let found: Session = try await api.get("/sessions/\(code.uppercased())", token: token)
        let joined: Session = try await api.post("/sessions/\(found.id)/join",
                                                  body: _Empty(), token: token)
        session = joined
        return joined
    }

    func fetchSession(_ id: UUID) async throws {
        session = try await api.get("/sessions/\(id)/status", token: token)
    }

    func startSwiping(_ id: UUID) async throws {
        isLoading = true; defer { isLoading = false }
        session = try await api.post("/sessions/\(id)/start", body: _Empty(), token: token)
    }

    func fetchRestaurants(sessionId: UUID) async throws {
        isLoading = true; defer { isLoading = false }
        restaurants = try await api.get("/restaurants?session_id=\(sessionId)", token: token)
    }

    func submitSwipe(sessionId: UUID, restaurantId: UUID, direction: SwipeDirection) async throws {
        let body = SwipeRequest(restaurantId: restaurantId, direction: direction)
        let _: SwipeAck = try await api.post("/sessions/\(sessionId)/swipe", body: body, token: token)
    }

    func fetchResults(sessionId: UUID) async throws {
        isLoading = true; defer { isLoading = false }
        let out: ResultsOut = try await api.get("/sessions/\(sessionId)/results", token: token)
        results = out.top
    }
}

private struct CreateSessionBody: Encodable {
    let locationLat: Double
    let locationLng: Double
}

private struct ResultsOut: Decodable {
    let top: [SessionResult]
}

private struct _Empty: Encodable {}
