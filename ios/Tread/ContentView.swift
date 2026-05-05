import SwiftUI

struct ContentView: View {
    @Environment(FootwearStore.self) private var store
    @Binding var deepLinkShoeId: UUID?
    @State private var selectedTab = 0
    @State private var collectionPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Collection", systemImage: "shoe.2.fill", value: 0) {
                CollectionView(path: $collectionPath)
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
        .onChange(of: deepLinkShoeId) { _, newValue in
            guard let id = newValue,
                  let shoe = store.footwear.first(where: { $0.id == id }) else { return }
            selectedTab = 0
            collectionPath = NavigationPath()
            collectionPath.append(shoe)
            deepLinkShoeId = nil
        }
    }
}
