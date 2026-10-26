import StoreKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @AppStorage("aiConsentGiven") private var aiConsentGiven = false
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    @State private var isRestoring = false
    @State private var message: String?
    @State private var confirmClearHistory = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.isPro {
                        HStack(spacing: 14) {
                            CoinGlyph(symbol: "crown.fill", size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Coin Values Pro").font(.headline)
                                Text(store.activeProductID == SubscriptionStore.weeklyID ? "Weekly plan · Active" : "Yearly plan · Active")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        Button("Manage Subscription") { showManageSubscriptions = true }
                    } else {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 14) {
                                CoinGlyph(symbol: "crown.fill", size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro").font(.headline).foregroundStyle(.primary)
                                    Text("Unlimited scans and value estimates").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Button {
                        Task { await restore() }
                    } label: {
                        HStack {
                            Text("Restore Purchases")
                            Spacer()
                            if isRestoring { ProgressView() }
                        }
                    }
                    .disabled(isRestoring)
                } header: {
                    Text("Subscription")
                }

                Section {
                    NavigationLink("How Values Are Estimated") { EstimatesInfoView() }
                    Toggle("Allow AI Identification", isOn: $aiConsentGiven)
                } header: {
                    Text("Values & AI")
                } footer: {
                    Text("Coin photos are sent to Anthropic's Claude AI to identify the coin. Turn this off to be asked again before your next scan.")
                }

                Section {
                    Button("Clear Scan History", role: .destructive) { confirmClearHistory = true }
                } footer: {
                    Text("Removes scans that aren't in your collection. Your collection stays.")
                }

                Section("About") {
                    Button("Rate Coin Values") { openURL(Links.writeReview) }
                    Button("Contact Support") { openURL(Links.support) }
                    Button("Privacy Policy") { openURL(Links.privacy) }
                    Button("Terms of Use") { openURL(Links.terms) }
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
            .fullScreenCover(isPresented: $showPaywall) { PaywallView() }
            .alert("Restore Purchases", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
            .confirmationDialog("Clear scan history?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { clearHistory() }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            message = try await store.restore()
                ? "Your Coin Values Pro subscription is active."
                : "We couldn't find an active Coin Values Pro subscription for this Apple ID."
        } catch {
            message = error.localizedDescription
        }
    }

    private func clearHistory() {
        try? modelContext.delete(model: CoinScan.self, where: #Predicate { !$0.inCollection })
        try? modelContext.save()
    }
}

struct EstimatesInfoView: View {
    var body: some View {
        List {
            Section {
                Text("Coin Values uses Anthropic's Claude AI to recognize your coin from the photos and to estimate a realistic retail value range for a coin in the condition shown.")
                Text("Estimates draw on typical dealer and auction prices. They are a starting point, not a professional appraisal or an offer to buy.")
            }
            Section("What changes a coin's value") {
                InfoRow(symbol: "sparkle.magnifyingglass", title: "Condition", text: "Wear, scratches and cleaning can move a coin's value a lot. Grades from professional services such as PCGS or NGC carry the most weight.")
                InfoRow(symbol: "building.columns", title: "Mint and variety", text: "The same year can be common from one mint and scarce from another. Die varieties and errors can add a premium.")
                InfoRow(symbol: "scalemass", title: "Metal content", text: "Silver and gold coins are rarely worth less than their metal value, which follows the market.")
                InfoRow(symbol: "chart.line.uptrend.xyaxis", title: "Demand", text: "Prices change with collector demand, so two sales of the same coin can differ.")
            }
            Section {
                Text("For coins that may be valuable, have them authenticated and graded before buying or selling.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("How Values Are Estimated")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InfoRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).foregroundStyle(Theme.gold).frame(width: 24).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
