import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(TemplateManager.self) private var templateManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("defaultStripMode") private var defaultStripMode = "all"
    @State private var showTipThankYou = false

    var body: some View {
        NavigationStack {
            List {
                // Pro status
                Section {
                    if store.isPro {
                        HStack(spacing: 12) {
                            Image("BadgePro")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("ExifArmor Pro")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color("AccentCyan"))
                                Text("All features unlocked")
                                    .font(.caption)
                                    .foregroundStyle(Color("TextSecondary"))
                            }

                            Spacer()

                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color("AccentCyan"))
                        }
                    } else {
                        NavigationLink {
                            ProUpgradeView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Color("AccentGold"))
                                Text("Upgrade to Pro")
                                .accessibilityLabel("Upgrade to Pro")
                                    .foregroundStyle(Color("TextPrimary"))
                            }
                        }

                        Button {
                        KataHaptic.tap.fire()
                            KataHaptic.tap.fire()
                            Task { await store.restorePurchases() }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(Color("AccentCyan"))
                                Text("Restore Purchase")
                            .accessibilityLabel("Restore previous purchase")
                            }
                        }
                    }
                }

                // Defaults
                Section {
                    Picker("Default Strip Mode", selection: $defaultStripMode) {
                        Text("Remove All").tag("all")
                        Text("Location Only").tag("location")
                        Text("Privacy Focused").tag("privacy")
                    }
                } header: {
                    Text("Defaults")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(defaultModeDescription)
                        Text("Remove All strips all detected metadata except image orientation.")
                        Text("Location Only removes GPS coordinates and altitude only.")
                        Text("Privacy Focused removes location, date/time, and device info, but keeps camera settings like lens, ISO, and exposure.")
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(Color("TextSecondary"))
                    }

                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(Color("AccentCyan"))
                            Text("Replay Onboarding")
                            .accessibilityLabel("Replay onboarding tutorial")
                        }
                    }

                    Link(destination: URL(string: "mailto:feedback@katafract.com?subject=ExifArmor%20feedback")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(Color("AccentCyan"))
                            Text("Send Feedback")
                                .foregroundStyle(Color("TextPrimary"))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary"))
                        }
                    }

                    Link(destination: URL(string: "https://katafract.com/support/exifarmor")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(Color("AccentCyan"))
                            Text("Support")
                                .foregroundStyle(Color("TextPrimary"))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary"))
                        }
                    }

                    Link(destination: URL(string: "https://katafract.com/privacy/exifarmor")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(Color("AccentCyan"))
                            Text("Privacy Policy")
                                .foregroundStyle(Color("TextPrimary"))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary"))
                        }
                    }

                    Link(destination: URL(string: "https://katafract.com/terms/exifarmor")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(Color("AccentCyan"))
                            Text("Terms of Use")
                                .foregroundStyle(Color("TextPrimary"))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary"))
                        }
                    }

                    NavigationLink {
                        AppGroupDiagnosticsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checklist")
                                .foregroundStyle(Color("AccentCyan"))
                            Text("App Group Diagnostics")
                                .foregroundStyle(Color("TextPrimary"))
                        }
                    }
                }

                if !store.tipProducts.isEmpty {
                    Section {
                        ForEach(store.tipProducts) { product in
                            Button {
                                Task {
                                    let success = await store.purchaseTip(product)
                                    if success {
                                        showTipThankYou = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(Color("AccentMagenta"))
                                    Text("Tip \(product.displayPrice)")
                                        .foregroundStyle(Color("TextPrimary"))
                                    Spacer()
                                }
                            }
                        }
                    } header: {
                        Text("Support Development")
                    } footer: {
                        Text("ExifArmor is built by one person. Tips go directly to indie development. No extra features - just gratitude.")
                    }
                }

                Section("Templates") {
                    ForEach(Array(templateManager.allTemplates.enumerated()), id: \.element.id) { index, template in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                    .foregroundStyle(Color("TextPrimary"))
                                Text(templateSummary(template.options))
                                    .font(.caption)
                                    .foregroundStyle(Color("TextSecondary"))
                            }

                            Spacer()

                            if template.isBuiltIn {
                                Text("Built-in")
                                    .font(.caption2)
                                    .foregroundStyle(Color("TextSecondary"))
                            }
                        }
                        .deleteDisabled(index < StripTemplate.builtIns.count)
                    }
                    .onDelete { indexSet in
                        let offset = StripTemplate.builtIns.count
                        for index in indexSet {
                            let adjustedIndex = index - offset
                            if adjustedIndex >= 0 && adjustedIndex < templateManager.customTemplates.count {
                                templateManager.delete(templateManager.customTemplates[adjustedIndex])
                            }
                        }
                    }
                }

                // Privacy
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Privacy")
                                .font(.subheadline.weight(.semibold))
                            Text("ExifArmor never transmits your photos. All processing happens on your device.")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary"))
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Color("SuccessGreen"))
                    }
                }

                #if DEBUG
                Section("Developer") {
                    NavigationLink {
                        AnalyticsDebugView()
                    } label: {
                        Label("Analytics Debug", systemImage: "chart.bar.fill")
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await store.ensureProductsLoaded()
            }
            .alert("Thank You!", isPresented: $showTipThankYou) {
                Button("You're welcome!", role: .cancel) {}
            } message: {
                Text("Your support means a lot and helps keep ExifArmor independent and ad-free.")
            }
        }
    }

    private var defaultModeDescription: String {
        switch defaultStripMode {
        case "location":
            return "Current default: Location Only. Best when you want to hide where a photo was taken but keep the rest of the camera metadata."
        case "privacy":
            return "Current default: Privacy Focused. Best when you want to remove personal identifiers but still keep photographic settings."
        default:
            return "Current default: Remove All. Best when you want the safest share-ready copy with the least metadata left behind."
        }
    }

    private func templateSummary(_ options: StripOptions) -> String {
        if options.removeAll {
            return "Removes all metadata"
        }

        var parts: [String] = []
        if options.removeLocation { parts.append("location") }
        if options.removeDateTime { parts.append("date/time") }
        if options.removeDeviceInfo { parts.append("device info") }
        if options.removeCameraSettings { parts.append("camera settings") }

        return parts.isEmpty ? "No fields selected" : "Removes " + parts.joined(separator: ", ")
    }
}
