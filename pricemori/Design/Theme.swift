import SwiftUI
import UIKit

enum Theme {
    static let background = adaptive(light: 0xF7F7F8, dark: 0x17171A)
    static let primaryText = adaptive(light: 0x252529, dark: 0xF0F0F2)
    static let secondaryText = adaptive(light: 0x686870, dark: 0xAAAAB3)
    static let secondaryControl = adaptive(light: 0x515159, dark: 0xC2C2CA)
    static let separator = adaptive(light: 0xDFDFE4, dark: 0x3A3A42)
    static let chartLine = adaptive(light: 0x73737B, dark: 0x999BA3)
    static let accent = adaptive(light: 0x0F766E, dark: 0x2DD4BF)
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x0D1313)
    static let fieldBackground = adaptive(light: 0xFFFFFF, dark: 0x1C1C20)
    static let chartHalo = adaptive(light: 0x0F766E, dark: 0x2DD4BF)
    static let error = adaptive(light: 0xA8322B, dark: 0xF2B8B5)
    static let overlay = adaptive(light: 0x000000, dark: 0x000000)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}
