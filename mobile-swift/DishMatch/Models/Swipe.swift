import Foundation

enum SwipeDirection: String, Encodable {
    case yes, no
}

struct SwipeRequest: Encodable {
    let restaurantId: UUID
    let direction: SwipeDirection
}

struct SwipeAck: Decodable {
    let accepted: Bool
    let instantMatch: Restaurant?
}
