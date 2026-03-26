import SwiftUI
import MapKit

struct ExposurePreviewView: View {
    let viewModel: PhotoStripViewModel
    let onStrip: () -> Void
    let onCancel: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var selectedPhotoIndex = 0
    @State private var showStripOptions = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !viewModel.analyzedPhotos.isEmpty {
                    photoCarousel

                    if let photo = currentPhoto {
                        // Privacy score banner
                        privacyScoreBanner(photo)

                        // Metadata sections
                        VStack(spacing: 16) {
                            if photo.hasLocation {
                                locationCard(photo)
                            }

                            if photo.hasDeviceInfo {
                                deviceCard(photo)
                            }

                            if photo.hasDateTime {
                                dateTimeCard(photo)
                            }

                            if photo.focalLength != nil || photo.aperture != nil {
                                cameraCard(photo)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }

                if !viewModel.analyzedVideos.isEmpty {
                    // Privacy score banner
                    VStack(spacing: 16) {
                        ForEach(viewModel.analyzedVideos) { video in
                            videoPrivacyBanner(video)
                            VideoMetadataCard(video: video)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                // Action buttons
                actionButtons
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            }
        }
        .background(Color("BackgroundDark"))
        .sheet(isPresented: $showStripOptions) {
            StripOptionsSheet(
                options: Binding(
                    get: { viewModel.stripOptions },
                    set: { viewModel.stripOptions = $0 }
                ),
                onConfirm: {
                    showStripOptions = false
                    onStrip()
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Photo Carousel

    private var currentPhoto: PhotoMetadata? {
        guard selectedPhotoIndex < viewModel.analyzedPhotos.count else { return nil }
        return viewModel.analyzedPhotos[selectedPhotoIndex]
    }

    private var photoCarousel: some View {
        TabView(selection: $selectedPhotoIndex) {
            ForEach(Array(viewModel.analyzedPhotos.enumerated()), id: \.offset) { index, photo in
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 280)
                    .clipped()
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: viewModel.analyzedPhotos.count > 1 ? .always : .never))
        .frame(height: 280)
        .overlay(alignment: .topTrailing) {
            if viewModel.analyzedPhotos.count > 1 {
                Text("\(selectedPhotoIndex + 1)/\(viewModel.analyzedPhotos.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(12)
            }
        }
    }

    // MARK: - Privacy Score

    private func privacyScoreBanner(_ photo: PhotoMetadata) -> some View {
        HStack(spacing: 12) {
            Image(systemName: photo.privacyScore >= 7 ? "exclamationmark.triangle.fill" :
                    photo.privacyScore >= 4 ? "exclamationmark.circle.fill" : "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(scoreColor(photo.privacyScore))

            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy Risk: \(photo.privacyScore)/10")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(scoreColor(photo.privacyScore))

                Text("\(photo.exposedFieldCount) data fields exposed")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
            }

            Spacer()
        }
        .padding(16)
        .background(scoreColor(photo.privacyScore).opacity(0.12))
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 7 { return Color("WarningRed") }
        if score >= 4 { return Color("AccentGold") }
        return Color("SuccessGreen")
    }

    private func videoPrivacyBanner(_ video: VideoMetadata) -> some View {
        HStack(spacing: 12) {
            Image(systemName: video.privacyScore >= 7 ? "exclamationmark.triangle.fill" :
                    video.privacyScore >= 4 ? "exclamationmark.circle.fill" : "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(scoreColor(video.privacyScore))

            VStack(alignment: .leading, spacing: 2) {
                Text("Video Privacy Risk: \(video.privacyScore)/10")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(scoreColor(video.privacyScore))

                Text("\(video.exposedFieldCount) data fields exposed")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
            }

            Spacer()
        }
        .padding(16)
        .background(scoreColor(video.privacyScore).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Location Card

    private func locationCard(_ photo: PhotoMetadata) -> some View {
        MetadataCard(
            icon: "location.fill",
            title: "GPS Location",
            iconColor: Color("WarningRed"),
            severity: .critical
        ) {
            if let coord = validatedCoordinate(for: photo) {
                // Keep the preview tightly centered on the exposed location instead of
                // relying on Map's implicit camera choice.
                Map(initialPosition: .region(locationPreviewRegion(for: coord))) {
                    Marker("Photo taken here", coordinate: coord)
                        .tint(Color("WarningRed"))
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .allowsHitTesting(false)

                MetadataRow(label: "Latitude", value: String(format: "%.6f", coord.latitude))
                MetadataRow(label: "Longitude", value: String(format: "%.6f", coord.longitude))

                Button {
                    openCoordinateInMaps(coord)
                } label: {
                    Label("Open in Maps", systemImage: "map")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("AccentCyan"))
                        .padding(.top, 4)
                }
            } else {
                Text("Location metadata exists, but the coordinate is invalid.")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
            }

            if let alt = photo.altitude {
                MetadataRow(label: "Altitude", value: String(format: "%.1f m", alt))
            }
        }
    }

    // MARK: - Device Card

    private func deviceCard(_ photo: PhotoMetadata) -> some View {
        MetadataCard(
            icon: "iphone",
            title: "Device Info",
            iconColor: Color("AccentMagenta"),
            severity: .warning
        ) {
            if let make = photo.deviceMake {
                MetadataRow(label: "Make", value: make)
            }
            if let model = photo.deviceModel {
                MetadataRow(label: "Model", value: model)
            }
            if let sw = photo.software {
                MetadataRow(label: "Software", value: sw)
            }
        }
    }

    // MARK: - Date/Time Card

    private func dateTimeCard(_ photo: PhotoMetadata) -> some View {
        MetadataCard(
            icon: "clock.fill",
            title: "Date & Time",
            iconColor: Color("AccentGold"),
            severity: .warning
        ) {
            if let dt = photo.dateTimeOriginal {
                MetadataRow(label: "Taken", value: dt)
            }
            if let dt = photo.dateTimeDigitized {
                MetadataRow(label: "Digitized", value: dt)
            }
        }
    }

    // MARK: - Camera Card

    private func cameraCard(_ photo: PhotoMetadata) -> some View {
        MetadataCard(
            icon: "camera.fill",
            title: "Camera Settings",
            iconColor: Color("AccentCyan"),
            severity: .info
        ) {
            if let lens = photo.lensModel {
                MetadataRow(label: "Lens", value: lens)
            }
            if let fl = photo.focalLength {
                MetadataRow(label: "Focal Length", value: String(format: "%.1f mm", fl))
            }
            if let ap = photo.aperture {
                MetadataRow(label: "Aperture", value: String(format: "ƒ/%.1f", ap))
            }
            if let et = photo.formattedExposureTime {
                MetadataRow(label: "Exposure", value: et)
            }
            if let iso = photo.iso {
                MetadataRow(label: "ISO", value: String(format: "%.0f", iso))
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onStrip) {
                Label("Strip All Metadata", systemImage: "eye.slash.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("AccentCyan"))
                    .foregroundStyle(Color("BackgroundDark"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 12) {
                Button {
                    showStripOptions = true
                } label: {
                    Label("Custom Strip", systemImage: "slider.horizontal.3")
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

                Button(action: onCancel) {
                    Text("Cancel")
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

    private func validatedCoordinate(for photo: PhotoMetadata) -> CLLocationCoordinate2D? {
        guard let coord = photo.coordinate, CLLocationCoordinate2DIsValid(coord) else {
            return nil
        }
        guard abs(coord.latitude) <= 90, abs(coord.longitude) <= 180 else {
            return nil
        }
        return coord
    }

    private func locationPreviewRegion(for coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    }

    private func openCoordinateInMaps(_ coordinate: CLLocationCoordinate2D) {
        let urlString = "http://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=Photo%20Location"
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
}
