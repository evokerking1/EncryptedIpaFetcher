import Foundation

struct DownloadJob: Identifiable, Hashable {
    enum Status: Hashable {
        case queued
        case preparing
        case downloading(Double)
        case completed(URL)
        case failed(String)
    }

    let id = UUID()
    let appName: String
    let bundleId: String
    let createdAt = Date()
    var updatedAt = Date()
    var finishedAt: Date?
    var status: Status = .queued

    mutating func updateStatus(_ nextStatus: Status) {
        status = nextStatus
        updatedAt = Date()
        switch nextStatus {
        case .completed, .failed:
            finishedAt = updatedAt
        case .queued, .preparing, .downloading:
            finishedAt = nil
        }
    }
}
