import Foundation
import Security

/// A secondary copy of the workout-history data that outlives the app's
/// sandbox, so history survives deleting and reinstalling the app.
protocol HistoryBackup {
    func read() -> Data?
    func write(_ data: Data)
}

/// Stores the history JSON as a generic-password keychain item. Keychain
/// items persist on-device after the app is deleted, which is what makes
/// reinstall-restore work. Unlike iCloud storage, this needs no paid
/// developer-program capability.
struct KeychainBackup: HistoryBackup {
    var service = "Houston-Warren.busy-timer"
    var account = "workout-history"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func read() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    func write(_ data: Data) {
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return }

        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
