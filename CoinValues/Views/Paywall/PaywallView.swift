import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedID = SubscriptionStore.yearlyID
    @State private var isPurchasing = false
    @State private var alert: AlertContent?

    private struct AlertContent: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        var dismissesPaywall = false
    }

    private var selected: Product? { store.products.first { $0.id == selectedID } }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.heroGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    header
                    features
                    plans
                    purchaseSection
                    legal
                }
                .padding(.horizontal, 22)
                .padding(.top, 56)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .disabled(isPurchasing)
        .task { if store.products.isEmpty { await store.loadProducts() } }
        .alert(item: $alert) { content in
            Alert(title: Text(content.title), message: Text(content.message), dismissButton: .default(Text("OK")) {
                if content.dismissesPaywall { dismiss() }
            })
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            CoinGlyph(symbol: "crown.fill", size: 96)
            Text("Coin Values Pro")
                .font(.largeTitle.weight(.bold))
            Text("Identify coins and track what your collection is worth.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(symbol: "camera.viewfinder", text: "Unlimited coin scans, front and back")
            FeatureRow(symbol: "calendar", text: "Year, mint mark, series and metal")
            FeatureRow(symbol: "sparkles", text: "Rarity and estimated value range")
            FeatureRow(symbol: "square.stack.3d.up.fill", text: "Collection with total estimated value")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder private var plans: some View {
        if store.products.isEmpty {
            VStack(spacing: 12) {
                if let error = store.productsError, !store.isLoadingProducts {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                    Button("Try Again") { Task { await store.loadProducts() } }
                        .font(.headline)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150)
        } else {
            VStack(spacing: 12) {
                if let yearly = store.yearly {
                    PlanCard(
                        title: "Yearly",
                        detail: store.hasFreeTrial(yearly) ? "\(yearly.subscription?.introductoryOffer?.period.adjectiveText ?? "3-day") free trial" : nil,
                        price: yearly.displayPrice,
                        period: "per year",
                        footnote: weeklyEquivalent(of: yearly).map { "Just \($0)/week" },
                        badge: savingsBadge,
                        isSelected: selectedID == yearly.id
                    ) { selectedID = yearly.id }
                }
                if let weekly = store.weekly {
                    PlanCard(
                        title: "Weekly",
                        detail: nil,
                        price: weekly.displayPrice,
                        period: "per week",
                        footnote: nil,
                        badge: nil,
                        isSelected: selectedID == weekly.id
                    ) { selectedID = weekly.id }
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchase() }
            } label: {
                ZStack {
                    Text(ctaTitle).opacity(isPurchasing ? 0 : 1)
                    if isPurchasing { ProgressView().tint(Theme.navy) }
                }
            }
            .buttonStyle(.primary)
            .disabled(selected == nil)

            Text(priceSummary)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    private var legal: some View {
        VStack(spacing: 14) {
            Text(renewalTerms)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Restore Purchases") { Task { await restore() } }
                Button("Terms of Use") { openURL(Links.terms) }
                Button("Privacy Policy") { openURL(Links.privacy) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Copy

    private var ctaTitle: String {
        guard let selected else { return "Continue" }
        if store.hasFreeTrial(selected), let period = selected.subscription?.introductoryOffer?.period {
            return "Start \(period.adjectiveText.capitalized) Free Trial"
        }
        return "Subscribe for \(selected.displayPrice)/\(selected.periodText)"
    }

    private var priceSummary: String {
        guard let selected else { return " " }
        if store.hasFreeTrial(selected), let period = selected.subscription?.introductoryOffer?.period {
            return "\(period.durationText) free, then \(selected.displayPrice) per \(selected.periodText). Cancel anytime."
        }
        return "\(selected.displayPrice) per \(selected.periodText). Cancel anytime."
    }

    private var renewalTerms: String {
        var text = "Coin Values Pro is an auto-renewing subscription. "
        if let selected, store.hasFreeTrial(selected) {
            text += "After the free trial, your Apple ID account is charged \(selected.displayPrice) per \(selected.periodText) unless you cancel before the trial ends. "
        } else {
            text += "Payment is charged to your Apple ID account at confirmation of purchase. "
        }
        text += "The subscription renews automatically unless cancelled at least 24 hours before the end of the current period, and your account is charged for renewal within 24 hours before the period ends. Manage or cancel anytime in your App Store account settings."
        return text
    }

    private func weeklyEquivalent(of yearly: Product) -> String? {
        (yearly.price / Decimal(52)).formatted(yearly.priceFormatStyle)
    }

    private var savingsBadge: String? {
        guard let yearly = store.yearly, let weekly = store.weekly, weekly.price > 0 else { return "BEST VALUE" }
        let yearlyCost = (yearly.price as NSDecimalNumber).doubleValue
        let weeklyCost = (weekly.price as NSDecimalNumber).doubleValue * 52
        let savings = Int(((1 - yearlyCost / weeklyCost) * 100).rounded(.down))
        return savings >= 10 ? "SAVE \(savings)%" : "BEST VALUE"
    }

    // MARK: - Actions

    private func purchase() async {
        guard let selected else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await store.purchase(selected) {
            case .purchased: dismiss()
            case .pending: alert = AlertContent(title: "Purchase Pending", message: "Your purchase is waiting for approval. Coin Values Pro unlocks as soon as it's approved.", dismissesPaywall: true)
            case .cancelled: break
            }
        } catch {
            alert = AlertContent(title: "Purchase Failed", message: error.localizedDescription)
        }
    }

    private func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await store.restore() {
                alert = AlertContent(title: "Purchases Restored", message: "Coin Values Pro is active again.", dismissesPaywall: true)
            } else {
                alert = AlertContent(title: "Nothing to Restore", message: "We couldn't find an active Coin Values Pro subscription for this Apple ID.")
            }
        } catch {
            alert = AlertContent(title: "Restore Failed", message: error.localizedDescription)
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.navy)
                .frame(width: 30, height: 30)
                .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(text)
                .font(.subheadline.weight(.medium))
        }
    }
}

private struct PlanCard: View {
    let title: String
    let detail: String?
    let price: String
    let period: String
    let footnote: String?
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.gold : .white.opacity(0.4))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    if let detail {
                        Text(detail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.goldLight)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                    if let footnote {
                        Text(footnote)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.white.opacity(isSelected ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.gold : .white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.goldGradient, in: Capsule())
                        .foregroundStyle(Theme.navy)
                        .offset(x: -12, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
