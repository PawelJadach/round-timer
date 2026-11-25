import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MMAClockWidgets: WidgetBundle {
    var body: some Widget {
        TrainingLiveActivity()
    }
}

struct TrainingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(liveBackgroundTint(context.state.tint))
                .activitySystemActionForegroundColor(liveForegroundColor(context.state.tint))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: symbol(context.state.tint))
                        .font(.title2)
                        .foregroundStyle(liveAccentColor(context.state.tint))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phaseName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(liveAccentColor(context.state.tint))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.detail)
                        .font(.caption2)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: symbol(context.state.tint))
                    .foregroundStyle(liveAccentColor(context.state.tint))
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: symbol(context.state.tint))
                    .foregroundStyle(liveAccentColor(context.state.tint))
            }
            .keylineTint(liveAccentColor(context.state.tint))
        }
    }

    private func lockScreen(_ state: TrainingAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol(state.tint))
                .font(.title2)
                .foregroundStyle(liveForegroundColor(state.tint))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.phaseName)
                    .font(.headline)
                    .foregroundStyle(liveForegroundColor(state.tint))
                Text(state.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
    }

    private func symbol(_ tint: String) -> String {
        switch tint {
        case "work": return "figure.boxing"
        case "rest": return "pause.circle.fill"
        case "prepare": return "timer"
        case "end": return "checkmark.circle.fill"
        case "stopwatch": return "stopwatch.fill"
        default: return "timer"
        }
    }

    private func liveForegroundColor(_ tint: String) -> Color {
        switch tint {
        case "prepare":
            return Color(red: 0.957, green: 0.937, blue: 0.902)
        case "work", "rest":
            return Color(red: 1, green: 0.97, blue: 0.95)
        case "end":
            return Color(red: 0.839, green: 0.890, blue: 0.416)
        case "stopwatch":
            return Color(red: 0.478, green: 0.761, blue: 0.949)
        default:
            return .white
        }
    }

    private func liveAccentColor(_ tint: String) -> Color {
        switch tint {
        case "work":
            return Color(red: 0.886, green: 0.227, blue: 0.169)
        case "rest":
            return Color(red: 0.16, green: 0.52, blue: 0.30)
        case "prepare":
            return Color(red: 0.957, green: 0.937, blue: 0.902)
        case "end":
            return Color(red: 0.839, green: 0.890, blue: 0.416)
        case "stopwatch":
            return Color(red: 0.478, green: 0.761, blue: 0.949)
        default:
            return .white
        }
    }

    private func liveBackgroundTint(_ tint: String) -> Color {
        switch tint {
        case "prepare":
            return Color.black.opacity(0.92)
        case "work":
            return Color(red: 0.886, green: 0.227, blue: 0.169).opacity(0.92)
        case "rest":
            return Color(red: 0.16, green: 0.52, blue: 0.30).opacity(0.92)
        default:
            return Color.black.opacity(0.55)
        }
    }
}