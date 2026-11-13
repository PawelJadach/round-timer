import ActivityKit
import Foundation

struct TrainingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phaseName: String
        var detail: String
        var tint: String
        var usesTimer: Bool
        var countsDown: Bool
        var rangeStart: Date
        var rangeEnd: Date
        var frozenText: String
    }

    var title: String
}
