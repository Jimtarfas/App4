import SwiftData
import SwiftUI

@main
struct CoinValuesApp: App {
    @State private var store = SubscriptionStore()
    private let container: ModelContainer

    init() {
        #if DEBUG
        if DemoMode.isEnabled {
            container = DemoMode.makeContainer()
            return
        }
        #endif
        container = try! ModelContainer(for: CoinScan.self)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.gold)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(SubscriptionStore.self) private var store
    @State private var showPaywall = false

    var body: some View {
        Group {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingView {
                    hasOnboarded = true
                    if !store.isPro { showPaywall = true }
                }
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        #if DEBUG
        .onAppear { if DemoMode.isEnabled { hasOnboarded = DemoMode.screen != "onboarding" } }
        #endif
    }
}

struct MainTabView: View {
    enum Tab { case scan, collection, settings }
    @State private var tab: Tab = .scan

    var body: some View {
        TabView(selection: $tab) {
            ScanHomeView()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
                .tag(Tab.scan)
            CollectionView()
                .tabItem { Label("Collection", systemImage: "square.stack.3d.up.fill") }
                .tag(Tab.collection)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        #if DEBUG
        .onAppear {
            switch DemoMode.screen {
            case "collection": tab = .collection
            case "settings": tab = .settings
            default: break
            }
        }
        #endif
    }
}
