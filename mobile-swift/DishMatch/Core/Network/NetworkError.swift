import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case notFound
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:       return "Session expired. Please log in again."
        case .notFound:           return "Resource not found."
        case .invalidResponse:    return "Invalid server response."
        case .serverError(let m): return m
        }
    }
}

private struct ErrorResponse: Decodable { let detail: String }
