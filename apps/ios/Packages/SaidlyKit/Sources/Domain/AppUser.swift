import Foundation

public struct AppUser: Sendable, Equatable, Identifiable {
    public let id: String
    public let email: String?
    
    public init(id: String, email: String?) {
        self.id = id
        self.email = email
    }
}
