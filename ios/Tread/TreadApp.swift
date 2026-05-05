import SwiftUI

@main
struct TreadApp: App {
    @State private var store = FootwearStore()
    @State private var healthKit = HealthKitService()
    @State private var auth = AuthService()
    @State private var deepLinkShoeId: UUID?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView(deepLinkShoeId: $deepLinkShoeId)
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
                await NotificationService.shared.bootstrap()
                if let userId = auth.userId {
                    await store.attach(userId: userId)
                }
            }
            .onChange(of: auth.userId) { _, newValue in
                Task {
                    await store.attach(userId: newValue)
                }
            }
            .onOpenURL { url in
                guard url.scheme == "tread", url.host == "shoe" else { return }
                let idString = url.lastPathComponent
                if let uuid = UUID(uuidString: idString) {
                    deepLinkShoeId = uuid
                }
            }
        }
    }
}
