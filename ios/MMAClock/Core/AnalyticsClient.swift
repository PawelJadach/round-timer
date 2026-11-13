import Foundation
import OSLog

protocol AnalyticsClient: Sendable {
    func track(_ event: String, parameters: [String: String])
    func recordError(_ error: Error, context: String)
}

extension AnalyticsClient {
    func track(_ event: String) {
        track(event, parameters: [:])
    }
}

struct ConsoleAnalyticsClient: AnalyticsClient {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RoundTimer", category: "Analytics")

    func track(_ event: String, parameters: [String: String]) {
        if parameters.isEmpty {
            logger.info("event=\(event, privacy: .public)")
        } else {
            let payload = parameters
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: " ")
            logger.info("event=\(event, privacy: .public) \(payload, privacy: .public)")
        }
    }

    func recordError(_ error: Error, context: String) {
        logger.error("error context=\(context, privacy: .public) detail=\(String(describing: error), privacy: .public)")
    }
}

enum Analytics {
    static var shared: AnalyticsClient = ConsoleAnalyticsClient()
}
