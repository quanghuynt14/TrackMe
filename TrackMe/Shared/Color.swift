import SwiftUI
import CryptoKit

extension Color {
    static func uniqueColor(for name: String) -> Color {
        let hash = SHA256.hash(data: Data(name.utf8))
        let bytes = Array(hash)

        // Use bytes to generate HSB values
        let hue = Double(bytes[0]) / 255.0
        let saturation = 0.5 + Double(bytes[1] % 50) / 100.0  // 0.5 - 1.0
        let brightness = 0.6 + Double(bytes[2] % 40) / 100.0  // 0.6 - 1.0

        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}
