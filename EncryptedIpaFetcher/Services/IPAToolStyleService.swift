// Adapted from PancakeStore's MuffinStoreJailed IPATool implementation:
// https://github.com/jailbreakdotparty/PancakeStore/blob/main/MuffinStoreJailed/Functions/IPATool.swift
import CryptoKit
import Foundation
import Security

final class IPAToolStyleService {
    enum AuthenticationResult: Hashable {
        case authenticated(accountName: String?)
        case twoFactorRequired(message: String)
    }

    enum ServiceError: Error, LocalizedError {
        case invalidCredentials
        case invalidSearchTerm
        case notAuthenticated
        case invalidResponse
        case authenticationFailed(String)
        case missingDownloadURL
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return L10n.text("error.invalidCredentials")
            case .invalidSearchTerm:
                return L10n.text("error.invalidSearchTerm")
            case .notAuthenticated:
                return L10n.text("error.notAuthenticated")
            case .invalidResponse:
                return L10n.text("error.invalidResponse")
            case let .authenticationFailed(message):
                return String(format: L10n.text("error.authenticationFailed"), message)
            case .missingDownloadURL:
                return L10n.text("error.noDownloadURL")
            case .saveFailed:
                return L10n.text("error.saveAuth")
            }
        }
    }

    private struct PersistedAuth: Codable {
        let appleID: String
        let password: String
        let guid: String
        let accountName: String?
        let authHeaders: [String: String]
        let pod: String
        let cookieArchive: Data?
    }

    private let session: URLSession
    private let userAgent = "Configurator/2.17 (Macintosh; OS X 15.2; 24C5089c) AppleWebKit/0620.1.16.11.6"

    private var appleID = ""
    private var password = ""
    private var guid: String?
    private var accountName: String?
    private var authHeaders: [String: String]?
    private var authCookies: [HTTPCookie]?
    private var pod: String?

    var isAuthenticated: Bool {
        authHeaders != nil && pod != nil && !appleID.isEmpty
    }

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieStorage = HTTPCookieStorage.shared
            configuration.httpShouldSetCookies = true
            self.session = URLSession(configuration: configuration)
        }
    }

    func login(_ request: LoginRequest) async throws -> AuthenticationResult {
        let trimmedID = request.appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = request.password.trimmingCharacters(in: .whitespacesAndNewlines)
        let twoFactorCode = request.twoFactorCode?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedID.contains("@"), trimmedPassword.count >= 6 else {
            throw ServiceError.invalidCredentials
        }

        appleID = trimmedID
        password = trimmedPassword

        if guid == nil {
            guid = generateGuid(for: trimmedID)
        }

        do {
            if try restorePersistedAuthIfPossible(for: trimmedID, password: trimmedPassword) {
                return .authenticated(accountName: accountName)
            }
        } catch {
            _ = KeychainAuthStore.delete()
        }

        let authURL = await getBagEndpoint()
        var lastMessage = L10n.text("error.authenticationUnknown")

        for attempt in 1 ... 4 {
            var body: [String: String] = [
                "appleId": trimmedID,
                "password": trimmedPassword,
                "guid": guid ?? "",
                "rmp": "0",
                "why": "signIn",
                "attempt": "\(attempt)"
            ]

            if let twoFactorCode, !twoFactorCode.isEmpty {
                body["code"] = twoFactorCode
                body["securityCode"] = twoFactorCode
            }

            var url = authURL
            if !url.absoluteString.hasSuffix("/") {
                url = URL(string: url.absoluteString + "/") ?? authURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.invalidResponse
            }

            if let podHeader = httpResponse.value(forHTTPHeaderField: "pod"), !podHeader.isEmpty {
                pod = podHeader
            }

            let responseBody = try parsePlistDictionary(data)

            if let dsPersonID = responseBody["dsPersonId"] as? String,
               let token = responseBody["passwordToken"] as? String,
               !dsPersonID.isEmpty,
               !token.isEmpty
            {
                guard
                    let queueInfo = responseBody["download-queue-info"] as? [String: Any],
                    let dsidAny = queueInfo["dsid"]
                else {
                    throw ServiceError.invalidResponse
                }

                let dsid: String
                if let dsidInt = dsidAny as? Int {
                    dsid = String(dsidInt)
                } else if let dsidString = dsidAny as? String {
                    dsid = dsidString
                } else {
                    throw ServiceError.invalidResponse
                }

                guard
                    let storeFront = httpResponse.value(forHTTPHeaderField: "x-set-apple-store-front"),
                    let podValue = pod
                else {
                    throw ServiceError.invalidResponse
                }

                authHeaders = [
                    "X-Dsid": dsid,
                    "iCloud-Dsid": dsid,
                    "X-Apple-Store-Front": storeFront,
                    "X-Token": token
                ]
                authCookies = session.configuration.httpCookieStorage?.cookies

                if let accountInfo = responseBody["accountInfo"] as? [String: Any],
                   let address = accountInfo["address"] as? [String: String]
                {
                    let firstName = address["firstName"] ?? ""
                    let lastName = address["lastName"] ?? ""
                    let joined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                    accountName = joined.isEmpty ? nil : joined
                } else {
                    accountName = nil
                }

                let persisted = PersistedAuth(
                    appleID: trimmedID,
                    password: trimmedPassword,
                    guid: guid ?? "",
                    accountName: accountName,
                    authHeaders: authHeaders ?? [:],
                    pod: podValue,
                    cookieArchive: authCookies.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false) }
                )
                try savePersistedAuth(persisted)
                return .authenticated(accountName: accountName)
            }

            let customerMessage = responseBody["customerMessage"] as? String ?? lastMessage
            lastMessage = customerMessage
            let needs2FA = customerMessage.localizedCaseInsensitiveContains("Configurator_message") ||
                customerMessage.localizedCaseInsensitiveContains("verification") ||
                customerMessage.localizedCaseInsensitiveContains("security code")

            if needs2FA {
                return .twoFactorRequired(message: customerMessage)
            }
        }

        throw ServiceError.authenticationFailed(lastMessage)
    }

    func search(term: String) async throws -> [AppSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw ServiceError.invalidSearchTerm }

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "limit", value: "30")
        ]

        guard let url = components?.url else { throw ServiceError.invalidResponse }
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(AppSearchResponse.self, from: data)
        return decoded.results
    }

    func downloadIPA(for app: AppSearchResult) async throws -> URL {
        guard isAuthenticated else { throw ServiceError.notAuthenticated }

        let appID = String(app.trackId)
        let versionID = try await getVersionIDList(appID: appID).first ?? ""
        let response = try await volumeStoreDownloadProduct(appID: appID, appVersionID: versionID)

        guard
            let songList = response["songList"] as? [[String: Any]],
            let first = songList.first,
            let urlString = first["URL"] as? String,
            let url = URL(string: urlString)
        else {
            throw ServiceError.missingDownloadURL
        }

        if let cookies = authCookies, let cookieStore = session.configuration.httpCookieStorage {
            cookieStore.setCookies(cookies, for: url, mainDocumentURL: nil)
        }

        let (data, _) = try await session.data(from: url)
        let destination = makeDestinationURL(app: app)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private func getVersionIDList(appID: String) async throws -> [String] {
        let response = try await volumeStoreDownloadProduct(appID: appID, appVersionID: "")
        guard
            let songList = response["songList"] as? [[String: Any]],
            let first = songList.first,
            let metadata = first["metadata"] as? [String: Any]
        else {
            return []
        }

        let ids = metadata["softwareVersionExternalIdentifiers"] as? [Int] ?? []
        return ids.map(String.init)
    }

    private func volumeStoreDownloadProduct(appID: String, appVersionID: String) async throws -> [String: Any] {
        guard
            let guid,
            let pod,
            let authHeaders
        else {
            throw ServiceError.notAuthenticated
        }

        var body: [String: String] = [
            "creditDisplay": "",
            "guid": guid,
            "salableAdamId": appID
        ]
        if !appVersionID.isEmpty {
            body["externalVersionId"] = appVersionID
        }

        guard let url = URL(string: "https://p\(pod)-buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/volumeStoreDownloadProduct?guid=\(guid)") else {
            throw ServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let cookies = authCookies, let cookieStore = session.configuration.httpCookieStorage {
            cookieStore.setCookies(cookies, for: url, mainDocumentURL: nil)
        }

        let (data, _) = try await session.data(for: request)
        return try parsePlistDictionary(data)
    }

    private func parsePlistDictionary(_ data: Data) throws -> [String: Any] {
        guard
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else {
            throw ServiceError.invalidResponse
        }
        return plist
    }

    private func makeDestinationURL(app: AppSearchResult) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let rawName = "\(app.trackName)-\(app.trackId)-\(app.version)"
        let safeName = rawName.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return documents.appendingPathComponent(safeName).appendingPathExtension("ipa")
    }

    private func generateGuid(for appleID: String) -> String {
        let defaultGUID = "000C2941396B"
        let defaultPrefixLength = 2
        let guidSeed = "CAFEBABE"
        let guidPosition = 10

        let source = Data((guidSeed + appleID + guidSeed).utf8)
        let hash = Insecure.SHA1.hash(data: source)
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        let defaultPart = defaultGUID.prefix(defaultPrefixLength)
        let start = hex.index(hex.startIndex, offsetBy: guidPosition)
        let end = hex.index(start, offsetBy: defaultGUID.count - defaultPrefixLength)
        let hashPart = hex[start ..< end]
        return (defaultPart + hashPart).uppercased()
    }

    private func getBagEndpoint() async -> URL {
        let fallback = URL(string: "https://auth.itunes.apple.com/auth/v1/native/")!
        guard let guid else { return fallback }

        guard let url = URL(string: "https://init.itunes.apple.com/bag.xml?guid=\(guid)") else {
            return fallback
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await session.data(for: request)
            guard
                !data.isEmpty,
                let xmlString = String(data: data, encoding: .utf8),
                let plistStart = xmlString.range(of: "<plist"),
                let plistEnd = xmlString.range(of: "</plist>")
            else {
                return fallback
            }

            let plistSection = String(xmlString[plistStart.lowerBound ..< plistEnd.upperBound])
            guard
                let cleanData = plistSection.data(using: .utf8),
                let plist = try PropertyListSerialization.propertyList(from: cleanData, options: [], format: nil) as? [String: Any],
                let urlBag = plist["urlBag"] as? [String: Any],
                let endpoint = urlBag["authenticateAccount"] as? String,
                let endpointURL = URL(string: endpoint)
            else {
                return fallback
            }

            return endpointURL
        } catch {
            return fallback
        }
    }

    private func savePersistedAuth(_ auth: PersistedAuth) throws {
        let data = try JSONEncoder().encode(auth)
        guard KeychainAuthStore.save(data: data) else {
            throw ServiceError.saveFailed
        }
    }

    private func restorePersistedAuthIfPossible(for appleID: String, password: String) throws -> Bool {
        guard let data = KeychainAuthStore.load() else { return false }
        let persisted = try JSONDecoder().decode(PersistedAuth.self, from: data)
        guard persisted.appleID == appleID, persisted.password == password else { return false }

        guid = persisted.guid
        accountName = persisted.accountName
        authHeaders = persisted.authHeaders
        pod = persisted.pod

        if let cookieArchive = persisted.cookieArchive,
           let cookies = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(cookieArchive) as? [HTTPCookie]
        {
            authCookies = cookies
        } else {
            authCookies = nil
        }

        return true
    }
}

private enum KeychainAuthStore {
    private static let service = "dev.evokerking.encryptedipafetcher.auth"
    private static let account = "itunes-auth"

    static func save(data: Data) -> Bool {
        _ = delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
