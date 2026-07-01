import Foundation

struct AppSearchResponse: Decodable {
    let resultCount: Int
    let results: [AppSearchResult]
}

struct AppSearchResult: Decodable, Identifiable, Hashable {
    let trackId: Int
    let trackName: String
    let sellerName: String
    let bundleId: String
    let version: String
    let averageUserRating: Double?
    let artworkUrl100: URL?

    var id: Int { trackId }
}
