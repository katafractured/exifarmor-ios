import AVKit
import CoreLocation
import MapKit
import SwiftUI

struct VideoMetadataCard: View {
    let video: VideoMetadata

    var body: some View {
        MetadataCard(
            icon: "video.fill",
            title: "Video File",
            iconColor: Color("AccentMagenta"),
            severity: video.hasLocation ? .critical : .info
        ) {
            VideoPreview(url: video.fileURL)

            if let location = video.location {
                Map(initialPosition: .region(locationPreviewRegion(for: location.coordinate))) {
                    Marker("Recorded here", coordinate: location.coordinate)
                        .tint(Color("WarningRed"))
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .allowsHitTesting(false)
            }

            MetadataRow(label: "Duration", value: video.formattedDuration)
            MetadataRow(label: "File Size", value: video.formattedFileSize)

            if let location = video.location {
                MetadataRow(
                    label: "GPS",
                    value: String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
                )
            }

            if let creationDate = video.creationDate {
                MetadataRow(
                    label: "Created",
                    value: creationDate.formatted(date: .abbreviated, time: .shortened)
                )
            }

            if let make = video.make {
                MetadataRow(label: "Make", value: make)
            }

            if let model = video.model {
                MetadataRow(label: "Model", value: model)
            }

            if let software = video.software {
                MetadataRow(label: "Software", value: software)
            }
        }
    }

    private func locationPreviewRegion(for coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    }
}

private struct VideoPreview: View {
    let url: URL

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color("CardBackground"))
                    .frame(height: 220)
                    .overlay {
                        ProgressView()
                            .tint(Color("AccentCyan"))
                    }
            }
        }
        .onAppear {
            guard player == nil else { return }
            let player = AVPlayer(url: url)
            player.isMuted = true
            self.player = player
        }
        .onDisappear {
            player?.pause()
        }
    }
}
