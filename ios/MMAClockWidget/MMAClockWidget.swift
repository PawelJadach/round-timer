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
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: symbol(context.state.tint))
                        .font(.title2)
                        .foregroundStyle(tintColor(context.state.tint))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.phaseName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tintColor(context.state.tint))
                        readout(context.state)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.detail)
                        .font(.caption2)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: symbol(context.state.tint))
                    .foregroundStyle(tintColor(context.state.tint))
            } compactTrailing: {
                readout(context.state)
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: symbol(context.state.tint))
                    .foregroundStyle(tintColor(context.state.tint))
            }
        }
    }

    private func lockScreen(_ state: TrainingAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol(state.tint))
                .font(.title2)
                .foregroundStyle(tintColor(state.tint))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.phaseName)
                    .font(.headline)
                Text(state.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            readout(state)
                .font(.system(size: 30, weight: .bold, design: .rounded))
        }
        .padding(16)
    }

    private func readout(_ state: TrainingAttributes.ContentState) -> some View {
        Group {
            if state.usesTimer, state.rangeEnd > state.rangeStart {
                Text(timerInterval: state.rangeStart...state.rangeEnd, countsDown: state.countsDown)
            } else {
                Text(state.frozenText)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
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

    private func tintColor(_ tint: String) -> Color {
        switch tint {
        case "work": return Color(red: 0.886, green: 0.227, blue: 0.169)
        case "rest": return Color(red: 0.247, green: 0.525, blue: 0.839)
        case "prepare": return Color(red: 0.894, green: 0.694, blue: 0.353)
        case "end": return Color(red: 0.839, green: 0.890, blue: 0.416)
        default: return .white
        }
    }
}
