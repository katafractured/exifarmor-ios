// SealSuccessView.swift — Ceremonial "Metadata purged." moment overlay
import SwiftUI

struct SealSuccessView: View {
    let thumbnail: UIImage?
    let onDismiss: () -> Void

    @State private var sealProgress: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var didFire = false

    var body: some View {
        ZStack {
            Color.kataMidnight.ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.kataNavy)
                            .frame(width: 180, height: 180)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.kataGold.opacity(0.5))
                            }
                    }

                    // Gold hairline seal ring
                    Circle()
                        .trim(from: 0, to: sealProgress)
                        .stroke(Color.kataGold, style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                        .frame(width: 210, height: 210)
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 6) {
                    Text("Metadata purged.")
                        .font(.kataDisplay(22))
                        .foregroundStyle(Color.kataChampagne)
                    Text("Your photo carries no trace.")
                        .font(.kataBody(13))
                        .foregroundStyle(Color.kataGold.opacity(0.6))
                }
                .opacity(textOpacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .task {
            // Fire haptic immediately when ring starts
            KataHaptic.unlocked.fire()
            withAnimation(.easeOut(duration: 0.6)) {
                sealProgress = 1.0
            }
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeIn(duration: 0.3)) {
                textOpacity = 1.0
            }
            // Auto-dismiss after 1.6s
            try? await Task.sleep(for: .milliseconds(1000))
            onDismiss()
        }
    }
}
