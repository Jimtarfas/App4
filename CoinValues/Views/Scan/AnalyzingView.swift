import SwiftUI

struct AnalyzingView: View {
    let image: UIImage?
    @State private var rotation = 0.0
    @State private var messageIndex = 0

    private let messages = [
        "Reading the date and mint mark…",
        "Matching the design and series…",
        "Checking rarity…",
        "Estimating the value…",
    ]

    var body: some View {
        ZStack {
            Theme.heroGradient.ignoresSafeArea()
            VStack(spacing: 36) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(colors: [Theme.gold.opacity(0), Theme.gold, Theme.goldLight], center: .center),
                            lineWidth: 5
                        )
                        .frame(width: 236, height: 236)
                        .rotationEffect(.degrees(rotation))
                    Group {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            CoinGlyph(size: 200)
                        }
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
                }
                VStack(spacing: 10) {
                    Text("Identifying your coin")
                        .font(.title2.weight(.bold))
                    Text(messages[messageIndex])
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.opacity)
                        .id(messageIndex)
                }
                .foregroundStyle(.white)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { rotation = 360 }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation { messageIndex = (messageIndex + 1) % messages.count }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
