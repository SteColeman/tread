import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Collection", systemImage: "shoe.2.fill", value: 0) {
                CollectionView()
            }
            Tab("Activity", systemImage: "figure.walk", value: 1) {
                ActivityView()
            }
            Tab("Insights", systemImage: "chart.bar.fill", value: 2) {
                InsightsView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: 3) {
                SettingsView()
            }
        }
    }
}
