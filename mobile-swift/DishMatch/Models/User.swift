import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let name: String
    var preferences: UserPreferences?
}

struct UserPreferences: Codable {
    var dietaryRestrictions: [String]
    var cuisinePreferences: [String]
    var budgetRange: String?
    var maxDistanceKm: Double
}
