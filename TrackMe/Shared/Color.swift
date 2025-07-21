import SwiftUI
import CryptoKit

extension Color {
    static func uniqueColor(for name: String) -> Color {
        // Special case for loginwindow
        if name == "loginwindow" {
            return Color.white
        }
        
        let hash = SHA256.hash(data: Data(name.utf8))
        let bytes = Array(hash)

        // Use bytes to generate HSB values for pastel colors
        let hue = Double(bytes[0]) / 255.0
        let saturation = 0.2 + Double(bytes[1] % 30) / 100.0  // 0.2 - 0.5 (lower saturation for pastel)
        let brightness = 0.85 + Double(bytes[2] % 15) / 100.0  // 0.85 - 1.0 (higher brightness for pastel)

        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}
