import SwiftUI

struct SettingsView: View {
    @Environment(HealthKitService.self) private var healthKit
    @Environment(FootwearStore.self) private var store
    @AppStorage("defaultLifespan") private var defaultLifespan: Double = 800
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Health") {
                    HStack {
                        Label("HealthKit", systemImage: "heart.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        if healthKit.isAuthorized {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                Text("Connected")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.green)
                        } else {
                            Button("Connect") {
                                Task { await healthKit.requestAuthorization() }
                            }
                            .font(.subheadline)
                        }
                    }

                    if let error = healthKit.authorizationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if !healthKit.isAvailable {
                        Label("HealthKit is not available on this device.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Defaults") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("New Pair Lifespan")
                            Spacer()
                            Text("\(Int(defaultLifespan)) km")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $defaultLifespan, in: 200...2000, step: 50)
                    }
                }

                Section("Your Data") {
                    HStack {
                        Label("Footwear", systemImage: "shoe.2.fill")
                        Spacer()
                        Text("\(store.footwear.count) pairs")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Wear Sessions", systemImage: "figure.walk")
                        Spacer()
                        Text("\(store.sessions.count) days")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Condition Logs", systemImage: "heart.text.clipboard")
                        Spacer()
                        Text("\(store.conditionLogs.count) entries")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Reset All Data", role: .destructive) {
                        showResetAlert = true
                    }
                }

                Section {
                    VStack(alignment: .center, spacing: 6) {
                        Text("Tread")
                            .font(.headline)
                        Text("Footwear lifecycle intelligence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("v1.0")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    store.footwear = []
                    store.sessions = []
                    store.conditionLogs = []
                    PersistenceService.shared.saveFootwear([])
                    PersistenceService.shared.saveSessions([])
                    PersistenceService.shared.saveConditionLogs([])
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently removes all footwear, sessions, and condition logs.")
            }
        }
    }
}
