import Foundation

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var appleID = ""
    @Published var password = ""
    @Published var twoFactorCode = ""
    @Published var requiresTwoFactorCode = false

    @Published var searchTerm = ""
    @Published var results: [AppSearchResult] = []
    @Published var jobs: [DownloadJob] = []

    @Published var isAuthenticating = false
    @Published var isSearching = false
    @Published var isProcessingQueue = false

    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private struct QueuedDownload {
        let jobID: UUID
        let app: AppSearchResult
    }

    private var pendingDownloads: [QueuedDownload] = []
    private let service: IPAToolStyleService

    var activeJobs: [DownloadJob] {
        jobs.filter {
            switch $0.status {
            case .queued, .preparing, .downloading:
                return true
            case .completed, .failed:
                return false
            }
        }
    }

    var historyJobs: [DownloadJob] {
        jobs.filter { $0.finishedAt != nil }
    }

    init(service: IPAToolStyleService) {
        self.service = service
    }

    func login() async {
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let result = try await service.login(.init(
                appleID: appleID,
                password: password,
                twoFactorCode: twoFactorCode.isEmpty ? nil : twoFactorCode
            ))

            errorMessage = nil
            switch result {
            case let .authenticated(accountName):
                requiresTwoFactorCode = false
                twoFactorCode = ""
                if let accountName, !accountName.isEmpty {
                    infoMessage = String(format: L10n.text("auth.signedInNamed"), accountName)
                } else {
                    infoMessage = L10n.text("auth.signedIn")
                }
            case let .twoFactorRequired(message):
                requiresTwoFactorCode = true
                infoMessage = message
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search() async {
        isSearching = true
        defer { isSearching = false }

        do {
            results = try await service.search(term: searchTerm)
            errorMessage = nil
            if results.isEmpty {
                infoMessage = L10n.text("search.noResults")
            }
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }

    func requestDownload(for app: AppSearchResult) async {
        var job = DownloadJob(appName: app.trackName, bundleId: app.bundleId)
        job.updateStatus(.queued)
        jobs.insert(job, at: 0)
        pendingDownloads.append(.init(jobID: job.id, app: app))

        if !isProcessingQueue {
            await processQueue()
        }
    }

    private func processQueue() async {
        isProcessingQueue = true
        defer { isProcessingQueue = false }

        while !pendingDownloads.isEmpty {
            let next = pendingDownloads.removeFirst()
            updateJob(id: next.jobID, status: .preparing)

            if #available(iOS 16.1, *) {
                await DownloadLiveActivityManager.shared.start(
                    for: next.jobID,
                    appName: next.app.trackName,
                    bundleId: next.app.bundleId
                )
                await DownloadLiveActivityManager.shared.update(
                    jobID: next.jobID,
                    progress: 0.1,
                    statusMessage: L10n.text("queue.preparing")
                )
            }

            do {
                updateJob(id: next.jobID, status: .downloading(0.35))
                if #available(iOS 16.1, *) {
                    await DownloadLiveActivityManager.shared.update(
                        jobID: next.jobID,
                        progress: 0.35,
                        statusMessage: L10n.text("queue.requestingDownload")
                    )
                }

                let fileURL = try await service.downloadIPA(for: next.app)
                updateJob(id: next.jobID, status: .completed(fileURL))
                errorMessage = nil

                if #available(iOS 16.1, *) {
                    await DownloadLiveActivityManager.shared.end(
                        jobID: next.jobID,
                        progress: 1.0,
                        statusMessage: L10n.text("queue.downloadComplete")
                    )
                }
            } catch {
                updateJob(id: next.jobID, status: .failed(error.localizedDescription))
                errorMessage = error.localizedDescription

                if #available(iOS 16.1, *) {
                    await DownloadLiveActivityManager.shared.end(
                        jobID: next.jobID,
                        progress: 0.0,
                        statusMessage: L10n.text("queue.downloadFailed")
                    )
                }
            }
        }
    }

    func statusLabel(for status: DownloadJob.Status) -> String {
        switch status {
        case .queued:
            return L10n.text("queue.statusQueued")
        case .preparing:
            return L10n.text("queue.statusPreparing")
        case let .downloading(progress):
            return String(format: L10n.text("queue.statusDownloading"), Int(progress * 100))
        case let .completed(url):
            return String(format: L10n.text("queue.statusCompleted"), url.lastPathComponent)
        case let .failed(message):
            return String(format: L10n.text("queue.statusFailed"), message)
        }
    }

    private func updateJob(id: UUID, status: DownloadJob.Status) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].updateStatus(status)
    }
}
