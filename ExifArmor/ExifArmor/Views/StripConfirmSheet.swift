// StripConfirmSheet.swift — Custom confirmation sheet, no red/destructive role
import SwiftUI

struct StripConfirmSheet: View {
    let photoCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var headline: String {
        photoCount == 1
            ? "Strip metadata from 1 photo?"
            : "Strip metadata from \(photoCount) photos?"
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text(headline)
                    .font(.kataDisplay(20))
                    .foregroundStyle(Color.kataIce)
                    .multilineTextAlignment(.center)

                Text("All EXIF data — location, device info, timestamps, and camera settings — will be permanently removed from the cleaned copy. Your originals stay untouched.")
                    .font(.kataBody(14))
                    .foregroundStyle(Color.kataIce.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 12) {
                Button {
                    KataHaptic.destructive.fire()
                    onConfirm()
                } label: {
                    Text("Strip Metadata")
                        .font(.kataBody(16)).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.kataSapphire)
                        .foregroundStyle(Color.kataIce)
                        .overlay(
                            Capsule().stroke(Color.kataGold.opacity(0.5), lineWidth: 0.5)
                        )
                        .clipShape(Capsule())
                }

                Button {
                    KataHaptic.tap.fire()
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.kataBody(16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            Capsule().stroke(Color.kataGold.opacity(0.4), lineWidth: 0.5)
                        )
                        .foregroundStyle(Color.kataGold.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .presentationDetents([.height(320)])
        .presentationBackground(Color.kataMidnight)
        .preferredColorScheme(.dark)
    }
}
