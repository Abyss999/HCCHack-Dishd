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
    let menu: [String]?
    let vibeBlurb: String?
    let isSeed: Bool?
}

// MARK: - Personalized Fit (Houston-only)

struct PersonalizedFitItem: Codable, Identifiable {
    let name: String
    let tags: [String]
    let reviewQuote: String?
    let reviewSource: String?

    var id: String { name }
}

struct PersonalizedFitHeadlineQuote: Codable {
    let text: String
    let source: String
}

struct PersonalizedFit: Codable {
    let eligibleItems: [PersonalizedFitItem]
    let personalizedReason: String
    let budgetFit: String  // "match" | "over" | "under" | "unknown"
    let headlineQuote: PersonalizedFitHeadlineQuote?
}

struct VibePick: Codable {
    let pickRestaurantId: UUID
    let name: String
    let reasoning: String
}

struct SessionResult: Codable, Identifiable {
    let restaurant: Restaurant
    let scorePct: Double
    let yesCount: Int
    let total: Int

    var id: UUID { restaurant.id }
}
