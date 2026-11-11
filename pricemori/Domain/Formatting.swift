import Foundation

enum Format {
    private static var numberLocale: Locale { L10n.formattingLocale }
    private static var dateLocale: Locale { L10n.formattingLocale }

    static func number(_ value: Decimal, minFraction: Int = 0, maxFraction: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = numberLocale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minFraction
        formatter.maximumFractionDigits = maxFraction
        formatter.usesGroupingSeparator = true
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    static func money(_ value: Decimal, currency: String) -> String {
        let digits = CurrencyOption.minorUnitCount(for: currency)
        return number(value, minFraction: digits, maxFraction: digits)
    }

    static func unitMoney(_ value: Decimal, currency: String, unit: String) -> String {
        "\(number(value, minFraction: 0, maxFraction: 2)) \(currency) / \(unit)"
    }

    static func signedMoney(_ value: Decimal, currency: String, unit: String? = nil) -> String {
        let sign = value > 0 ? "+" : value < 0 ? "−" : ""
        let magnitude = value < 0 ? -value : value
        if let unit {
            return "\(sign)\(number(magnitude, minFraction: 0, maxFraction: 2)) \(currency) / \(unit)"
        }
        return "\(sign)\(money(magnitude, currency: currency)) \(currency)"
    }

    static func percent(_ value: Decimal, includeSign: Bool = true) -> String {
        if value == 0 { return "0%" }
        let sign = value > 0 ? (includeSign ? "+" : "") : "−"
        let magnitude = value < 0 ? -value : value
        return "\(sign)\(number(magnitude, minFraction: 1, maxFraction: 1))%"
    }

    static func quantity(_ value: Decimal) -> String {
        number(value, minFraction: 0, maxFraction: 3)
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = dateLocale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = dateLocale
        formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return formatter.string(from: date)
    }

    static func dateAndAge(_ date: Date, relativeTo now: Date = .now) -> String {
        "\(Format.date(date)) · \(relativeAge(date, relativeTo: now))"
    }

    static func relativeThenDate(_ date: Date, relativeTo now: Date = .now) -> String {
        "\(relativeAge(date, relativeTo: now)) · \(Format.date(date))"
    }

    static func dateAndShortAge(_ date: Date, relativeTo now: Date = .now) -> String {
        "\(shortDate(date)) · \(relativeAge(date, relativeTo: now))"
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = dateLocale
        formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy HHmm")
        return formatter.string(from: date)
    }

    static func time(_ date: Date, includesSeconds: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = dateLocale
        formatter.timeStyle = includesSeconds ? .medium : .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func relativeAge(_ date: Date, relativeTo now: Date = .now) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        switch days {
        case ..<0:
            let future = abs(days)
            return future == 1 ? L10n.string("Tomorrow") : L10n.format("In %lld days", future)
        case 0:
            return L10n.string("Today")
        case 1:
            return L10n.string("Yesterday")
        default:
            return L10n.format("%lld days ago", days)
        }
    }

    static func periodRange(from: Date, to: Date) -> String {
        L10n.format("%@ to %@", shortDate(from), date(to))
    }

    static func roundedForCurrency(_ amount: Decimal, currency: String) -> Decimal {
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, CurrencyOption.minorUnitCount(for: currency), .plain)
        return result
    }

    static func decimal(from text: String, locale: Locale = L10n.formattingLocale) -> Decimal? {
        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","
        var input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if groupingSeparator.trimmingCharacters(in: .whitespaces).isEmpty {
            for space in [" ", "\u{00A0}", "\u{202F}"] {
                input = input.replacingOccurrences(of: space, with: groupingSeparator)
            }
        }
        let decimalPattern = NSRegularExpression.escapedPattern(for: decimalSeparator)
        let groupingPattern = NSRegularExpression.escapedPattern(for: groupingSeparator)
        let integerPattern = "(?:[0-9]+|[0-9]{1,3}(?:\(groupingPattern)[0-9]{3})+)"
        let pattern = "\\A[+-]?(?:\(integerPattern)(?:\(decimalPattern)[0-9]*)?|\(decimalPattern)[0-9]+)\\z"
        guard input.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let normalized = input
            .replacingOccurrences(of: groupingSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else { return nil }
        return value
    }

    nonisolated static func inputText(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
            .replacingOccurrences(of: ".", with: L10n.formattingLocale.decimalSeparator ?? ".")
    }
}
