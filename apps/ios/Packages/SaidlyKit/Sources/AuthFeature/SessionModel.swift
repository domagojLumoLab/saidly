import Domain
import Observation

@Observable @MainActor public final class SessionModel {

    public private(set) var state: State = .unknown

    public enum State: Equatable {
        case unknown, signedOut
        case signedIn(AppUser)
    }

    private let authRepository: any AuthRepository

    public init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    public func start() async {
        for await user in authRepository.authStateChanges() {
            state = user.map { .signedIn($0) } ?? .signedOut
        }
    }

    public func signOut() {
        try? authRepository.signOut()
    }
}
