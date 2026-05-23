import Foundation

struct Restaurant: Codable, Identifiable {
    let id: UUID
    let googlePlaceId: String
    let name: String
    let cuisineTags: [String]
    let priceTier: String?
    let rating: Double?
    let photoUrl: String?
    let address: String?
    let lat: Double
    let lng: Double
    let description: String?
}

struct SessionResult: Codable, Identifiable {
    let restaurant: Restaurant
    let scorePct: Double
    let yesCount: Int
    let total: Int

    var id: UUID { restaurant.id }
}
