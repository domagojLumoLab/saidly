public enum AppError: Error, Sendable, Equatable {
    case invalidCredentials
    case invalidEmail
    case networkUnavailable
    case unknown
    case sessionExpired
    case server
    case rateLimited
    case parserFailed

    public var message: String {
        switch self {
        case .invalidCredentials:
            "Incorrect email or password."
        case .invalidEmail:
            "That is not a valid email address."
        case .networkUnavailable:
            "No connection. Check your network."
        case .unknown:
            "Something went wrong. Please try again."
        case .sessionExpired:
            "Your session has expired. Please sign in again."
        case .server:
            "The server is having trouble. Please try again later."
        case .rateLimited:
            "You've planned a lot today. Try again tomorrow."
        case .parserFailed:
            "Couldn't understand that. Try rephrasing."
        }
    }
}
