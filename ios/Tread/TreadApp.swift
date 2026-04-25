import SwiftUI

@main
struct TreadApp: App {
    @State private var store = FootwearStore()
    @State private var healthKit = HealthKitService()
    @State private var auth = AuthService()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .environment(store)
                        .environment(healthKit)
                        .environment(auth)
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            }
            .task {
                store.load()
                await auth.bootstrap()
                if let userId = auth.userId {
                    await store.attach(userId: userId)
                }
            }
            .onChange(of: auth.userId) { _, newValue in
                Task {
                    await store.attach(userId: newValue)
                }
            }
        }
    }
}
