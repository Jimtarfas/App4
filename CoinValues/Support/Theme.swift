import SwiftUI

enum Theme {
    static let gold = Color("AccentColor")
    static let goldLight = Color(red: 0.98, green: 0.86, blue: 0.52)
    static let goldDark = Color(red: 0.62, green: 0.43, blue: 0.10)
    static let navy = Color(red: 0.06, green: 0.09, blue: 0.16)
    static let navyLight = Color(red: 0.12, green: 0.17, blue: 0.28)

    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, goldDark],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let heroGradient = LinearGradient(
        colors: [navyLight, navy],
        startPoint: .top, endPoint: .bottom
    )
}

enum Links {
    static let privacy = URL(string: "https://jimtarfas.github.io/coin-values-site/privacy.html")!
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let support = URL(string: "https://jimtarfas.github.io/coin-values-site/support.html")!
    static let api = URL(string: "https://coin-values-api.vercel.app/api/identify")!
    static let writeReview = URL(string: "https://apps.apple.com/app/id6826951196?action=write-review")!
}

extension Double {
    /// Formats a US dollar amount as "$12" or "$4.50". Estimates are always in US dollars,
    /// so the US format is used everywhere instead of the region's "US$".
    var usd: String {
        formatted(.currency(code: "USD")
            .locale(Locale(identifier: "en_US"))
            .precision(.fractionLength(self < 100 && self.rounded() != self ? 2 : 0)))
    }
}

/// "$12 – $40", or a single figure when the range collapses.
func valueRange(_ low: Double, _ high: Double) -> String {
    if abs(high - low) < 0.005 { return low.usd }
    return "\(low.usd) – \(high.usd)"
}
