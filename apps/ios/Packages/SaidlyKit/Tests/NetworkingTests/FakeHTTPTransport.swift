import Foundation
import Networking

actor FakeHTTPTransport: HTTPTransport {
    private var responses: [Result<(Data, URLResponse), URLError>]
    private(set) var requests: [URLRequest] = []

    init(responses: [Result<(Data, URLResponse), URLError>]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let next = responses.removeFirst()
        return try next.get()
    }

    static func response(status: Int, body: String = "") -> Result<(Data, URLResponse), URLError> {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: status,
            httpVersion: nil, headerFields: nil)!
        return .success((Data(body.utf8), response))
    }
}
