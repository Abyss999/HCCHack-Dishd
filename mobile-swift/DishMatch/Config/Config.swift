import Foundation

enum Config {
    static var apiBaseURL: URL {
        let str = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
                  ?? "http://localhost:8000"
        return URL(string: str)!
    }

    static var wsBaseURL: URL {
        let http = apiBaseURL.absoluteString
        let ws = http
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://",  with: "ws://")
        return URL(string: ws)!
    }
}
