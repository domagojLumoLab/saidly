import Domain
import FirebaseAuth
import Foundation

public final class FirebaseAuthRepository: AuthRepository {

    public init() {}

    public var currentUser: Domain.AppUser? {
        Auth.auth().currentUser.map { AppUser(firebaseUser: $0) }
    }

    public func authStateChanges() -> AsyncStream<AppUser?> {
        AsyncStream { continuation in
            // handle is an immutable, opaque token used only to remove the listener; Firebase Auth is thread-safe, so sharing it with the @Sendable onTermination is safe.
            nonisolated(unsafe) let handle = Auth.auth().addStateDidChangeListener { _, user in
                continuation.yield(user.map { AppUser(firebaseUser: $0) })
            }
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    public func signIn(email: String, password: String) async throws(AppError) {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw Self.toAppError(error)
        }
    }

    public func signOut() throws(AppError) {
        do {
            try Auth.auth().signOut()
        } catch {
            throw Self.toAppError(error)
        }
    }

    static func toAppError(_ error: Error) -> AppError {
        let errorApp = error as NSError
        guard errorApp.domain == AuthErrorDomain,
            let authError = AuthErrorCode(rawValue: errorApp.code)
        else { return .unknown }
        switch authError {
        case .invalidCredential, .wrongPassword, .userNotFound:
            return .invalidCredentials
        case .invalidEmail:
            return .invalidEmail
        case .networkError:
            return .networkUnavailable
        default:
            return .unknown
        }
    }
}

extension AppUser {
    init(firebaseUser: User) {
        self.init(id: firebaseUser.uid, email: firebaseUser.email)
    }
}
