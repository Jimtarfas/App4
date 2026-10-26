import SwiftData
import SwiftUI

/// The identification result. Used right after a scan and when opening a saved coin.
struct CoinDetailView: View {
    @Bindable var coin: CoinScan
    var isNewResult = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var zoomedImage: Data?

    var body: some View {
        ScrollViewReader { reader in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photos
                titleBlock
                valueCard
                detailsGrid
                if !coin.summary.isEmpty { section("About this coin", text: coin.summary).id("about") }
                if !coin.features.isEmpty { featuresSection }
                if !coin.valueNotes.isEmpty { section("What affects the value", text: coin.valueNotes) }
                if coin.inCollection { notesSection }
                EstimateDisclaimer()
                    .padding(.top, 4)
            }
            .padding(20)
            .padding(.bottom, 90)
        }
        #if DEBUG
        .onAppear { if DemoMode.scrollToDetails { reader.scrollTo("about", anchor: .top) } }
        #endif
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isNewResult ? "Result" : coin.year == "Unknown" ? "Coin" : coin.year)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { collectionButton }
        .toolbar {
            if !isNewResult {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Delete")
                }
            }
        }
        .confirmationDialog("Delete this coin?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(coin)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("It will be removed from your scans and your collection.")
        }
        .sheet(item: Binding(get: { zoomedImage.map(ZoomItem.init) }, set: { zoomedImage = $0?.data })) { item in
            ZoomedPhoto(data: item.data)
        }
    }

    private var photos: some View {
        HStack(spacing: 16) {
            photo(coin.frontImage, label: "Front")
            photo(coin.backImage, label: "Back")
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func photo(_ data: Data?, label: String) -> some View {
        VStack(spacing: 6) {
            if data != nil {
                Button { zoomedImage = data } label: { CoinPhoto(data: data, size: 140) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(label) photo")
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .overlay(Text("No photo").font(.caption).foregroundStyle(.secondary))
            }
            Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(coin.name)
                .font(.title2.weight(.bold))
            if !coin.subtitle.isEmpty {
                Text(coin.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Estimated value (USD)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                EstimateTag()
            }
            Text(valueRange(coin.valueLow, coin.valueHigh))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.goldGradient)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !coin.condition.isEmpty {
                Text("For the condition shown: \(coin.condition)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Divider().overlay(.white.opacity(0.15))
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rarity").font(.caption).foregroundStyle(.white.opacity(0.6))
                    Text(coin.rarity.title).font(.headline).foregroundStyle(.white)
                }
                RarityMeter(rarity: coin.rarity)
                    .frame(maxWidth: 150)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(20)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var detailsGrid: some View {
        let items: [(String, String)] = [
            ("Year", coin.year),
            ("Mint mark", coin.mintMark),
            ("Denomination", coin.denomination),
            ("Composition", coin.composition),
            ("Series", coin.series),
            ("Match confidence", coin.confidence.title),
        ].filter { !$0.1.isEmpty }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0).font(.caption).foregroundStyle(.secondary)
                    Text(item.1).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text).font(.body).foregroundStyle(.primary.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Worth checking").font(.headline)
            ForEach(coin.features, id: \.self) { feature in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                    Text(feature).font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My notes").font(.headline)
            TextField("Where you found it, purchase price…", text: $coin.notes, axis: .vertical)
                .lineLimit(2...6)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var collectionButton: some View {
        Group {
            if coin.inCollection {
                Button {
                    withAnimation { coin.setInCollection(false) }
                    try? modelContext.save()
                } label: {
                    Label("In Your Collection", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityHint("Removes the coin from your collection")
            } else {
                Button {
                    withAnimation { coin.setInCollection(true) }
                    try? modelContext.save()
                } label: {
                    Label("Add to Collection", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

private struct ZoomItem: Identifiable {
    let data: Data
    var id: Int { data.hashValue }
}

private struct ZoomedPhoto: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnifyGesture().onChanged { scale = max(1, min($0.magnification, 5)) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Close")
            .padding(20)
        }
    }
}
