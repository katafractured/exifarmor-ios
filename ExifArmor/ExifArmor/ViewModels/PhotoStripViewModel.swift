import Foundation
import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Explicitly requests HEIC data from the Photos library to prevent silent JPEG transcoding.
private struct HEICPhoto: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .heic) { HEICPhoto(data: $0) }
    }
}

private struct PickedVideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PickedVideos", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let filename = received.file.lastPathComponent.isEmpty
                ? "ExifArmor_\(UUID().uuidString).mov"
                : "\(UUID().uuidString)_\(received.file.lastPathComponent)"
            let destinationURL = directory.appendingPathComponent(filename)

            try FileManager.default.copyItem(at: received.file, to: destinationURL)
            return Self(url: destinationURL)
        }
    }
}

/// Drives the core workflow: pick → analyze → preview → strip → save/share.
@Observable
final class PhotoStripViewModel {

    private enum Keys {
        static let defaultStripMode = "defaultStripMode"
    }

    // MARK: - State

    enum Phase {
        case idle
        case loading
        case preview
        case stripping
        case done
        case error(String)
    }

    var phase: Phase = .idle
    var selectedItems: [PhotosPickerItem] = []
    var analyzedPhotos: [PhotoMetadata] = []
    var analyzedVideos: [VideoMetadata] = []
    var stripResults: [StripResult] = []
    var videoStripResults: [URL] = []
    var stripOptions: StripOptions = .all
    var showStripOptions: Bool = false
    var statusMessage: String = ""
    var currentItemProgress: Double = 0
    private var importedVideoURLs: [URL] = []
    private var sharedItemURLs: [URL] = []

    // Batch progress
    var processedCount: Int = 0
    var totalCount: Int = 0
    var livePhotoCount: Int = 0
    var videoStripFailures: Int = 0

    // MARK: - Load Selected Photos

    /// Load image data from PhotosPicker selections and extract metadata.
    func loadSelectedPhotos() async {
        guard !selectedItems.isEmpty else { return }

        cleanupImportedVideos()

        await MainActor.run {
            phase = .loading
            analyzedPhotos = []
            analyzedVideos = []
            stripResults = []
            videoStripResults = []
            processedCount = 0
            currentItemProgress = 0
            statusMessage = "Scanning selected media…"
            totalCount = selectedItems.count
            livePhotoCount = 0
            videoStripFailures = 0
        }

        var photoResults: [PhotoMetadata] = []
        var videoResults: [VideoMetadata] = []

        for (index, item) in selectedItems.enumerated() {
            await MainActor.run {
                currentItemProgress = 0
                statusMessage = isMovieItem(item)
                    ? "Importing video \(index + 1) of \(selectedItems.count)…"
                    : "Scanning photo \(index + 1) of \(selectedItems.count)…"
            }

            if isMovieItem(item) {
                if let pickedFile = try? await item.loadTransferable(type: PickedVideoFile.self) {
                    importedVideoURLs.append(pickedFile.url)
                    await MainActor.run {
                        statusMessage = "Reading video metadata \(index + 1) of \(selectedItems.count)…"
                    }
                    let videoMeta = await VideoMetadataService.extractMetadata(from: pickedFile.url)
                    videoResults.append(videoMeta)
                }
            } else {
                do {
                    // Prefer HEIC-specific loading to prevent iOS from silently
                    // transcoding HEIC photos to JPEG before we see the data.
                    let rawData: Data?
                    if item.supportedContentTypes.contains(.heic),
                       let heicPhoto = try? await item.loadTransferable(type: HEICPhoto.self) {
                        rawData = heicPhoto.data
                    } else {
                        rawData = try await item.loadTransferable(type: Data.self)
                    }
                    guard let data = rawData,
                          let image = UIImage(data: data)
                    else { continue }

                    let isLivePhoto = isLivePhotoItem(item)
                    if isLivePhoto {
                        await MainActor.run {
                            self.livePhotoCount += 1
                        }
                    }
                    var metadata = MetadataService.extractMetadata(from: data, image: image)
                    metadata.isLivePhoto = isLivePhoto
                    photoResults.append(metadata)
                } catch {
                    // Skip photos that fail to load
                }
            }

            await MainActor.run {
                currentItemProgress = 0
                processedCount += 1
            }
        }

        await MainActor.run {
            analyzedPhotos = photoResults
            analyzedVideos = videoResults
            statusMessage = ""
            phase = (photoResults.isEmpty && videoResults.isEmpty) ? .error("Could not load any media") : .preview
        }
    }

    // MARK: - Strip Metadata

    func stripAll() async {
        await MainActor.run {
            phase = .stripping
            stripResults = []
            videoStripResults = []
            processedCount = 0
            currentItemProgress = 0
            statusMessage = "Preparing media cleanup…"
            totalCount = analyzedPhotos.count + (stripOptions.includeVideos ? analyzedVideos.count : 0)
        }

        var results: [StripResult] = []

        for (index, metadata) in analyzedPhotos.enumerated() {
            await MainActor.run {
                currentItemProgress = 0
                statusMessage = "Cleaning photo \(index + 1) of \(totalCount)…"
            }
            let fieldsToRemove = StripService.countFieldsToRemove(
                from: metadata, options: stripOptions
            )

            if let cleanedData = StripService.stripMetadata(
                from: metadata.imageData, options: stripOptions
            ),
               let cleanedImage = UIImage(data: cleanedData) {

                let result = StripResult(
                    originalMetadata: metadata,
                    cleanedImageData: cleanedData,
                    cleanedImage: cleanedImage,
                    fieldsRemoved: fieldsToRemove
                )
                results.append(result)
            }

            await MainActor.run {
                currentItemProgress = 0
                processedCount += 1
            }
        }

        await stripAllVideos()

        await MainActor.run {
            stripResults = results
            statusMessage = ""
            phase = (results.isEmpty && videoStripResults.isEmpty) ? .error("Failed to strip media") : .done
        }
    }

    func stripAllVideos() async {
        guard stripOptions.includeVideos else { return }

        let videoOffset = analyzedPhotos.count
        let totalVideos = analyzedVideos.count
        for (index, meta) in analyzedVideos.enumerated() {
            await MainActor.run {
                currentItemProgress = 0
                statusMessage = "Cleaning video \(index + 1) of \(totalVideos)…"
            }

            do {
                let cleanURL = try await VideoStripService.stripMetadata(
                    from: meta.fileURL,
                    onProgress: { [weak viewModel = self, index, totalVideos] progress in
                        await viewModel?.updateVideoProgress(
                            itemIndex: index,
                            totalVideos: totalVideos,
                            progress: progress
                        )
                    }
                )
                await MainActor.run {
                    videoStripResults.append(cleanURL)
                    currentItemProgress = 0
                    processedCount += 1
                }
            } catch {
                await MainActor.run {
                    videoStripFailures += 1
                    currentItemProgress = 0
                    statusMessage = "Video cleanup failed for item \(videoOffset + index + 1): \(error.localizedDescription)"
                    processedCount += 1
                }
            }
        }
    }

    @MainActor
    private func updateVideoProgress(itemIndex: Int, totalVideos: Int, progress: Double) {
        currentItemProgress = progress
        statusMessage = "Cleaning video \(itemIndex + 1) of \(totalVideos)… \(Int(progress * 100))%"
    }

    // MARK: - Save to Photo Library

    func saveAllToPhotoLibrary() async -> Bool {
        do {
            for result in stripResults {
                try await saveToPhotoLibrary(data: result.cleanedImageData)
            }
            for url in videoStripResults {
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .video, fileURL: url, options: nil)
                }
            }
            return true
        } catch {
            await MainActor.run {
                phase = .error("Failed to save: \(error.localizedDescription)")
            }
            return false
        }
    }

    private func saveToPhotoLibrary(data: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "ExifArmor",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to save cleaned photo"]
                    ))
                }
            }
        }
    }

    // MARK: - Share

    /// Returns temp file URLs for the cleaned images so that all share destinations
    /// (Instagram, Facebook, Messages, Mail, etc.) can accept them.
    func shareItems() -> [Any] {
        cleanupSharedItems()
        let tmpDir = FileManager.default.temporaryDirectory
        let imageURLs = stripResults.compactMap { result -> URL? in
            let ext = preferredImageExtension(for: result.originalMetadata.sourceUTI)
            let filename = "ExifArmor_\(UUID().uuidString.prefix(8)).\(ext)"
            let url = tmpDir.appendingPathComponent(filename)
            let data = result.cleanedImageData
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }

        sharedItemURLs = imageURLs + videoStripResults
        return sharedItemURLs
    }

    // MARK: - Reset

    func reset() {
        cleanupSharedItems()
        cleanupImportedVideos()
        for url in videoStripResults {
            try? FileManager.default.removeItem(at: url)
        }
        phase = .idle
        selectedItems = []
        analyzedPhotos = []
        analyzedVideos = []
        stripResults = []
        videoStripResults = []
        processedCount = 0
        currentItemProgress = 0
        statusMessage = ""
        totalCount = 0
        livePhotoCount = 0
        videoStripFailures = 0
        applySavedDefaultStripMode()
    }

    // MARK: - Stats for this batch

    var totalFieldsRemoved: Int {
        stripResults.reduce(0) { $0 + $1.fieldsRemoved }
            + analyzedVideos.reduce(0) { $0 + $1.exposedFieldCount }
    }

    var hadLocationData: Bool {
        analyzedPhotos.contains { $0.hasLocation } || analyzedVideos.contains { $0.hasLocation }
    }

    var totalProcessedMediaCount: Int {
        stripResults.count + videoStripResults.count
    }

    var effectiveProgress: Double {
        guard totalCount > 0 else { return 0 }
        return min(Double(processedCount) + currentItemProgress, Double(totalCount))
    }

    func applySavedDefaultStripMode() {
        stripOptions = stripOptions(for: UserDefaults.standard.string(forKey: Keys.defaultStripMode) ?? "all")
    }

    private func stripOptions(for mode: String) -> StripOptions {
        switch mode {
        case "location":
            return .locationOnly
        case "privacy":
            return .privacyFocused
        default:
            return .all
        }
    }

    private func preferredImageExtension(for sourceUTI: String?) -> String {
        guard let sourceUTI,
              let type = UTType(sourceUTI),
              let ext = type.preferredFilenameExtension
        else {
            return "jpg"
        }
        return ext
    }

    private func cleanupSharedItems() {
        for url in sharedItemURLs {
            try? FileManager.default.removeItem(at: url)
        }
        sharedItemURLs = []
    }

    private func cleanupImportedVideos() {
        for url in importedVideoURLs {
            try? FileManager.default.removeItem(at: url)
        }
        importedVideoURLs = []

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PickedVideos", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }

    private func isMovieItem(_ item: PhotosPickerItem) -> Bool {
        item.supportedContentTypes.contains { $0.conforms(to: .movie) }
    }

    private func isLivePhotoItem(_ item: PhotosPickerItem) -> Bool {
        item.supportedContentTypes.contains { $0.conforms(to: .livePhoto) }
    }
}
