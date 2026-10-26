#if DEBUG
import SwiftData
import UIKit

/// Simulator demo data for App Store screenshots. Debug builds only.
/// Enabled by the DEMO_DIR launch environment variable, a folder on the Mac with demo.json and the coin photos.
/// DEMO_SCREEN picks the screen to open: onboarding, collection, settings, scan, analyzing, result, paywall.
/// Example: SIMCTL_CHILD_DEMO_DIR=marketing/demo SIMCTL_CHILD_DEMO_SCREEN=result xcrun simctl launch booted com.coinvalues.identifier
enum DemoMode {
    static var directory: URL? { ProcessInfo.processInfo.environment["DEMO_DIR"].map { URL(fileURLWithPath: $0) } }
    static var isEnabled: Bool { directory != nil }
    static var screen: String? { ProcessInfo.processInfo.environment["DEMO_SCREEN"] }
    /// Part of the coin name to open on the result screen; the newest scan when unset.
    static var coin: String? { ProcessInfo.processInfo.environment["DEMO_COIN"] }
    static var scrollToDetails: Bool { ProcessInfo.processInfo.environment["DEMO_SCROLL"] == "details" }

    private struct Entry: Decodable {
        let front: String
        let back: String?
        let inCollection: Bool
        let hoursAgo: Double
        let result: CoinIdentification
    }

    static func image(named name: String) -> UIImage? {
        directory.flatMap { UIImage(contentsOfFile: $0.appending(path: name).path) }
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let container = try! ModelContainer(for: CoinScan.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        guard let directory,
              let data = try? Data(contentsOf: directory.appending(path: "demo.json")),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return container }
        for entry in entries {
            let scan = CoinScan(
                identification: entry.result,
                frontImage: try? Data(contentsOf: directory.appending(path: entry.front)),
                backImage: entry.back.flatMap { try? Data(contentsOf: directory.appending(path: $0)) }
            )
            scan.createdAt = Date().addingTimeInterval(-entry.hoursAgo * 3600)
            if entry.inCollection {
                scan.inCollection = true
                scan.addedToCollectionAt = scan.createdAt
            }
            container.mainContext.insert(scan)
        }
        try? container.mainContext.save()
        return container
    }
}
#endif
