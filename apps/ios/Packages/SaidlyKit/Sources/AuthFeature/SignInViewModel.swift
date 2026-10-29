import Domain
import Observation

@Observable @MainActor public final class SignInViewModel {

    public enum State: Equatable {
        case idle, signingIn
        case failed(AppError)
    }

    public var email: String = ""
    public var password: String = ""

    public var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && state != .signingIn
    }

    public private(set) var state: State = .idle

    private let authRepository: any AuthRepository

    public init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    public func signIn() async {
        guard canSubmit else { return }
        state = .signingIn
        do {
            try await authRepository.signIn(email: email, password: password)
            state = .idle
        } catch {
            state = .failed(error)
        }
    }
}
