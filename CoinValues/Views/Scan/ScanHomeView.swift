import SwiftData
import SwiftUI

struct ScanHomeView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("aiConsentGiven") private var aiConsentGiven = false
    @Query(sort: \CoinScan.createdAt, order: .reverse) private var scans: [CoinScan]
    @State private var showScanner = false
    @State private var showPaywall = false
    @State private var showConsent = false
    @State private var demoResult: CoinScan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    tips
                    recentScans
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Coin Values")
            .navigationDestination(for: CoinScan.self) { CoinDetailView(coin: $0) }
            .toolbar {
                if !store.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showPaywall = true } label: {
                            Label("Go Pro", systemImage: "crown.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) { ScanFlowView() }
        .fullScreenCover(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showConsent) {
            AIConsentView {
                aiConsentGiven = true
                showConsent = false
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    showScanner = true
                }
            }
            .presentationDetents([.large])
        }
        #if DEBUG
        .fullScreenCover(item: $demoResult) { coin in
            NavigationStack { CoinDetailView(coin: coin, isNewResult: true) }
        }
        .onAppear {
            switch DemoMode.screen {
            case "scan", "analyzing": showScanner = true
            case "paywall": showPaywall = true
            case "result": demoResult = scans.first { DemoMode.coin.map($0.name.contains) ?? true }
            default: break
            }
        }
        #endif
    }

    private func startScan() {
        if !store.isPro {
            showPaywall = true
        } else if !aiConsentGiven {
            showConsent = true
        } else {
            showScanner = true
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            HStack(spacing: -26) {
                CoinGlyph(symbol: "building.columns", size: 74).rotationEffect(.degrees(-12))
                CoinGlyph(symbol: "dollarsign", size: 96).zIndex(1)
                CoinGlyph(symbol: "star.fill", size: 74).rotationEffect(.degrees(12))
            }
            VStack(spacing: 6) {
                Text("Identify any coin")
                    .font(.title2.weight(.bold))
                Text("Snap the front and back to see the year, mint, rarity and estimated value.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            Button(action: startScan) {
                Label("Scan a Coin", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.primary)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var tips: some View {
        HStack(spacing: 10) {
            TipChip(symbol: "sun.max.fill", text: "Good light")
            TipChip(symbol: "viewfinder", text: "Fill the circle")
            TipChip(symbol: "hand.raised.fill", text: "Hold steady")
        }
    }

    @ViewBuilder private var recentScans: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Scans").font(.title3.weight(.bold))
            if scans.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath").font(.title).foregroundStyle(.secondary)
                    Text("Coins you scan will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(scans.prefix(12)) { scan in
                        NavigationLink(value: scan) {
                            CoinRow(coin: scan).padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)
                        if scan.id != scans.prefix(12).last?.id { Divider().padding(.leading, 80) }
                    }
                }
                .padding(.vertical, 6)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct TipChip: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.gold)
            Text(text).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Asked once before the first scan: photos go to a third-party AI service (guideline 5.1.2(i)).
struct AIConsentView: View {
    let onAgree: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.navy)
                .frame(width: 60, height: 60)
                .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 28)
            Text("How your coin is identified")
                .font(.title.weight(.bold))
            VStack(alignment: .leading, spacing: 16) {
                ConsentPoint(symbol: "photo", text: "The photos you take of your coin are sent to our server and to Anthropic's Claude, a third-party AI service, which identifies the coin and estimates its value.")
                ConsentPoint(symbol: "lock.shield", text: "Photos are used only to identify your coin. We don't store them on our server, sell them, or use them for advertising.")
                ConsentPoint(symbol: "iphone", text: "Your scans and collection are saved only on this iPhone.")
            }
            Button("Read the Privacy Policy") { openURL(Links.privacy) }
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button("Agree and Continue", action: onAgree)
                .buttonStyle(.primary)
            Button("Not Now") { dismiss() }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
    }
}

private struct ConsentPoint: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: 24)
            Text(text).font(.body)
        }
    }
}
