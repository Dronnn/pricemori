import Foundation

enum MeasurementUnit: String, Codable, CaseIterable, Identifiable {
    case gram
    case kilogram
    case milliliter
    case liter
    case item
    case pair
    case loaf

    var id: String { rawValue }

    nonisolated var symbol: String {
        switch self {
        case .gram: "g"
        case .kilogram: "kg"
        case .milliliter: "mL"
        case .liter: "L"
        case .item: "item"
        case .pair: "pair"
        case .loaf: "loaf"
        }
    }

    nonisolated var dimension: UnitDimension {
        switch self {
        case .gram, .kilogram: .mass
        case .milliliter, .liter: .volume
        case .item, .pair, .loaf: .count
        }
    }

    /// Amount of the base unit contained in one of this unit.
    nonisolated var baseMultiplier: Decimal {
        switch self {
        case .gram: Decimal(string: "0.001")!
        case .kilogram, .liter: 1
        case .milliliter: Decimal(string: "0.001")!
        case .item: 1
        case .pair: 2
        case .loaf: 1
        }
    }

    nonisolated var baseUnitSymbol: String {
        switch dimension {
        case .mass: "kg"
        case .volume: "L"
        case .count: self == .loaf ? "loaf" : self == .pair ? "pair" : "item"
        }
    }

    nonisolated static func fromSymbol(_ symbol: String) -> MeasurementUnit? {
        allCases.first { $0.symbol == symbol }
    }
}

enum UnitDimension: String, Codable {
    case mass
    case volume
    case count
}

enum ObservationCondition: String, Codable, CaseIterable, Identifiable {
    case regular
    case card
    case multiBuy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regular: "Regular price"
        case .card: "Card only"
        case .multiBuy: "Multi-buy"
        }
    }

    var shortTitle: String {
        switch self {
        case .regular: "Regular"
        case .card: "Card"
        case .multiBuy: "Multi-buy"
        }
    }
}

enum ObservationSource: String, Codable, CaseIterable, Identifiable {
    case shelf
    case paid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shelf: "Seen on shelf"
        case .paid: "Actually paid"
        }
    }

    var shortTitle: String {
        switch self {
        case .shelf: "Shelf price"
        case .paid: "Paid price"
        }
    }
}

enum JournalSort: String, CaseIterable, Identifiable {
    case recent
    case name

    var id: String { rawValue }
    var title: String { self == .recent ? "Recent" : "Name" }
}

struct CurrencyOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
    var title: String { "\(code) · \(name)" }

    static let all: [CurrencyOption] = [
        CurrencyOption(code: "AMD", name: "Armenian dram"),
        CurrencyOption(code: "USD", name: "US dollar"),
        CurrencyOption(code: "EUR", name: "Euro"),
        CurrencyOption(code: "GBP", name: "British pound"),
        CurrencyOption(code: "RUB", name: "Russian ruble"),
        CurrencyOption(code: "GEL", name: "Georgian lari"),
        CurrencyOption(code: "TRY", name: "Turkish lira"),
        CurrencyOption(code: "JPY", name: "Japanese yen")
    ]

    static func name(for code: String) -> String {
        all.first { $0.code == code }?.name ?? code
    }

    static func minorUnitCount(for code: String) -> Int {
        switch code {
        case "AMD", "JPY": 0
        default: 2
        }
    }
}
