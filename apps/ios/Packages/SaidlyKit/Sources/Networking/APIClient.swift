import Domain
import Foundation

public final class APIClient: Sendable {
    private let baseURL: URL
    private let tokenProvider: any TokenProvider
    private let transport: any HTTPTransport

    public init(baseURL: URL, tokenProvider: any TokenProvider, transport: any HTTPTransport = URLSession.shared) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.transport = transport
    }

    public func get<Response: Decodable>(_ path: String) async throws(AppError) -> Response {
        var (data, response) = try await send(path, forceRefresh: false)

        if response.statusCode == 401 {
            (data, response) = try await send(path, forceRefresh: true)
            if response.statusCode == 401 {
                throw .sessionExpired
            }
        }
        
        switch response.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                throw .server
            }
        case 500..<600:
            throw .server
        default:
            throw .unknown
        }
    }

    private func send(_ path: String, forceRefresh: Bool) async throws(AppError) -> (
        Data, HTTPURLResponse
    ) {
        let token = try await tokenProvider.idToken(forceRefresh: forceRefresh)
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            throw Self.toAppError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw .unknown }

        return (data, http)
    }

    private static func toAppError(_ error: any Error) -> AppError {
        guard let urlError = error as? URLError else { return .unknown }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
            .cannotConnectToHost:
            return .networkUnavailable
        default:
            return .unknown
        }
    }
}
