import Foundation
import SwiftData

/// One identified coin. Every scan is kept in the history; `inCollection` marks the ones the user keeps.
@Model
final class CoinScan {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var name: String = ""
    var country: String = ""
    var denomination: String = ""
    var year: String = ""
    var mintMark: String = ""
    var series: String = ""
    var composition: String = ""
    var rarityRaw: String = Rarity.common.rawValue
    var condition: String = ""
    var valueLow: Double = 0
    var valueHigh: Double = 0
    var confidenceRaw: String = Confidence.medium.rawValue
    var summary: String = ""
    var features: [String] = []
    var valueNotes: String = ""
    var inCollection: Bool = false
    var addedToCollectionAt: Date?
    var notes: String = ""
    @Attribute(.externalStorage) var frontImage: Data?
    @Attribute(.externalStorage) var backImage: Data?

    init(identification: CoinIdentification, frontImage: Data?, backImage: Data?) {
        name = identification.name
        country = identification.country
        denomination = identification.denomination
        year = identification.year
        mintMark = identification.mintMark
        series = identification.series
        composition = identification.composition
        rarityRaw = identification.rarity.rawValue
        condition = identification.conditionEstimate
        valueLow = min(identification.valueLowUSD, identification.valueHighUSD)
        valueHigh = max(identification.valueLowUSD, identification.valueHighUSD)
        confidenceRaw = identification.confidence.rawValue
        summary = identification.description
        features = identification.notableFeatures
        valueNotes = identification.valueNotes
        self.frontImage = frontImage
        self.backImage = backImage
    }

    var rarity: Rarity { Rarity(rawValue: rarityRaw) ?? .common }
    var confidence: Confidence { Confidence(rawValue: confidenceRaw) ?? .medium }
    var valueMidpoint: Double { (valueLow + valueHigh) / 2 }

    var subtitle: String {
        [country, denomination].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func setInCollection(_ value: Bool) {
        inCollection = value
        addedToCollectionAt = value ? Date() : nil
    }
}

enum Rarity: String, Codable, CaseIterable {
    case common, uncommon, scarce, rare
    case veryRare = "very_rare"

    var title: String {
        switch self {
        case .common: "Common"
        case .uncommon: "Uncommon"
        case .scarce: "Scarce"
        case .rare: "Rare"
        case .veryRare: "Very Rare"
        }
    }

    /// 1...5, used for the rarity meter.
    var level: Int { (Rarity.allCases.firstIndex(of: self) ?? 0) + 1 }
}

enum Confidence: String, Codable {
    case high, medium, low

    var title: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }
}

/// The JSON returned by the identification service.
struct CoinIdentification: Codable, Equatable {
    var isCoin: Bool
    var name: String
    var country: String
    var denomination: String
    var year: String
    var mintMark: String
    var series: String
    var composition: String
    var rarity: Rarity
    var conditionEstimate: String
    var valueLowUSD: Double
    var valueHighUSD: Double
    var confidence: Confidence
    var description: String
    var notableFeatures: [String]
    var valueNotes: String

    enum CodingKeys: String, CodingKey {
        case isCoin = "is_coin"
        case name, country, denomination, year
        case mintMark = "mint_mark"
        case series, composition, rarity
        case conditionEstimate = "condition_estimate"
        case valueLowUSD = "value_low_usd"
        case valueHighUSD = "value_high_usd"
        case confidence, description
        case notableFeatures = "notable_features"
        case valueNotes = "value_notes"
    }
}
