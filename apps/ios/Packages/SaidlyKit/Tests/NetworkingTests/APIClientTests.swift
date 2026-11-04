import Domain
import Foundation
import Networking
import Testing

struct TestResponse: Decodable, Equatable {
    let userId: String
}

@Suite struct APIClientTests {

    private func makeClient(
        responses: [Result<(Data, URLResponse), URLError>]
    ) -> (APIClient, FakeHTTPTransport) {
        let transport = FakeHTTPTransport(responses: responses)
        let client = APIClient(
            baseURL: URL(string: "https://example.com")!,
            tokenProvider: FakeTokenProvider(),
            transport: transport
        )
        return (client, transport)
    }

    @Test("Sends the cached token as a bearer header")
    func sendsBearerToken() async throws {
        let (client, transport) = makeClient(responses: [
            FakeHTTPTransport.response(status: 200, body: #"{"userId":"abc"}"#)
        ])

        let _: TestResponse = try await client.get("/me")

        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer cached-token")
    }

    @Test("Decodes a successful response")
    func decodesResponse() async throws {
        let (client, _) = makeClient(responses: [
            FakeHTTPTransport.response(status: 200, body: #"{"userId":"abc"}"#)
        ])

        let result: TestResponse = try await client.get("/me")

        #expect(result == TestResponse(userId: "abc"))
    }

    @Test("Retries once with a fresh token after 401")
    func retriesWithFreshTokenAfter401() async throws {
        let (client, transport) = makeClient(responses: [
            FakeHTTPTransport.response(status: 401),
            FakeHTTPTransport.response(status: 200, body: #"{"userId":"abc"}"#),
        ])

        let result: TestResponse = try await client.get("/me")

        let requests = await transport.requests
        #expect(requests.count == 2)
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer fresh-token")
        #expect(result == TestResponse(userId: "abc"))
    }

    @Test("Throws sessionExpired when the retry is also 401")
    func throwsSessionExpiredAfterTwo401s() async {
        let (client, _) = makeClient(responses: [
            FakeHTTPTransport.response(status: 401),
            FakeHTTPTransport.response(status: 401),
        ])

        await #expect(throws: AppError.sessionExpired) {
            let _: TestResponse = try await client.get("/me")
        }
    }

    @Test("Maps a missing connection to networkUnavailable")
    func throwsNetworkUnavailableWhenOffline() async {
        let (client, _) = makeClient(responses: [
            .failure(URLError(.notConnectedToInternet))
        ])

        await #expect(throws: AppError.networkUnavailable) {
            let _: TestResponse = try await client.get("/me")
        }
    }

    @Test("Maps a 5xx status to server")
    func throwsServerOn500() async {
        let (client, _) = makeClient(responses: [
            FakeHTTPTransport.response(status: 500)
        ])

        await #expect(throws: AppError.server) {
            let _: TestResponse = try await client.get("/me")
        }
    }

    @Test("Maps an undecodable body to server")
    func throwsServerOnInvalidJSON() async {
        let (client, _) = makeClient(responses: [
            FakeHTTPTransport.response(status: 200, body: "not json")
        ])

        await #expect(throws: AppError.server) {
            let _: TestResponse = try await client.get("/me")
        }
    }
}
