import Domain

struct FakeTokenProvider: TokenProvider {
    func idToken(forceRefresh: Bool) async throws(Domain.AppError) -> String {
        forceRefresh ? "fresh-token" : "cached-token"
    }
}
