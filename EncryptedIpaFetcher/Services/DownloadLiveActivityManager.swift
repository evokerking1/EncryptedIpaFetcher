import ActivityKit
import Foundation

@available(iOS 16.1, *)
actor DownloadLiveActivityManager {
    static let shared = DownloadLiveActivityManager()

    private var activities: [UUID: Activity<DownloadActivityAttributes>] = [:]

    func start(for jobID: UUID, appName: String, bundleId: String) {
        let attributes = DownloadActivityAttributes(appName: appName, bundleId: bundleId)
        let initialState = DownloadActivityAttributes.ContentState(
            progress: 0.0,
            statusMessage: L10n.text("queue.preparing")
        )

        do {
            let activity = try Activity<DownloadActivityAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            activities[jobID] = activity
        } catch {
            // Ignore activity startup failures to avoid breaking download flow.
        }
    }

    func update(jobID: UUID, progress: Double, statusMessage: String) async {
        guard let activity = activities[jobID] else { return }
        let state = DownloadActivityAttributes.ContentState(
            progress: min(max(progress, 0.0), 1.0),
            statusMessage: statusMessage
        )
        await activity.update(using: state)
    }

    func end(jobID: UUID, progress: Double, statusMessage: String) async {
        guard let activity = activities[jobID] else { return }
        let finalState = DownloadActivityAttributes.ContentState(
            progress: min(max(progress, 0.0), 1.0),
            statusMessage: statusMessage
        )
        await activity.end(using: finalState, dismissalPolicy: .immediate)
        activities.removeValue(forKey: jobID)
    }
}
