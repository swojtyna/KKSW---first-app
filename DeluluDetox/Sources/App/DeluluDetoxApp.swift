import SwiftUI

@main
struct DeluluDetoxApp: App {
    private let container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView(model: container.makeAppRootViewModel())
        }
    }
}
