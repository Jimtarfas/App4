import SwiftData
import SwiftUI

struct CollectionView: View {
    enum SortOrder: String, CaseIterable, Identifiable {
        case recent = "Recently Added"
        case value = "Highest Value"
        case year = "Oldest First"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CoinScan> { $0.inCollection }) private var coins: [CoinScan]
    @AppStorage("collectionSort") private var sort: SortOrder = .recent

    private var sortedCoins: [CoinScan] {
        switch sort {
        case .recent: coins.sorted { ($0.addedToCollectionAt ?? $0.createdAt) > ($1.addedToCollectionAt ?? $1.createdAt) }
        case .value: coins.sorted { $0.valueMidpoint > $1.valueMidpoint }
        case .year: coins.sorted { (Int($0.year.prefix(4)) ?? .max) < (Int($1.year.prefix(4)) ?? .max) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TotalValueCard(coins: coins)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if coins.isEmpty {
                    Section {
                        emptyState
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(sortedCoins) { coin in
                            NavigationLink(value: coin) { CoinRow(coin: coin) }
                                .swipeActions {
                                    Button("Remove") {
                                        withAnimation { coin.setInCollection(false) }
                                        try? modelContext.save()
                                    }
                                    .tint(.red)
                                }
                        }
                    } header: {
                        Text("\(coins.count) \(coins.count == 1 ? "coin" : "coins")")
                    } footer: {
                        EstimateDisclaimer().padding(.top, 8)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Collection")
            .navigationDestination(for: CoinScan.self) { CoinDetailView(coin: $0) }
            .toolbar {
                if !coins.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort", selection: $sort) {
                                ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                        }
                        .accessibilityLabel("Sort")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            CoinGlyph(symbol: "plus", size: 80)
            Text("Your collection is empty")
                .font(.headline)
            Text("Scan a coin and tap Add to Collection to keep track of it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct TotalValueCard: View {
    let coins: [CoinScan]

    private var low: Double { coins.reduce(0) { $0 + $1.valueLow } }
    private var high: Double { coins.reduce(0) { $0 + $1.valueHigh } }
    private var scarceCount: Int { coins.filter { $0.rarity.level >= Rarity.scarce.level }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Total estimated value (USD)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                EstimateTag()
            }
            Text(valueRange(low, high))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.goldGradient)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            HStack(spacing: 0) {
                stat("\(coins.count)", coins.count == 1 ? "Coin" : "Coins")
                stat("\(scarceCount)", "Scarce or rarer")
                stat(coins.map(\.valueHigh).max()?.usd ?? "–", "Top coin")
            }
        }
        .padding(20)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).foregroundStyle(.white).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
