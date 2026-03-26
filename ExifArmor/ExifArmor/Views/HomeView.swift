import SwiftUI
import PhotosUI

struct HomeView: View {
    @Environment(StoreManager.self) private var store
    @Environment(FreeTierManager.self) private var freeTier
    @Environment(PrivacyReportManager.self) private var report

    @State private var viewModel = PhotoStripViewModel()
    @State private var showPhotoPicker = false
    @State private var showUpgradeSheet = false
    @State private var showShareSheet = false
    @State private var showSavedAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundDark").ignoresSafeArea()

                switch viewModel.phase {
                case .idle:
                    idleView
                case .loading:
                    loadingView
                case .preview:
                    ExposurePreviewView(
                        viewModel: viewModel,
                        onStrip: handleStrip,
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
            .navigationTitle("ExifArmor")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !store.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showUpgradeSheet = true
                        } label: {
                            Text("PRO")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        colors: [Color("AccentCyan"), Color("AccentMagenta")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
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
            .alert("Saved!", isPresented: $showSavedAlert) {
                Button("OK") { viewModel.reset() }
            } message: {
                Text("\(viewModel.totalProcessedMediaCount) cleaned item(s) saved to your library.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("EmptyNoPhotos")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(spacing: 8) {
                Text("Select photos or videos to scan")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color("TextPrimary"))

                Text("See what hidden data your media reveal")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextSecondary"))
            }

            Button {
                showPhotoPicker = true
            } label: {
                Label("Choose Photos", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("AccentCyan"))
                    .foregroundStyle(Color("BackgroundDark"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            if !store.isPro {
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

            Spacer()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.effectiveProgress, total: Double(max(viewModel.totalCount, 1)))
                .tint(Color("AccentCyan"))
                .padding(.horizontal, 60)

            Text(viewModel.statusMessage.isEmpty ? "Scanning \(viewModel.processedCount)/\(viewModel.totalCount) items…" : viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(Color("TextSecondary"))

            Text("\(viewModel.processedCount)/\(viewModel.totalCount)")
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    // MARK: - Stripping

    private var strippingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.effectiveProgress,
                         total: Double(viewModel.totalCount))
                .tint(Color("AccentCyan"))
                .padding(.horizontal, 60)

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
                .foregroundStyle(Color("WarningRed"))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
            .tint(Color("AccentCyan"))
        }
    }

    // MARK: - Actions

    private func handleStrip() {
        // Check free tier limit
        let count = viewModel.analyzedPhotos.count + (viewModel.stripOptions.includeVideos ? viewModel.analyzedVideos.count : 0)
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

        AnalyticsLogger.shared.log(.stripInitiated, metadata: ["count": "\(count)"])

        Task {
            await viewModel.stripAll()
            // Record usage
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
