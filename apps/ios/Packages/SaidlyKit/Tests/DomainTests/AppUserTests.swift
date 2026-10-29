import Domain
import Testing

@Suite struct AppUserTests {
    @Test("Users with the same id and email are equal")
    func usersWithSameIdAndEmailAreEqual() {
        let user1 = AppUser(id: "123", email: "test@test.com")
        let user2 = AppUser(id: "123", email: "test@test.com")

        #expect(user1 == user2)
    }

    @Test(
        "Users that differ in any field are not equal",
        arguments: [
            (AppUser(id: "23", email: "test@test.com"), AppUser(id: "123", email: "test@test.com")),
            (AppUser(id: "123", email: "test@test.com"), AppUser(id: "123", email: "a@test.com")),
            (AppUser(id: "123", email: "a@test.com"), AppUser(id: "123", email: nil)),
        ])
    func usersThatDifferInAnyFieldAreNotEqual(lhs: AppUser, rhs: AppUser) {
        #expect(lhs != rhs)
    }
}
