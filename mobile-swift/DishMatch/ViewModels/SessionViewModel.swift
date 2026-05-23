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

    func createSession(
        lat: Double, lng: Double,
        soloMode: Bool = false,
        locationLabel: String? = nil,
        cuisineOverrides: [String]? = nil,
        radiusKmOverride: Double? = nil,
        budgetOverrides: [String]? = nil,
        swipeCeilingOverride: Int? = nil
    ) async throws -> Session {
        isLoading = true; defer { isLoading = false }
        let body = CreateSessionBody(
            locationLat: lat, locationLng: lng, soloMode: soloMode,
            locationLabel: locationLabel,
            cuisineOverrides: cuisineOverrides,
            radiusKmOverride: radiusKmOverride,
            budgetOverrides: budgetOverrides,
            swipeCeilingOverride: swipeCeilingOverride
        )
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

    func fetchRestaurants(sessionId: UUID, mock: Bool = false) async throws {
        isLoading = true; defer { isLoading = false }
        restaurants = []  // clear stale data so a failed fetch can't fall back to a prior session's list
        let path = "/restaurants?session_id=\(sessionId)" + (mock ? "&mock=true" : "")
        restaurants = try await api.get(path, token: token)
    }

    func submitSwipe(sessionId: UUID, restaurantId: UUID, direction: SwipeDirection) async throws -> SwipeAck {
        let body = SwipeRequest(restaurantId: restaurantId, direction: direction)
        return try await api.post("/sessions/\(sessionId)/swipe", body: body, token: token)
    }

    func fetchResults(sessionId: UUID) async throws {
        isLoading = true; defer { isLoading = false }
        let out: ResultsOut = try await api.get("/sessions/\(sessionId)/results", token: token)
        results = out.top
    }

    func fetchVibePick(sessionId: UUID) async throws -> VibePick {
        try await api.get("/sessions/\(sessionId)/vibe-pick", token: token)
    }

    func fetchPersonalizedFit(restaurantId: UUID, sessionId: UUID) async throws -> PersonalizedFit {
        try await api.get("/restaurants/\(restaurantId)/personalized-fit?session_id=\(sessionId)", token: token)
    }

    func fetchUserSessions() async throws -> [Session] {
        try await api.get("/users/me/sessions", token: token)
    }

    func leaveSession(_ id: UUID) async throws {
        try await api.postNoContent("/sessions/\(id)/leave", body: _Empty(), token: token)
    }

    func deleteSession(_ id: UUID) async throws {
        try await api.delete("/sessions/\(id)", token: token)
    }
}

private struct CreateSessionBody: Encodable {
    let locationLat: Double
    let locationLng: Double
    let soloMode: Bool
    let locationLabel: String?
    let cuisineOverrides: [String]?
    let radiusKmOverride: Double?
    let budgetOverrides: [String]?
    let swipeCeilingOverride: Int?
}

private struct ResultsOut: Decodable {
    let top: [SessionResult]
}

private struct _Empty: Codable {}
