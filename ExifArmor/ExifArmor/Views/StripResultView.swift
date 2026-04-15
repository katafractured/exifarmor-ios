import AVFoundation
import SwiftUI

struct StripResultView: View {
    let viewModel: PhotoStripViewModel
    let onSave: () -> Void
    let onShare: () -> Void
    let onDone: () -> Void

    @State private var showBeforeAfter = false
    @State private var showDiff = false
    @State private var diffResultIndex = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success header
                successHeader

                // Stats summary
                statsSummary

                if viewModel.stripResults.count > 1 {
                    Picker("Photo", selection: $diffResultIndex) {
                        ForEach(viewModel.stripResults.indices, id: \.self) { index in
                            Text("Photo \(index + 1)").tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !viewModel.stripResults.isEmpty {
                    Button("View Full Metadata Report") {
                        showDiff = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color("AccentCyan"))
                }

                if viewModel.stripResults.contains(where: { $0.originalMetadata.isLivePhoto }) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color("AccentGold"))
                        Text("Live Photo video components are not modified. Only the still photo is cleaned.")
                            .font(.caption)
                            .foregroundStyle(Color("TextSecondary"))
                    }
                    .padding(12)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                metadataOutcomeSummary

                // Cleaned photos grid — only shown when photos were actually stripped
                if !viewModel.stripResults.isEmpty {
                    cleanedPhotosGrid
                }

                if viewModel.videoStripFailures > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Color("AccentGold"))
                        Text("\(viewModel.videoStripFailures) video(s) could not be cleaned.")
                            .font(.caption)
                            .foregroundStyle(Color("TextSecondary"))
                    }
                    .padding(12)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !viewModel.videoStripResults.isEmpty {
                    cleanedVideosGrid
                }

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(Color("BackgroundDark"))
        .sheet(isPresented: $showDiff) {
            if !viewModel.stripResults.isEmpty {
                MetadataDiffView(
                    result: viewModel.stripResults[diffResultIndex],
                    options: viewModel.stripOptions
                )
                .presentationDetents([.large])
            }
        }
    }

    // MARK: - Success Header

    private var successHeader: some View {
        VStack(spacing: 12) {
            Image("EmptyAllClean")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            Text(successHeadline)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color("TextPrimary"))

            Text("All selected metadata has been removed.")
                .font(.subheadline)
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    /// Headline adapts to what was actually cleaned: photos only, videos only,
    /// or both. Uses singular/plural based on count.
    private var successHeadline: String {
        let photoCount = viewModel.stripResults.count
        let videoCount = viewModel.videoStripResults.count

        switch (photoCount, videoCount) {
        case (0, 0):
            return "Cleaned!"
        case (_, 0):
            return photoCount == 1 ? "Photo Cleaned!" : "Photos Cleaned!"
        case (0, _):
            return videoCount == 1 ? "Video Cleaned!" : "Videos Cleaned!"
        default:
            return "Media Cleaned!"
        }
    }

    // MARK: - Stats

    private var statsSummary: some View {
        let photoCount = viewModel.stripResults.count
        let videoCount = viewModel.videoStripResults.count

        return HStack(spacing: 0) {
            if photoCount > 0 {
                statItem(
                    value: "\(photoCount)",
                    label: "Photos",
                    icon: "photo.fill"
                )
                statDivider
            }

            if videoCount > 0 {
                statItem(
                    value: "\(videoCount)",
                    label: "Videos",
                    icon: "video.fill"
                )
                statDivider
            }

            statItem(
                value: "\(viewModel.totalFieldsRemoved)",
                label: "Fields Removed",
                icon: "eye.slash.fill"
            )

            if viewModel.hadLocationData {
                statDivider

                statItem(
                    value: "✓",
                    label: "GPS Stripped",
                    icon: "location.slash.fill"
                )
            }
        }
        .padding(.vertical, 16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statDivider: some View {
        Divider()
            .frame(height: 40)
            .background(Color("TextSecondary").opacity(0.3))
    }

    private var metadataOutcomeSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What Changed")
                .font(.headline)
                .foregroundStyle(Color("TextPrimary"))

            outcomeSection(
                title: "Removed",
                items: removedMetadataItems,
                tint: Color("WarningRed")
            )

            outcomeSection(
                title: "Kept",
                items: keptMetadataItems,
                tint: Color("SuccessGreen")
            )
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func outcomeSection(title: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            FlowLayout(items: items, tint: tint)
        }
    }

    private var removedMetadataItems: [String] {
        var items: [String] = []
        let options = viewModel.stripOptions

        if options.removeAll || options.removeLocation {
            items.append("GPS location")
            items.append("Altitude")
        }
        if options.removeAll || options.removeDateTime {
            items.append("Date & time")
        }
        if options.removeAll || options.removeDeviceInfo {
            items.append("Device info")
        }
        if options.removeAll || options.removeCameraSettings {
            items.append("Camera settings")
        }

        return items
    }

    private var keptMetadataItems: [String] {
        let options = viewModel.stripOptions
        var items: [String] = ["Image orientation"]

        if !options.removeAll && !options.removeLocation {
            items.append("GPS location")
        }
        if !options.removeAll && !options.removeDateTime {
            items.append("Date & time")
        }
        if !options.removeAll && !options.removeDeviceInfo {
            items.append("Device info")
        }
        if !options.removeAll && !options.removeCameraSettings {
            items.append("Camera settings")
        }

        return items
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Color("AccentCyan"))

            Text(label)
                .font(.caption2)
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Grid

    private var cleanedPhotosGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.stripResults.isEmpty {
                Text("Cleaned Photos")
                    .font(.headline)
                    .foregroundStyle(Color("TextPrimary"))
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 8) {
                ForEach(viewModel.stripResults) { result in
                    Image(uiImage: result.cleanedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(minHeight: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.caption)
                                .foregroundStyle(Color("SuccessGreen"))
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .padding(4)
                        }
                }
            }
        }
    }

    private var cleanedVideosGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cleaned Videos")
                .font(.headline)
                .foregroundStyle(Color("TextPrimary"))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 8) {
                ForEach(viewModel.videoStripResults, id: \.self) { url in
                    VideoResultThumbnail(url: url)
                }
            }
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onSave) {
                Label("Save to Photo Library", systemImage: "square.and.arrow.down.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("AccentCyan"))
                    .foregroundStyle(Color("BackgroundDark"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 12) {
                Button(action: onShare) {
                    Label("Share Clean Copy", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("CardBackground"))
                        .foregroundStyle(Color("AccentCyan"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("AccentCyan").opacity(0.3), lineWidth: 1)
                        )
                }

                Button(action: onDone) {
                    Text("Done")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("CardBackground"))
                        .foregroundStyle(Color("TextSecondary"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private struct VideoResultThumbnail: View {
    let url: URL

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("CardBackground"))
                    .frame(minHeight: 100)
                    .overlay {
                        Image(systemName: "video.fill")
                            .foregroundStyle(Color("AccentMagenta"))
                    }
            }

            Image(systemName: "checkmark.shield.fill")
                .font(.caption)
                .foregroundStyle(Color("SuccessGreen"))
                .padding(4)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .padding(4)
        }
        .task(id: url) {
            thumbnail = await Self.loadThumbnail(from: url)
        }
    }

    /// Loads a video thumbnail off the main actor. Returns nil on any failure.
    nonisolated private static func loadThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try await generator.image(at: .zero).image
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

private struct FlowLayout: View {
    let items: [String]
    let tint: Color

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(tint.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}
