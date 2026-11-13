import SwiftUI

enum Palette {
    static let background = Color(red: 0.055, green: 0.059, blue: 0.071)

    static func color(_ tint: String) -> Color {
        switch tint {
        case "work":
            return Color(red: 1.0, green: 0.306, blue: 0.180)
        case "rest":
            return Color(red: 0.18, green: 0.74, blue: 0.98)
        case "prepare":
            return Color(red: 1.0, green: 0.74, blue: 0.30)
        case "end":
            return Color(red: 0.49, green: 0.86, blue: 0.45)
        case "stopwatch":
            return Color(red: 0.95, green: 0.95, blue: 0.97)
        default:
            return Color(red: 0.55, green: 0.55, blue: 0.58)
        }
    }
}
