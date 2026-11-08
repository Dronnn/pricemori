import SwiftUI
import UIKit

enum AppFont {
    enum Weight {
        case regular
        case medium
        case semibold
        case bold

        var swiftUI: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            }
        }

        var postScriptSuffix: String {
            switch self {
            case .regular: "Inter-Regular"
            case .medium: "Inter-Regular_Medium"
            case .semibold: "Inter-Regular_SemiBold"
            case .bold: "Inter-Regular_Bold"
            }
        }
    }

    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        if UIFont(name: "DMSerifDisplay-Regular", size: size) != nil {
            return .custom("DMSerifDisplay-Regular", size: size, relativeTo: style)
        }
        return .system(size: size, weight: .regular, design: .serif)
    }

    static func inter(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name = weight.postScriptSuffix
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size, relativeTo: style)
        }
        return .system(size: size, weight: weight.swiftUI)
    }

    static func registerFonts() {
        for name in ["DMSerifDisplay-Regular", "Inter"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

import CoreText

extension View {
    func headingStyle(_ size: CGFloat = 32, relativeTo style: Font.TextStyle = .title) -> some View {
        font(AppFont.serif(size))
            .foregroundStyle(Theme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
