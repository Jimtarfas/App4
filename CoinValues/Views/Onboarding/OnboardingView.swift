import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [(symbol: String, title: String, text: String)] = [
        ("camera.viewfinder", "Identify any coin", "Photograph the front and back. Coin Values recognizes the coin in seconds."),
        ("calendar.badge.clock", "Year, mint mark & rarity", "See the year, mint, series, metal and how hard the coin is to find."),
        ("chart.line.uptrend.xyaxis", "Know what it's worth", "Get an estimated value range and watch your collection's total grow."),
    ]

    var body: some View {
        ZStack {
            Theme.heroGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPage(index: index, symbol: pages[index].symbol, title: pages[index].title, text: pages[index].text)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Theme.gold : Color.white.opacity(0.25))
                            .frame(width: index == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring(duration: 0.3), value: page)
                .padding(.bottom, 28)
                .accessibilityHidden(true)

                Button(page == pages.count - 1 ? "Get Started" : "Continue") {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                }
                .buttonStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct OnboardingPage: View {
    let index: Int
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.12))
                    .frame(width: 260, height: 260)
                Circle()
                    .strokeBorder(Theme.gold.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 8]))
                    .frame(width: 220, height: 220)
                CoinGlyph(symbol: index == 0 ? "dollarsign" : index == 1 ? "building.columns" : "star.fill", size: 150)
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 64, height: 64)
                    .background(Theme.goldGradient, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.navy, lineWidth: 4))
                    .offset(x: 86, y: 86)
            }
            VStack(spacing: 12) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .foregroundStyle(.white)
            Spacer()
            Spacer()
        }
    }
}
