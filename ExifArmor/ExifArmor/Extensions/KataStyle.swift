// KataStyle.swift — Inline KatafractStyle tokens for ExifArmor
// Mirrors KatafractStyle v0.1.2 palette; imported via SPM when resolved.
// These extensions on Color/Font are additive and do not conflict with the SPM module.
import SwiftUI

// MARK: - Color tokens
extension Color {
    static let kataGold       = Color(red: 0.776, green: 0.596, blue: 0.220)
    static let kataSapphire   = Color(red: 0.110, green: 0.200, blue: 0.400)
    static let kataIce        = Color(red: 0.920, green: 0.940, blue: 0.970)
    static let kataMidnight   = Color(red: 0.040, green: 0.040, blue: 0.080)
    static let kataChampagne  = Color(red: 0.960, green: 0.890, blue: 0.780)
    static let kataNavy       = Color(red: 0.060, green: 0.090, blue: 0.180)
}

// MARK: - Font tokens
extension Font {
    static func kataDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    static func kataBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func kataMono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

// MARK: - KataAccent
enum KataAccent {
    static let gold     = Color.kataGold
    static let sapphire = Color.kataSapphire
}

// MARK: - KataProgressRing
struct KataProgressRing: View {
    let progress: Double   // 0.0 – 1.0
    var diameter: CGFloat = 48
    var lineWidth: CGFloat = 3.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.kataGold.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    Color.kataGold,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: diameter, height: diameter)
    }
}
