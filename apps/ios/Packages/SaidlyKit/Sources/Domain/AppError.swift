public enum AppError: Error, Sendable, Equatable {
    case invalidCredentials
    case invalidEmail
    case networkUnavailable
    case unknown
    
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
        }
    }
}
