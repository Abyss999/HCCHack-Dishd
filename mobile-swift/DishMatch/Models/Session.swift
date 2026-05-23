import Foundation

enum SessionStatus: String, Codable, Equatable {
    case lobby, swiping, results, matched
}

struct Session: Codable, Identifiable, Equatable {
    let id: UUID
    let code: String
    let hostUserId: UUID
    var status: SessionStatus
    let locationLat: Double?
    let locationLng: Double?
    let locationLabel: String?
    var members: [SessionMember]
    let matchedRestaurantId: UUID?
    var soloMode: Bool?
    let cuisineOverrides: [String]?
    let radiusKmOverride: Double?
    let budgetOverrides: [String]?
    let swipeCeilingOverride: Int?
    let topN: Int?
    let createdAt: Date
}

struct SessionMember: Codable, Identifiable, Equatable {
    let userId: UUID
    let name: String
    let joinedAt: Date

    var id: UUID { userId }
}
