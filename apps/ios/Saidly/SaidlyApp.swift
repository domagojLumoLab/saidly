import Auth
import SwiftUI

@main
struct SaidlyApp: App {
    @State private var dependencies: AppDependencies
    
    init() {
        FirebaseSetup.configure()
        _dependencies = State(initialValue: AppDependencies())
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
