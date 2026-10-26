import Foundation
import StoreKit

/// StoreKit 2 subscription state: products, purchases, restore and the active entitlement.
@MainActor
@Observable
final class SubscriptionStore {
    static let weeklyID = "com.coinvalues.identifier.weekly"
    static let yearlyID = "com.coinvalues.identifier.yearly"
    static let productIDs = [yearlyID, weeklyID]

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var activeProductID: String?
    /// Signed transaction for the active subscription; the server verifies it before each scan.
    private(set) var activeTransactionJWS: String?
    private(set) var isLoadingProducts = false
    private(set) var productsError: String?
    private(set) var trialEligible: [String: Bool] = [:]

    private var updatesTask: Task<Void, Never>?
    #if DEBUG
    /// Posted by the StoreKit tests after they switch to the local StoreKit configuration.
    static let reloadForTestingNotification = Notification.Name("SubscriptionStore.reloadForTesting")
    private var reloadObserver: NSObjectProtocol?
    #endif

    init() {
        #if DEBUG
        reloadObserver = NotificationCenter.default.addObserver(forName: Self.reloadForTestingNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshEntitlements()
                await self?.loadProducts()
            }
        }
        #endif
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    var yearly: Product? { products.first { $0.id == Self.yearlyID } }
    var weekly: Product? { products.first { $0.id == Self.weeklyID } }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        productsError = nil
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { Self.productIDs.firstIndex(of: $0.id)! < Self.productIDs.firstIndex(of: $1.id)! }
            for product in products {
                trialEligible[product.id] = await product.subscription?.isEligibleForIntroOffer ?? false
            }
            if products.isEmpty { productsError = "Subscriptions are unavailable right now. Please try again later." }
        } catch {
            productsError = "Couldn't load subscription options. Check your connection and try again."
        }
    }

    /// True when the product has a free trial this customer can still use.
    func hasFreeTrial(_ product: Product) -> Bool {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return false }
        return trialEligible[product.id] ?? false
    }

    enum PurchaseOutcome: Equatable { case purchased, pending, cancelled }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw StoreError.failedVerification }
            await transaction.finish()
            await refreshEntitlements()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Syncs with the App Store and reports whether an active subscription was found.
    func restore() async throws -> Bool {
        try await AppStore.sync()
        await refreshEntitlements()
        return isPro
    }

    func refreshEntitlements() async {
        var foundJWS: String?
        var foundProduct: String?
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expires = transaction.expirationDate, expires < Date() { continue }
            foundJWS = entitlement.jwsRepresentation
            foundProduct = transaction.productID
        }
        #if DEBUG
        if DemoMode.isEnabled {
            isPro = true
            activeProductID = Self.yearlyID
            return
        }
        #endif
        isPro = foundJWS != nil
        activeTransactionJWS = foundJWS
        activeProductID = foundProduct
    }

    enum StoreError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "The App Store couldn't verify this purchase." }
    }
}

extension Product {
    /// "week", "year", "3 days", for price labels.
    var periodText: String {
        guard let period = subscription?.subscriptionPeriod else { return "" }
        return period.text
    }
}

extension Product.SubscriptionPeriod {
    var text: String {
        let unitName: String
        switch unit {
        case .day: unitName = value == 1 ? "day" : "days"
        case .week: unitName = value == 1 ? "week" : "weeks"
        case .month: unitName = value == 1 ? "month" : "months"
        case .year: unitName = value == 1 ? "year" : "years"
        @unknown default: unitName = ""
        }
        return value == 1 ? unitName : "\(value) \(unitName)"
    }

    /// "3 days", "1 week", for "3 days free".
    var durationText: String { value == 1 ? "1 \(text)" : text }

    /// "3-day", "1-week", for "3-day free trial".
    var adjectiveText: String {
        let unitName: String
        switch unit {
        case .day: unitName = "day"
        case .week: unitName = "week"
        case .month: unitName = "month"
        case .year: unitName = "year"
        @unknown default: unitName = ""
        }
        return "\(value)-\(unitName)"
    }
}
