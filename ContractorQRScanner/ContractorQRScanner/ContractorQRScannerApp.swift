import SwiftUI

@main
struct ContractorQRScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ScannerView()
                .preferredColorScheme(.dark)
        }
    }
}
