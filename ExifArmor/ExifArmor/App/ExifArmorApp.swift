import SwiftUI

@main
struct ExifArmorApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var storeManager = StoreManager()
    @State private var privacyReport = PrivacyReportManager()
    @State private var freeTier = FreeTierManager()
    @State private var templateManager = TemplateManager()
    @State private var isShowingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingSplash {
                    LaunchSplashView(isVisible: $isShowingSplash)
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    appRoot
                        .transition(.opacity)
                        .zIndex(0)
                }
            }
            .animation(.easeIn(duration: 0.25), value: isShowingSplash)
            .tint(Color.kataGold)
        }
    }

    @ViewBuilder
    private var appRoot: some View {
        if hasCompletedOnboarding {
            MainTabView()
                .environment(storeManager)
                .environment(privacyReport)
                .environment(freeTier)
                .environment(templateManager)
                .onAppear {
                    AnalyticsLogger.shared.log(.appLaunch)
                }
        } else {
            OnboardingView(onComplete: {
                AnalyticsLogger.shared.log(.onboardingCompleted)
                withAnimation {
                    hasCompletedOnboarding = true
                }
            })
            .onAppear {
                AnalyticsLogger.shared.log(.onboardingStarted)
            }
        }
    }
}
