import SwiftUI

struct SettingsView: View {
    @Environment(HealthKitService.self) private var healthKit
    @Environment(FootwearStore.self) private var store
    @Environment(AuthService.self) private var auth
    @AppStorage("defaultLifespan") private var defaultLifespan: Double = 800
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showResetAlert = false
    @State private var showSignIn = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if auth.isSignedIn {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(auth.displayName ?? auth.email ?? "Signed in")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Synced across devices")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        if store.isSyncing {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Syncing…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let last = store.lastSyncedAt {
                            HStack {
                                Text("Last synced")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(last, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let error = store.syncError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button("Sign Out", role: .destructive) {
                            showSignOutAlert = true
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync your rotation")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Sign in to keep your footwear, sessions, and condition logs across devices.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)

                        Button {
                            showSignIn = true
                        } label: {
                            HStack {
                                Image(systemName: "applelogo")
                                Text("Sign in with Apple")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .disabled(!auth.isAvailable)

                        if !auth.isAvailable {
                            Text("Sync isn't configured for this build.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Account")
                }

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
            .sheet(isPresented: $showSignIn) {
                SignInView()
                    .environment(auth)
            }
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    Task {
                        await store.clearLocalAndRemote()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently removes all footwear, sessions, and condition logs\(auth.isSignedIn ? " from your account on all devices" : "").")
            }
            .alert("Sign Out?", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your data stays on this device. Sign back in to resume sync.")
            }
        }
    }
}
