import SwiftUI
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

struct ProUpgradeView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false

    private let features: [(icon: String, title: String, description: String)] = [
        ("infinity", "Unlimited Strips", "Remove the daily cap and clean as many photos as you want"),
        ("square.and.arrow.up.on.square", "Premium Share Extension", "Clean photos straight from Photos or another app, then forward the clean copy to Instagram, Messages, Facebook, and more"),
        ("rectangle.stack.fill", "Batch Mode", "Select and clean larger groups of photos in one pass"),
        ("slider.horizontal.3", "Custom Strip Options", "Choose whether to remove everything, location only, or privacy-sensitive metadata while keeping camera settings"),
        ("shield.checkered", "Privacy Report", "Track how many photos and exposed fields you have cleaned over time"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    headerSection

                    // Features list
                    featuresSection

                    // Trust badges
                    trustSection

                    // Purchase button
                    purchaseButton

                    // Restore
                    restoreButton

                    #if DEBUG
                    diagnosticsSection
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color("BackgroundDark"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await store.ensureProductsLoaded()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("BadgePro")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            Text("ExifArmor Pro")
                .font(.title.weight(.bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color("AccentCyan"), Color("AccentMagenta")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("One-time purchase. Unlock every Pro feature forever for $0.99.")
                .font(.subheadline)
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color("AccentCyan"))
                        .frame(width: 36, height: 36)
                        .background(Color("AccentCyan").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextPrimary"))

                        Text(feature.description)
                            .font(.caption)
                            .foregroundStyle(Color("TextSecondary"))
                    }

                    Spacer()
                }
                .padding(.vertical, 12)

                if index < features.count - 1 {
                    Divider()
                        .background(Color("TextSecondary").opacity(0.2))
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Trust

    private var trustSection: some View {
        HStack(spacing: 20) {
            trustBadge(icon: "lock.shield.fill", text: "No Data\nCollection")
            trustBadge(icon: "wifi.slash", text: "Works\nOffline")
            trustBadge(icon: "purchased", text: "One-Time\nPurchase")
        }
        .frame(maxWidth: .infinity)
    }

    private func trustBadge(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color("SuccessGreen"))

            Text(text)
                .font(.caption2)
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Purchase

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                isPurchasing = true
                AnalyticsLogger.shared.log(.purchaseInitiated)
                Task {
                    let success = await store.purchasePro()
                    isPurchasing = false
                    if success {
                        AnalyticsLogger.shared.log(.purchaseCompleted)
                        KataHaptic.unlocked.fire()
                        dismiss()
                    } else {
                        AnalyticsLogger.shared.log(.purchaseCancelled)
                    }
                }
            } label: {
                HStack {
                    if isPurchasing {
                        KataProgressRing(progress: 0.8, diameter: 20, lineWidth: 2)
                            .accessibilityLabel("Purchasing in progress")
                            .tint(Color("BackgroundDark"))
                    }
                    Text("\(store.proProduct?.displayPrice ?? "$0.99") — Unlock Pro Forever")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color("AccentCyan"), Color("AccentMagenta")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isPurchasing || store.isLoading)

            Text("Includes unlimited strips, the premium share extension, batch cleaning, custom strip options, and privacy report progress.")
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)

            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color("WarningRed"))
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await store.restorePurchases() }
            } label: {
                Text("Restore Purchase")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextSecondary"))
            }

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://katafract.com/privacy/exifarmor")!)
                Text("·")
                Link("Terms of Use", destination: URL(string: "https://katafract.com/terms/exifarmor")!)
            }
            .font(.caption)
            .foregroundStyle(Color("TextSecondary"))
        }
    }

    #if DEBUG
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("StoreKit Diagnostics")
                    .font(.headline)
                    .foregroundStyle(Color("TextPrimary"))

                Spacer()

                Button("Copy All") {
                    copyDiagnosticsToPasteboard()
                }
                .font(.caption.weight(.semibold))

                Button("Retry Product Load") {
                    Task { await store.loadProducts() }
                }
                .font(.caption.weight(.semibold))
            }

            diagnosticRow("Bundle ID", store.bundleIdentifier)
            diagnosticRow("Product ID", StoreManager.proProductID)
            diagnosticRow("AppTransaction Env", store.appTransactionEnvironmentDescription)
            diagnosticRow("Testing Mode", store.testingModeDescription)
            diagnosticRow("AppTransaction Bundle", store.appTransactionBundleID)
            diagnosticRow("Last Attempt", "\(store.lastLoadAttempt)")
            diagnosticRow("Last Product Count", "\(store.lastProductCount)")
            diagnosticRow("Last Error", store.lastLoadError)
            diagnosticRow("Resolved Product", store.proProduct?.id ?? "nil")

            if !store.debugLog.isEmpty {
                Divider()
                    .background(Color("TextSecondary").opacity(0.2))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent Log")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("TextSecondary"))

                    ForEach(Array(store.debugLog.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color("TextSecondary"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("TextSecondary"))
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(Color("TextPrimary"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var diagnosticsText: String {
        let rows = [
            ("Bundle ID", store.bundleIdentifier),
            ("Product ID", StoreManager.proProductID),
            ("AppTransaction Env", store.appTransactionEnvironmentDescription),
            ("Testing Mode", store.testingModeDescription),
            ("AppTransaction Bundle", store.appTransactionBundleID),
            ("Last Attempt", "\(store.lastLoadAttempt)"),
            ("Last Product Count", "\(store.lastProductCount)"),
            ("Last Error", store.lastLoadError),
            ("Resolved Product", store.proProduct?.id ?? "nil"),
        ]

        let header = rows.map { "\($0): \($1)" }.joined(separator: "\n")
        let log = store.debugLog.isEmpty ? "Recent Log: None" : "Recent Log:\n" + store.debugLog.joined(separator: "\n")
        return header + "\n" + log
    }

    private func copyDiagnosticsToPasteboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = diagnosticsText
        #endif
    }
    #endif
}
