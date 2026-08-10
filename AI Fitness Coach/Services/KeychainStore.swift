import Foundation
import Security

final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "com.unxry.aifitnesscoach"
    private let yandexAPIKeyAccount = "yandex-api-key"
    private let yandexFolderIDAccount = "yandex-folder-id"

    private init() {}

    func saveYandexAPIKey(_ key: String) {
        save(key, account: yandexAPIKeyAccount)
    }

    func readYandexAPIKey() -> String {
        read(account: yandexAPIKeyAccount)
    }

    func deleteYandexAPIKey() {
        delete(account: yandexAPIKeyAccount)
    }

    func saveYandexFolderID(_ folderID: String) {
        save(folderID, account: yandexFolderIDAccount)
    }

    func readYandexFolderID() -> String {
        read(account: yandexFolderIDAccount)
    }

    func deleteYandexFolderID() {
        delete(account: yandexFolderIDAccount)
    }

    private func save(_ value: String, account: String) {
        delete(account: account)

        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
