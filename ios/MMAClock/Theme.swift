import SwiftUI

enum Palette {
    static let background = Color(red: 0.063, green: 0.047, blue: 0.039)
    static let ink = Color(red: 0.957, green: 0.937, blue: 0.902)
    static let gold = Color(red: 0.894, green: 0.694, blue: 0.353)
    static let canvas = Color(red: 0.102, green: 0.071, blue: 0.055)

    static func color(_ tint: String) -> Color {
        switch tint {
        case "work":
            return Color(red: 0.886, green: 0.227, blue: 0.169)
        case "rest":
            return Color(red: 0.247, green: 0.525, blue: 0.839)
        case "prepare":
            return gold
        case "end":
            return Color(red: 0.839, green: 0.890, blue: 0.416)
        case "stopwatch":
            return ink
        default:
            return gold
        }
    }

    static func ink(on tint: String) -> Color {
        tint == "work" || tint == "rest" ? Color(red: 1, green: 0.973, blue: 0.949) : Color(red: 0.102, green: 0.063, blue: 0.047)
    }

    static func display(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-Bold", size: size)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom(weight == .regular || weight == .medium ? "Barlow-Medium" : "Barlow-SemiBold", size: size)
    }
}
