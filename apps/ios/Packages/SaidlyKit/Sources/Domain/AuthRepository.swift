public protocol AuthRepository: Sendable {
    var currentUser: AppUser? { get }
    func authStateChanges() -> AsyncStream<AppUser?>
    func signIn(email: String, password: String) async throws(AppError)
    func signOut() throws(AppError)
}
