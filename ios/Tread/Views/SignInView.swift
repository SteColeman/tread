import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Image(systemName: "shoe.2.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)

                    Text("Sync your rotation")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Sign in to keep your footwear, condition logs, and wear history across devices.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            auth.handleAppleRequest(request)
                        },
                        onCompletion: { result in
                            Task {
                                await auth.handleAppleCompletion(result)
                                if auth.isSignedIn { dismiss() }
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .clipShape(.rect(cornerRadius: 12))

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("Your data stays private to your account.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
