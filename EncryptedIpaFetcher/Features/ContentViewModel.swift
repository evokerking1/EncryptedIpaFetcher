import Foundation

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var appleID = ""
    @Published var password = ""
    @Published var searchTerm = ""
    @Published var results: [AppSearchResult] = []
    @Published var jobs: [DownloadJob] = []
    @Published var isAuthenticating = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: IPAToolStyleService

    init(service: IPAToolStyleService) {
        self.service = service
    }

    func login() {
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            try service.login(.init(appleID: appleID, password: password))
            infoMessage = "Signed in. Search for an app and request IPA retrieval."
            errorMessage = nil
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
                infoMessage = "No app results found."
            }
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }

    func requestDownload(for app: AppSearchResult) async {
        var job = DownloadJob(appName: app.trackName, bundleId: app.bundleId)
        jobs.insert(job, at: 0)

        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index].status = .downloading(0.0)

        if #available(iOS 16.1, *) {
            await DownloadLiveActivityManager.shared.start(
                for: job.id,
                appName: app.trackName,
                bundleId: app.bundleId
            )
        }

        do {
            for step in 1 ... 7 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                let progress = Double(step) / 10.0
                jobs[index].status = .downloading(progress)

                if #available(iOS 16.1, *) {
                    await DownloadLiveActivityManager.shared.update(
                        jobID: job.id,
                        progress: progress,
                        statusMessage: "Downloading \(Int(progress * 100))%"
                    )
                }
            }

            let url = try await service.downloadIPA(for: app)
            jobs[index].status = .completed(url)
            errorMessage = nil

            if #available(iOS 16.1, *) {
                await DownloadLiveActivityManager.shared.end(
                    jobID: job.id,
                    progress: 1.0,
                    statusMessage: "Download complete"
                )
            }
        } catch {
            jobs[index].status = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription

            if #available(iOS 16.1, *) {
                await DownloadLiveActivityManager.shared.end(
                    jobID: job.id,
                    progress: 0.0,
                    statusMessage: "Download failed"
                )
            }
        }
    }
}
