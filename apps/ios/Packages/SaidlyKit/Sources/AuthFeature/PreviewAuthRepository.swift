import Domain

struct PreviewAuthRepository: AuthRepository {
    let behavior: Behavior

    enum Behavior {
        case succeeds
        case fails(AppError)
        case hangs
    }

    init(behavior: Behavior = .fails(.invalidCredentials)) {
        self.behavior = behavior
    }

    var currentUser: AppUser? { nil }

    func authStateChanges() -> AsyncStream<AppUser?> {
        AsyncStream { $0.finish() }
    }

    func signIn(email: String, password: String) async throws(AppError) {
        switch behavior {
        case .succeeds:
            return
        case .fails(let error):
            throw error
        case .hangs:
            try? await Task.sleep(for: .seconds(3600))
        }
    }

    func signOut() throws(AppError) {}
}
