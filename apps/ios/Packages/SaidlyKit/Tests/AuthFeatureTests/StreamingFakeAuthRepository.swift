import Domain

struct StreamingFakeAuthRepository: AuthRepository {
    let stream: AsyncStream<AppUser?>
    let continuation: AsyncStream<AppUser?>.Continuation
    
    init() {
        (stream, continuation) = AsyncStream.makeStream(of: AppUser?.self)
    }
    
    var currentUser: AppUser? { nil }
    
    func authStateChanges() -> AsyncStream<AppUser?> {
        stream
    }
    
    func signIn(email: String, password: String) async throws(AppError) { }
    
    func signOut() throws(AppError) { }
}
