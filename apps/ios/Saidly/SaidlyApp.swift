import Auth
import SwiftUI

@main
struct SaidlyApp: App {
    init() {
        FirebaseSetup.configure()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
