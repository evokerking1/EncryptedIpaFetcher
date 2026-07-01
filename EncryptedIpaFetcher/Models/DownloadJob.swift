import Foundation

struct DownloadJob: Identifiable, Hashable {
    enum Status: Hashable {
        case pending
        case downloading(Double)
        case completed(URL)
        case failed(String)
    }

    let id = UUID()
    let appName: String
    let bundleId: String
    let createdAt = Date()
    var status: Status = .pending
}
