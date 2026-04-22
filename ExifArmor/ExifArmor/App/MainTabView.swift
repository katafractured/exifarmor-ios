import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Strip", systemImage: "eye.slash.fill", value: 0) {
                    HomeView()
                }
                Tab("Report", systemImage: "shield.checkered", value: 1) {
                    PrivacyReportView()
                }
                Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                    SettingsView()
                }
            }
            .tint(Color.kataGold)
            .tabViewStyle(.sidebarAdaptable)
        } else {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("Strip", systemImage: "eye.slash.fill") }
                    .tag(0)

                PrivacyReportView()
                    .tabItem { Label("Report", systemImage: "shield.checkered") }
                    .tag(1)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(2)
            }
            .tint(Color.kataGold)
        }
    }
}
