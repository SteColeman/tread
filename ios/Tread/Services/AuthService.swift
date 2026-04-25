import Foundation
import AuthenticationServices
import CryptoKit
import Supabase

@Observable
@MainActor
final class AuthService: NSObject {
    var userId: UUID?
    var email: String?
    var displayName: String?
    var isLoading: Bool = false
    var errorMessage: String?

    private var currentNonce: String?

    var isSignedIn: Bool { userId != nil }
    var isAvailable: Bool { SupabaseClientProvider.shared != nil }

    func bootstrap() async {
        guard let client = SupabaseClientProvider.shared else { return }
        do {
            let session = try await client.auth.session
            apply(session: session)
        } catch {
            userId = nil
        }
    }

    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        guard let client = SupabaseClientProvider.shared else {
            errorMessage = "Sync isn't configured for this build."
            return
        }
        isLoading = true
        defer { isLoading = false }

        switch result {
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = error.localizedDescription
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let identityTokenData = credential.identityToken,
                let idToken = String(data: identityTokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Couldn't read Apple credential."
                return
            }

            let providedName: String? = {
                guard let name = credential.fullName else { return nil }
                let formatter = PersonNameComponentsFormatter()
                let formatted = formatter.string(from: name).trimmingCharacters(in: .whitespaces)
                return formatted.isEmpty ? nil : formatted
            }()

            do {
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )
                apply(session: session, fallbackName: providedName)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() async {
        guard let client = SupabaseClientProvider.shared else { return }
        try? await client.auth.signOut()
        userId = nil
        email = nil
        displayName = nil
    }

    private func apply(session: Session, fallbackName: String? = nil) {
        userId = session.user.id
        email = session.user.email
        if let meta = session.user.userMetadata["full_name"]?.stringValue, !meta.isEmpty {
            displayName = meta
        } else if let fallbackName, !fallbackName.isEmpty {
            displayName = fallbackName
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { continue }
            if random < charset.count {
                result.append(charset[Int(random) % charset.count])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
