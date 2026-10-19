import Domain

struct FakeAuthRepository: AuthRepository {
    var currentUser: AppUser? { nil }
    
    let signInResult: Result<Void, AppError>
    
    func authStateChanges() -> AsyncStream<AppUser?> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    func signIn(email: String, password: String) async throws(AppError) {
        try signInResult.get()
    }
    
    func signOut() throws(AppError) { }
}

