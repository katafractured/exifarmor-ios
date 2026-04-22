// LaunchSplashView.swift — 600ms brand splash for ExifArmor
import SwiftUI

struct LaunchSplashView: View {
    @State private var sealProgress: CGFloat = 0
    @State private var wordmarkOpacity: Double = 0
    @Binding var isVisible: Bool

    var body: some View {
        ZStack {
            Color.kataMidnight.ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    // Hairline gold seal ring drawing around icon area
                    Circle()
                        .trim(from: 0, to: sealProgress)
                        .stroke(Color.kataGold, style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                        .frame(width: 104, height: 104)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.kataGold.opacity(0.9))
                }

                VStack(spacing: 4) {
                    Text("ExifArmor")
                        .font(.kataDisplay(26))
                        .foregroundStyle(Color.kataIce)
                    Text("Strip. Share. Stay private.")
                        .font(.kataBody(13))
                        .foregroundStyle(Color.kataGold.opacity(0.7))
                }
                .opacity(wordmarkOpacity)
            }
        }
        .task {
            // Animate seal ring
            withAnimation(.easeOut(duration: 0.45)) {
                sealProgress = 1.0
            }
            // Haptic at ring-complete moment
            try? await Task.sleep(for: .milliseconds(400))
            KataHaptic.unlocked.fire()
            withAnimation(.easeIn(duration: 0.2)) {
                wordmarkOpacity = 1.0
            }
            // Dismiss after 600ms total
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeIn(duration: 0.25)) {
                isVisible = false
            }
        }
    }
}
