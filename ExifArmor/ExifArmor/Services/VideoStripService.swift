import AVFoundation
import Foundation

struct VideoStripService {
    enum VideoStripError: LocalizedError {
        case exportFailed(String?)
        case unsupportedFormat
        case cancelled
        case exportTimeout

        var errorDescription: String? {
            switch self {
            case .exportFailed(let message):
                return "Export failed: \(message ?? "unknown error")"
            case .unsupportedFormat:
                return "This video format is not supported."
            case .cancelled:
                return "Export was cancelled."
            case .exportTimeout:
                return "Video export timed out — try a shorter clip or lower resolution."
            }
        }
    }

    /// Strips metadata from a video file at both container and track level.
    /// Returns the URL of the cleaned temp file. Caller must delete after use.
    static func stripMetadata(
        from inputURL: URL,
        onProgress: (@Sendable (Double) async -> Void)? = nil
    ) async throws -> URL {
        await onProgress?(0.05)

        // Load asset to verify it's exportable
        let asset = AVURLAsset(url: inputURL)
        guard try await asset.load(.isExportable) else {
            throw VideoStripError.unsupportedFormat
        }

        let ext = inputURL.pathExtension.lowercased()
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExifArmor_\(UUID().uuidString).\(ext.isEmpty ? "mov" : ext)")

        await onProgress?(0.1)

        // Build a mutable movie on a background thread so we can zero all metadata:
        //   1. movie-level metadata (GPS, device info, creation date, etc.)
        //   2. every track's metadata (embedded per-track EXIF/location headers)
        let mutableMovie: AVMutableMovie = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let movie = AVMutableMovie(url: inputURL, options: nil)
                // Strip container-level metadata
                movie.metadata = []
                // Strip every track's metadata
                for track in movie.tracks {
                    track.metadata = []
                }
                continuation.resume(returning: movie)
            }
        }

        await onProgress?(0.25)

        // Export the metadata-clean mutable movie
        guard let session = AVAssetExportSession(
            asset: mutableMovie,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw VideoStripError.exportFailed("Could not create export session")
        }

        // Belt-and-suspenders: also clear session-level metadata
        session.metadata = []
        session.directoryForTemporaryFiles = FileManager.default.temporaryDirectory

        let preferredType: AVFileType = ext == "mp4" ? .mp4 : .mov
        let outputFileType: AVFileType
        if session.supportedFileTypes.contains(preferredType) {
            outputFileType = preferredType
        } else if let fallback = session.supportedFileTypes.first(where: { $0 == .mov || $0 == .mp4 }) {
            outputFileType = fallback
        } else {
            throw VideoStripError.unsupportedFormat
        }

        // Per-export progress reporting via session.states(updateInterval:) is
        // iOS 18+ only. On iOS 17 we just keep the coarse 0.25 → 1.0 jump.
        var progressTask: Task<Void, Never>?
        if #available(iOS 18.0, *) {
            progressTask = Task {
                for await state in session.states(updateInterval: 0.2) {
                    guard !Task.isCancelled else { break }
                    if case .exporting(let progress) = state {
                        // Map 0→1 export progress to 0.25→1.0 overall progress
                        await onProgress?(0.25 + progress.fractionCompleted * 0.75)
                    }
                }
            }
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await session.export(to: tmpURL, as: outputFileType)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 120 * 1_000_000_000)
                    throw VideoStripError.exportTimeout
                }
                try await group.next()
                group.cancelAll()
            }
            progressTask?.cancel()
            await onProgress?(1.0)
            return tmpURL
        } catch is CancellationError {
            progressTask?.cancel()
            try? FileManager.default.removeItem(at: tmpURL)
            throw VideoStripError.cancelled
        } catch {
            progressTask?.cancel()
            try? FileManager.default.removeItem(at: tmpURL)
            if error is VideoStripError { throw error }
            throw VideoStripError.exportFailed(error.localizedDescription)
        }
    }
}
