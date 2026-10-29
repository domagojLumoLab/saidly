import Domain
import FirebaseAuth
import Foundation
import Testing

@testable import Auth

@Suite struct FirebaseAuthRepositoryTests {

    @Test(arguments: [
        (AuthErrorCode.wrongPassword.rawValue, AppError.invalidCredentials),
        (AuthErrorCode.userNotFound.rawValue, AppError.invalidCredentials),
        (AuthErrorCode.invalidCredential.rawValue, AppError.invalidCredentials),
        (AuthErrorCode.invalidEmail.rawValue, AppError.invalidEmail),
        (AuthErrorCode.networkError.rawValue, AppError.networkUnavailable),
        (AuthErrorCode.userDisabled.rawValue, AppError.sessionExpired),
        (AuthErrorCode.userTokenExpired.rawValue, AppError.sessionExpired),
        (AuthErrorCode.invalidUserToken.rawValue, AppError.sessionExpired),
        (AuthErrorCode.requiresRecentLogin.rawValue, AppError.sessionExpired),
        (AuthErrorCode.tooManyRequests.rawValue, AppError.unknown),
    ])
    func firebaseErrorMapsToAppError(code: Int, expected: AppError) {
        let error = NSError(domain: AuthErrorDomain, code: code)
        #expect(FirebaseAuthRepository.toAppError(error) == expected)
    }

    @Test func nonFirebaseErrorReturnsUnknown() {
        let error = NSError(
            domain: "SomeOtherDomain",
            code: AuthErrorCode.invalidEmail.rawValue
        )
        #expect(FirebaseAuthRepository.toAppError(error) == .unknown)
    }
}
