import AuthFeature
import Domain
import Testing

@MainActor @Suite struct SessionModelTests {
    let fake = StreamingFakeAuthRepository()
    let appUser = AppUser(id: "12b", email: "test@test.com")

    private func makeSessionModel() -> SessionModel {
        SessionModel(authRepository: fake)
    }

    @Test func initialStateIsUnknown() {
        let sessionModel = makeSessionModel()
        #expect(sessionModel.state == .unknown)
    }

    @Test func userSignedInSetsSignedInState() async {
        let sessionModel = makeSessionModel()

        fake.continuation.yield(appUser)
        fake.continuation.finish()

        await sessionModel.start()

        #expect(sessionModel.state == .signedIn(appUser))
    }

    @Test func signInThenSignOutSetsSignedOutState() async {
        let sessionModel = makeSessionModel()

        fake.continuation.yield(appUser)
        fake.continuation.yield(nil)
        fake.continuation.finish()

        await sessionModel.start()

        #expect(sessionModel.state == .signedOut)
    }
}
