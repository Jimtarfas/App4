import SwiftUI

/// A drawn gold coin, used where there is no photo yet (onboarding, empty states, paywall).
struct CoinGlyph: View {
    var symbol: String = "dollarsign"
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            Circle().fill(Theme.goldGradient)
            Circle()
                .strokeBorder(
                    AngularGradient(colors: [Theme.goldLight, Theme.goldDark, Theme.goldLight, Theme.goldDark, Theme.goldLight], center: .center),
                    style: StrokeStyle(lineWidth: size * 0.06, dash: [size * 0.012, size * 0.012])
                )
            Circle()
                .strokeBorder(Theme.goldDark.opacity(0.55), lineWidth: size * 0.012)
                .padding(size * 0.1)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold, design: .serif))
                .foregroundStyle(Theme.goldDark.opacity(0.85))
                .shadow(color: Theme.goldLight.opacity(0.8), radius: 0, x: -1, y: -1)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: size * 0.08, y: size * 0.04)
        .accessibilityHidden(true)
    }
}

/// A coin photo clipped to a circle, or a drawn coin when there is no photo.
struct CoinPhoto: View {
    let data: Data?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            } else {
                CoinGlyph(size: size)
            }
        }
        .accessibilityHidden(true)
    }
}

struct RarityMeter: View {
    let rarity: Rarity

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { level in
                Capsule()
                    .fill(level <= rarity.level ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.secondary.opacity(0.2)))
                    .frame(height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rarity: \(rarity.title)")
    }
}

/// A small "Estimate" tag shown next to every value.
struct EstimateTag: View {
    var body: some View {
        Text("ESTIMATE")
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.gold.opacity(0.18), in: Capsule())
            .foregroundStyle(Theme.goldDark)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(Theme.navy)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

/// The value line used in lists: "$12 – $40" with a muted "est." suffix.
struct ValueRangeLabel: View {
    let low: Double
    let high: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(valueRange(low, high))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text("est. value")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct CoinRow: View {
    let coin: CoinScan

    var body: some View {
        HStack(spacing: 14) {
            CoinPhoto(data: coin.frontImage, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(coin.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text([coin.year, coin.rarity.title].filter { !$0.isEmpty && $0 != "Unknown" }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            ValueRangeLabel(low: coin.valueLow, high: coin.valueHigh)
        }
        .padding(.vertical, 4)
    }
}

/// Shown under every value so nobody mistakes an estimate for an appraisal.
struct EstimateDisclaimer: View {
    var body: some View {
        Label {
            Text("Values are AI estimates for information only, not a professional appraisal. Real prices depend on condition, authenticity and demand. For valuable coins, ask a dealer or grading service.")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
