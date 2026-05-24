import Foundation

struct SessionInfo {
    let sessionId: UUID
    let code: String
}

enum SessionURLParser {
    private static let scheme = "dishd"
    private static let host = "session"

    static func encode(session: Session) -> URL {
        var comps = URLComponents()
        comps.scheme = scheme
        comps.host = host
        comps.queryItems = [
            URLQueryItem(name: "id", value: session.id.uuidString),
            URLQueryItem(name: "code", value: session.code)
        ]
        return comps.url!
    }

    static func parse(_ url: URL?) -> SessionInfo? {
        guard let url,
              url.scheme == scheme,
              url.host == host,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idStr = comps.queryItems?.first(where: { $0.name == "id" })?.value,
              let id = UUID(uuidString: idStr),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        return SessionInfo(sessionId: id, code: code)
    }
}
