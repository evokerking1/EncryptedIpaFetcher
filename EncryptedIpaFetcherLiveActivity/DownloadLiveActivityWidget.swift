import ActivityKit
import SwiftUI
import WidgetKit

struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.attributes.appName)
                    .font(.headline)
                Text(context.state.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: context.state.progress)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.down.circle.fill")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.appName)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                }
            } compactLeading: {
                Image(systemName: "arrow.down")
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))")
            } minimal: {
                Image(systemName: "arrow.down")
            }
        }
    }
}
