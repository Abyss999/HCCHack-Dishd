import Foundation
import Security

enum KeychainService {
    private static let service = "com.dishmatch.app"
    private static let sharedAccessGroup = "group.com.dishmatch.app"

    static func set(_ value: String, forKey key: String, shared: Bool = false) throws {
        let data = Data(value.utf8)
        var query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        if shared { query[kSecAttrAccessGroup] = sharedAccessGroup }
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData] = data
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    static func get(_ key: String, shared: Bool = false) throws -> String? {
        var query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  key,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne
        ]
        if shared { query[kSecAttrAccessGroup] = sharedAccessGroup }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { throw KeychainError.unhandledError(status) }
        return string
    }

    static func delete(_ key: String, shared: Bool = false) {
        var query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        if shared { query[kSecAttrAccessGroup] = sharedAccessGroup }
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error {
        case unhandledError(OSStatus)
    }
}
