import ActivityKit

struct DownloadActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var statusMessage: String
    }

    var appName: String
    var bundleId: String
}
