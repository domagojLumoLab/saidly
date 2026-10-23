public protocol TokenProvider: Sendable {
    func idToken(forceRefresh: Bool) async throws(AppError) -> String
}

