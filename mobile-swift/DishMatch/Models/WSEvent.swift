import Foundation

enum WSEventType: String, Codable {
    case memberJoined  = "member_joined"
    case swipeProgress = "swipe_progress"
    case instantMatch  = "instant_match"
    case phaseChange   = "phase_change"
    case top3Ready     = "top3_ready"
}

struct WSEnvelope: Decodable {
    let type: WSEventType
    let payload: RawJSON
}

struct MemberJoinedPayload: Decodable {
    let userId: UUID
    let name: String
}

struct SwipeProgressPayload: Decodable {
    let userId: UUID
    let swipeCount: Int
}

struct InstantMatchPayload: Decodable {
    let restaurant: Restaurant
}

struct PhaseChangePayload: Decodable {
    let phase: SessionStatus
}

struct Top3ReadyPayload: Decodable {
    let results: [SessionResult]
}

// Captures any JSON value so we can re-decode payload sub-objects on demand.
struct RawJSON: Codable {
    private let raw: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let obj = try? container.decode([String: RawJSON].self) {
            raw = obj
        } else if let arr = try? container.decode([RawJSON].self) {
            raw = arr
        } else if let str = try? container.decode(String.self) {
            raw = str
        } else if let num = try? container.decode(Double.self) {
            raw = num
        } else if let bool = try? container.decode(Bool.self) {
            raw = bool
        } else {
            raw = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch raw {
        case let obj as [String: RawJSON]: try container.encode(obj)
        case let arr as [RawJSON]:         try container.encode(arr)
        case let str as String:            try container.encode(str)
        case let num as Double:            try container.encode(num)
        case let bool as Bool:             try container.encode(bool)
        default:                           try container.encodeNil()
        }
    }

    func toData() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
