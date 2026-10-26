import StoreKit
import StoreKitTest
import XCTest
@testable import CoinValues

/// Runs inside the app with the local StoreKit configuration, so the paywall shows real
/// product data and the purchase flow can be exercised without App Store Connect.
@MainActor
final class StoreKitFlowTests: XCTestCase {
    func testProductsTrialAndPurchase() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
        NotificationCenter.default.post(name: SubscriptionStore.reloadForTestingNotification, object: nil)

        let products = try await Product.products(for: SubscriptionStore.productIDs)
        XCTAssertEqual(Set(products.map(\.id)), Set(SubscriptionStore.productIDs))
        let yearly = try XCTUnwrap(products.first { $0.id == SubscriptionStore.yearlyID })
        let weekly = try XCTUnwrap(products.first { $0.id == SubscriptionStore.weeklyID })
        XCTAssertEqual(yearly.subscription?.subscriptionPeriod.unit, .year)
        XCTAssertEqual(weekly.subscription?.subscriptionPeriod.unit, .week)
        let trial = try XCTUnwrap(yearly.subscription?.introductoryOffer)
        XCTAssertEqual(trial.paymentMode, .freeTrial)
        XCTAssertEqual(trial.period.value, 3)
        XCTAssertEqual(trial.period.unit, .day)
        let eligible = await yearly.subscription?.isEligibleForIntroOffer
        XCTAssertEqual(eligible, true)

        // Leave the paywall on screen for a while so it can be captured.
        if let hold = ProcessInfo.processInfo.environment["HOLD_SECONDS"].flatMap(Double.init) {
            try await Task.sleep(for: .seconds(hold))
        }

        let store = SubscriptionStore()
        try await Task.sleep(for: .seconds(1))
        let outcome = try await store.purchase(yearly)
        XCTAssertEqual(outcome, .purchased)
        await store.refreshEntitlements()
        XCTAssertNotNil(store.activeTransactionJWS)
        XCTAssertEqual(store.activeProductID, SubscriptionStore.yearlyID)

        // Optionally keep the subscribed app running so the scan flow can be tried by hand.
        if let hold = ProcessInfo.processInfo.environment["HOLD_AFTER_PURCHASE_SECONDS"].flatMap(Double.init) {
            try await Task.sleep(for: .seconds(hold))
        }
    }
}
