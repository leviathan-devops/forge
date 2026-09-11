import UIKit
import SwiftUI

// MARK: - UIColor Hex Initializer

extension UIColor {
    /// Initialize a UIColor from a hex string.
    /// Supports 6-character RGB (#RRGGBB or RRGGBB) and 8-character RGBA (#RRGGBBAA or RRGGBBAA).
    /// The leading '#' is optional.
    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let r, g, b, a: CGFloat

        if hexString.count == 8 {
            // RRGGBBAA
            r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgbValue & 0x000000FF) / 255.0
        } else {
            // RRGGBB (default alpha = 1.0)
            r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgbValue & 0x0000FF) / 255.0
            a = 1.0
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }

    /// Initialize a UIColor from a hex string with an explicit alpha override.
    convenience init(hex: String, alpha: CGFloat) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    /// Convert a UIColor back to a hex string (RRGGBB).
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - SwiftUI Color Hex Initializer

extension Color {
    /// Initialize a SwiftUI Color from a hex string (e.g. "0A0A0F" or "#00F0FF").
    init(hex: String) {
        self.init(UIColor(hex: hex))
    }

    /// Initialize a SwiftUI Color from a hex string with an explicit opacity.
    init(hex: String, opacity: Double) {
        self.init(UIColor(hex: hex, alpha: CGFloat(opacity)))
    }
}
