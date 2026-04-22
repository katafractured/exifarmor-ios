import SwiftUI
import PhotosUI

struct HomeView: View {
    @Environment(StoreManager.self) private var store
    @Environment(FreeTierManager.self) private var freeTier
    @Environment(PrivacyReportManager.self) private var report
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var viewModel = PhotoStripViewModel()
    @State private var showPhotoPicker = false
    @State private var showUpgradeSheet = false
    @State private var showShareSheet = false
    @State private var showSavedAlert = false
    @State private var showStripConfirm = false
    @State private var showSealSuccess = false
    @State private var sealThumbnail: UIImage?

    var body: some View {
        ZStack {
            if sizeClass == .regular {
                NavigationSplitView {
                    pickerSidebar
                } detail: {
                    ipadDetail
                }
            } else {
                NavigationStack {
                    phaseContent(idleFallback: idleView)
                        .navigationTitle("ExifArmor")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { proButton }
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $viewModel.selectedItems,
            maxSelectionCount: store.isPro ? 50 : 5,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: viewModel.selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            viewModel.applySavedDefaultStripMode()
            AnalyticsLogger.shared.logPhotosSelected(count: newItems.count)
            Task { await viewModel.loadSelectedPhotos() }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            ProUpgradeView()
        }
        .sheet(isPresented: $showShareSheet) {
            if !viewModel.shareItems().isEmpty {
                ShareSheet(items: viewModel.shareItems())
            }
        }
        .sheet(isPresented: $showStripConfirm) {
            let count = viewModel.analyzedPhotos.count
                + (viewModel.stripOptions.includeVideos ? viewModel.analyzedVideos.count : 0)
            StripConfirmSheet(
                photoCount: count,
                onConfirm: {
                    showStripConfirm = false
                    executeStrip()
                },
                onCancel: {
                    showStripConfirm = false
                }
            )
        }
        .fullScreenCover(isPresented: $showSealSuccess) {
            SealSuccessView(
                thumbnail: sealThumbnail,
                onDismiss: { showSealSuccess = false }
            )
        }
        .alert("Saved!", isPresented: $showSavedAlert) {
            Button("OK") { viewModel.reset() }
        } message: {
            Text(savedAlertMessage)
        }
    }

    // MARK: - Saved alert message
    private var savedAlertMessage: String {
        let photoCount = viewModel.stripResults.count
        let videoCount = viewModel.videoStripResults.count
        let photoPart = photoCount > 0
            ? "\(photoCount) \(photoCount == 1 ? "photo" : "photos")" : ""
        let videoPart = videoCount > 0
            ? "\(videoCount) \(videoCount == 1 ? "video" : "videos")" : ""
        switch (photoPart.isEmpty, videoPart.isEmpty) {
        case (false, false): return "\(photoPart) and \(videoPart) saved to your library."
        case (false, true):  return "\(photoPart) saved to your library."
        case (true, false):  return "\(videoPart) saved to your library."
        default:             return "Saved to your library."
        }
    }

    // MARK: - iPad Sidebar
    private var pickerSidebar: some View {
        ZStack {
            Color("BackgroundDark").ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                brandedEmptyState
                kataPickerButton
                if !store.isPro { freeStripCounter }
                Spacer()
            }
        }
        .navigationTitle("ExifArmor")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { proButton }
        }
    }

    // MARK: - iPad Detail
    private var ipadDetail: some View {
        ZStack {
            Color("BackgroundDark").ignoresSafeArea()
        }
        .overlay {
            phaseContent(idleFallback: ipadIdlePlaceholder)
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var ipadIdlePlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash.circle")
                .font(.system(size: 72))
                .foregroundStyle(Color.kataGold.opacity(0.35))
            Text("Choose photos from the sidebar")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color("TextSecondary"))
            Text("Your cleaned media will appear here")
                .font(.subheadline)
                .foregroundStyle(Color("TextSecondary").opacity(0.7))
        }
    }

    // MARK: - Phase content
    @ViewBuilder
    private func phaseContent(idleFallback: some View) -> some View {
        switch viewModel.phase {
        case .idle:
            idleFallback
        case .loading:
            loadingView
        case .preview:
            ExposurePreviewView(
                viewModel: viewModel,
                onStrip: handleStripTapped,
                onCancel: { viewModel.reset() }
            )
        case .stripping:
            strippingView
        case .done:
            StripResultView(
                viewModel: viewModel,
                onSave: handleSave,
                onShare: { showShareSheet = true },
                onDone: { viewModel.reset() }
            )
        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - Pro toolbar button
    @ViewBuilder
    private var proButton: some View {
        if !store.isPro {
            Button {
                showUpgradeSheet = true
            } label: {
                Text("PRO")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.kataGold, Color.kataSapphire],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .foregroundStyle(Color.kataIce)
            }
        }
    }

    // MARK: - Branded empty state (point 5)
    private var brandedEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundStyle(Color.kataGold.opacity(0.5))
            Text("No photos sealed yet.")
                .font(.kataDisplay(18))
                .foregroundStyle(Color.kataIce)
            Text("Pick one or more to strip EXIF metadata.")
                .font(.kataBody(13))
                .foregroundStyle(Color.kataGold.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Kata-styled picker CTA button (point 3)
    private var kataPickerButton: some View {
        Button {
            KataHaptic.tap.fire()
            showPhotoPicker = true
        } label: {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                Text("Choose Photos")
            }
            .font(.kataBody(16)).bold()
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.kataSapphire)
            .foregroundStyle(Color.kataIce)
            .overlay(
                Capsule().stroke(Color.kataGold.opacity(0.5), lineWidth: 0.5)
            )
            .clipShape(Capsule())
        }
        .padding(.horizontal, 40)
    }

    private var freeStripCounter: some View {
        VStack(spacing: 6) {
            Text("\(freeTier.stripsRemaining) free strips remaining today")
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))
            Text("Pro unlocks the premium share extension, larger batch cleaning, and custom strip controls.")
                .font(.caption2)
                .foregroundStyle(Color("TextSecondary").opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Idle state (iPhone) — hero repaint (point 3)
    private var idleView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero header
            VStack(spacing: 6) {
                Text("ExifArmor")
                    .font(.kataDisplay(28))
                    .foregroundStyle(Color.kataIce)
                Text("Nothing personal leaves with your photos.")
                    .font(.kataBody(14))
                    .foregroundStyle(Color.kataGold.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 32)

            // Card backing
            VStack(spacing: 20) {
                brandedEmptyState
                kataPickerButton
                if !store.isPro { freeStripCounter }
            }
            .padding(20)
            .background(Color.kataSapphire.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.kataGold.opacity(0.3), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Loading (point 7 — KataProgressRing)
    private var loadingView: some View {
        VStack(spacing: 20) {
            let progress = viewModel.totalCount > 0
                ? viewModel.effectiveProgress / Double(max(viewModel.totalCount, 1))
                : 0.0
            KataProgressRing(progress: progress, diameter: 56, lineWidth: 3)

            Text(viewModel.statusMessage.isEmpty
                 ? "Scanning \(viewModel.processedCount)/\(viewModel.totalCount) items…"
                 : viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(Color("TextSecondary"))

            Text("\(viewModel.processedCount)/\(viewModel.totalCount)")
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    // MARK: - Stripping (point 7 — KataProgressRing)
    private var strippingView: some View {
        VStack(spacing: 20) {
            let progress = viewModel.totalCount > 0
                ? viewModel.effectiveProgress / Double(viewModel.totalCount)
                : 0.0
            KataProgressRing(progress: progress, diameter: 56, lineWidth: 3)

            Text(viewModel.statusMessage.isEmpty ? "Stripping metadata…" : viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(Color("TextSecondary"))

            Text("\(viewModel.processedCount)/\(viewModel.totalCount)")
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    // MARK: - Error
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.kataGold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again") { viewModel.reset() }
                .buttonStyle(.bordered)
                .tint(Color.kataGold)
        }
    }

    // MARK: - Strip flow
    private func handleStripTapped() {
        let count = viewModel.analyzedPhotos.count
            + (viewModel.stripOptions.includeVideos ? viewModel.analyzedVideos.count : 0)
        if !store.isPro && !freeTier.canStrip(isPro: false) {
            AnalyticsLogger.shared.log(.freeLimitReached)
            AnalyticsLogger.shared.log(.paywallShown, metadata: ["trigger": "free_limit"])
            showUpgradeSheet = true
            return
        }
        if !store.isPro && freeTier.stripsRemaining < count {
            AnalyticsLogger.shared.log(.freeLimitReached)
            AnalyticsLogger.shared.log(.paywallShown, metadata: ["trigger": "batch_exceeds_limit"])
            showUpgradeSheet = true
            return
        }
        showStripConfirm = true
    }

    private func executeStrip() {
        let count = viewModel.analyzedPhotos.count
            + (viewModel.stripOptions.includeVideos ? viewModel.analyzedVideos.count : 0)
        AnalyticsLogger.shared.log(.stripInitiated, metadata: ["count": "\(count)"])
        Task {
            await viewModel.stripAll()
            freeTier.recordStrips(count: viewModel.totalProcessedMediaCount, isPro: store.isPro)
            report.recordStrip(
                photosCount: viewModel.totalProcessedMediaCount,
                fieldsRemoved: viewModel.totalFieldsRemoved,
                hadLocation: viewModel.hadLocationData
            )
            AnalyticsLogger.shared.logStripCompleted(
                photosCount: viewModel.totalProcessedMediaCount,
                fieldsRemoved: viewModel.totalFieldsRemoved,
                hadGPS: viewModel.hadLocationData
            )
            // Show ceremonial seal overlay
            sealThumbnail = viewModel.stripResults.first?.cleanedImage
            showSealSuccess = true
        }
    }

    private func handleSave() {
        Task {
            let saved = await viewModel.saveAllToPhotoLibrary()
            if saved {
                AnalyticsLogger.shared.log(.photosSaved, metadata: [
                    "count": "\(viewModel.totalProcessedMediaCount)"
                ])
                showSavedAlert = true
            }
        }
    }
}

// MARK: - Share Sheet UIKit Wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
