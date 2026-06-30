import Foundation

final class IPAToolStyleService {
    enum ServiceError: Error, LocalizedError {
        case notAuthenticated
        case invalidCredentials
        case invalidSearchTerm
        case noDownloadURL

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must sign in with an Apple ID before downloading."
            case .invalidCredentials:
                return "Please enter a valid Apple ID and password."
            case .invalidSearchTerm:
                return "Search term must be at least 2 characters."
            case .noDownloadURL:
                return "No downloadable IPA URL returned for this app/version."
            }
        }
    }

    private var isAuthenticated = false
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func login(_ request: LoginRequest) throws {
        guard request.appleID.contains("@"), request.password.count >= 6 else {
            throw ServiceError.invalidCredentials
        }

        // This app keeps credentials local and only marks session readiness.
        // The real Apple private auth sequence used by ipatool requires API flows
        // not publicly documented for third-party iOS clients.
        isAuthenticated = true
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

        guard let url = components?.url else { return [] }
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(AppSearchResponse.self, from: data)
        return decoded.results
    }

    func downloadIPA(for app: AppSearchResult) async throws -> URL {
        guard isAuthenticated else { throw ServiceError.notAuthenticated }

        // Placeholder for Apple-hosted IPA retrieval flow.
        // A production implementation would replicate authenticated purchase/license
        // metadata flows and then stream from Apple CDN URLs.
        throw ServiceError.noDownloadURL
    }
}
