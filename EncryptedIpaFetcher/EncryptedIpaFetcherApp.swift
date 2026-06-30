import SwiftUI

@main
struct EncryptedIpaFetcherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: .init(service: IPAToolStyleService()))
        }
    }
}
