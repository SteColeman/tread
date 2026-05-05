import SwiftUI

struct NotificationsSettingsView: View {
    @State private var notifications = NotificationService.shared
    @State private var primingShown = false

    var body: some View {
        Form {
            if !notifications.hasRequested {
                Section {
                    primingCard
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            } else if !notifications.isAuthorized {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundStyle(.orange)
                            Text("Notifications are off")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("Enable Tread notifications in iOS Settings to receive replacement alerts and weekly summaries.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open System Settings")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
            }

            Section {
                Toggle("Enable Notifications", isOn: bind(\.masterEnabled))
                    .disabled(!notifications.isAuthorized)
            } footer: {
                Text("Master switch for all Tread alerts.")
            }

            Section("Alerts") {
                Toggle(isOn: bind(\.lifeWarningEnabled)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replacement warning")
                        Text("Heads-up when a pair reaches 80% of its goal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: bind(\.weeklySummaryEnabled)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly wear summary")
                        Text("Sundays at 7pm — your shoes' week in review.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: bind(\.monthlyCheckInEnabled)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly condition check-in")
                        Text("Gentle reminder to log how your active pair feels.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!notifications.isAuthorized || !notifications.masterEnabled)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notifications.bootstrap()
        }
    }

    private var primingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 38, height: 38)
                    Image(systemName: "bell.badge")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text("Stay ahead of wear")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                primingRow(icon: "exclamationmark.triangle", title: "Replacement warnings", body: "We'll let you know when a pair hits 80% so you can start looking.")
                primingRow(icon: "calendar", title: "Weekly summaries", body: "A short Sunday recap of how each pair did this week.")
                primingRow(icon: "heart.text.clipboard", title: "Condition check-ins", body: "A monthly nudge to log how your active pair feels.")
            }

            Button {
                Task {
                    _ = await notifications.requestAuthorization()
                }
            } label: {
                Text("Allow Notifications")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary)
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Text("Tread never sends spam or marketing alerts.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func primingRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<NotificationService, Bool>) -> Binding<Bool> {
        Binding(
            get: { notifications[keyPath: keyPath] },
            set: { notifications[keyPath: keyPath] = $0 }
        )
    }
}
