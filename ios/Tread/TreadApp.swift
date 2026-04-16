import SwiftUI

@main
struct TreadApp: App {
    @State private var store = FootwearStore()
    @State private var healthKit = HealthKitService()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environment(store)
                    .environment(healthKit)
                    .task {
                        store.load()
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }
}
