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

    /// Strips metadata from a video file and returns the URL of the cleaned temp file.
    /// Caller must delete the output file after use.
    static func stripMetadata(
        from inputURL: URL,
        onProgress: (@Sendable (Double) async -> Void)? = nil
    ) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        guard try await asset.load(.isExportable) else {
            throw VideoStripError.unsupportedFormat
        }

        let ext = inputURL.pathExtension.lowercased()
        let preferredType: AVFileType = ext == "mp4" ? .mp4 : .mov
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw VideoStripError.exportFailed("Could not create export session")
        }

        let outputFileType: AVFileType
        if session.supportedFileTypes.contains(preferredType) {
            outputFileType = preferredType
        } else if let fallbackType = session.supportedFileTypes.first(where: { $0 == .mov || $0 == .mp4 }) {
            outputFileType = fallbackType
        } else {
            throw VideoStripError.unsupportedFormat
        }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExifArmor_\(UUID().uuidString).\(ext.isEmpty ? "mov" : ext)")

        session.metadata = []
        session.metadataItemFilter = AVMetadataItemFilter.forSharing()
        session.directoryForTemporaryFiles = FileManager.default.temporaryDirectory

        let progressTask = Task {
            for await state in session.states(updateInterval: 0.2) {
                guard !Task.isCancelled else { break }
                if case .exporting(let progress) = state {
                    await onProgress?(progress.fractionCompleted)
                }
            }
        }

        do {
            await onProgress?(0)
            
            // Wrap export in a timeout task group
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await session.export(to: tmpURL, as: outputFileType)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 120 * 1_000_000_000) // 120 seconds
                    throw VideoStripError.exportTimeout
                }
                
                // First one to finish wins
                try await group.next()
                group.cancelAll()
            }
            
            progressTask.cancel()
            await onProgress?(1)
            return tmpURL
        } catch is CancellationError {
            progressTask.cancel()
            try? FileManager.default.removeItem(at: tmpURL)
            throw VideoStripError.cancelled
        } catch {
            progressTask.cancel()
            try? FileManager.default.removeItem(at: tmpURL)
            if error is VideoStripError {
                throw error
            }
            throw VideoStripError.exportFailed(error.localizedDescription)
        }
    }
}
