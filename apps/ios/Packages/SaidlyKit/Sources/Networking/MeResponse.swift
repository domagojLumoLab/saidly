import Domain

public struct MeResponse: Decodable, Sendable {
    public let userId: String
}

extension APIClient {
    public func me() async throws(AppError) -> MeResponse {
        try await get("/me")
    }
}
