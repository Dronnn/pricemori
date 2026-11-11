import SwiftUI
import Charts

struct PriceChartView: View {
    let observations: [PriceObservation]
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var height: CGFloat = 174
    var showsUnitLabel = false
    var basis: ChartBasis = .unit
    var selectedDate: Binding<Date?>? = nil

    private var series: [PriceObservation] {
        observations
            .filter { basis == .unit ? $0.unitPrice != nil : true }
            .sortedChronologically
    }

    private var drawsEveryPoint: Bool { series.count <= 120 }
    private var showsEveryAnnotation: Bool { series.count <= (dynamicTypeSize.isAccessibilitySize ? 3 : 12) }

    private func value(for observation: PriceObservation) -> Decimal? {
        ChartValues.amount(observation, basis: basis)
    }

    private var values: [Double] {
        series.compactMap { value(for: $0).map { NSDecimalNumber(decimal: $0).doubleValue } }
    }

    private var grid: [Double] { ChartValues.axisTicks(values) }

    private var domain: ClosedRange<Double> {
        (grid.first ?? 0)...(grid.last ?? 1)
    }

    private var xDomain: ClosedRange<Date> {
        ChartValues.dateDomain(series.map(\.observedAt))
    }

    private var unitLabel: String {
        guard let last = series.last else { return "" }
        if basis == .package { return "\(last.currencyCode) / package" }
        guard let unit = last.baseUnitSymbol else { return last.currencyCode }
        return "\(last.currencyCode) / \(unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsUnitLabel {
                Text(unitLabel)
                    .font(AppFont.inter(13))
                    .foregroundStyle(Theme.secondaryText)
            }

            if series.isEmpty {
                Text("No unit price to chart")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: height)
            } else {
                Chart {
                    ForEach(Array(series.enumerated()), id: \.element.id) { index, observation in
                        if let displayValue = value(for: observation) {
                            let value = NSDecimalNumber(decimal: displayValue).doubleValue
                            let isLatest = index == series.count - 1

                            LineMark(
                                x: .value("Date", observation.observedAt),
                                y: .value(basis.title, value)
                            )
                            .interpolationMethod(.linear)
                            .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(Theme.chartLine)

                            if isLatest {
                                PointMark(
                                    x: .value("Date", observation.observedAt),
                                    y: .value(basis.title, value)
                                )
                                .symbolSize(420)
                                .foregroundStyle(Theme.chartHalo.opacity(0.13))
                            }

                            if drawsEveryPoint || isLatest {
                                PointMark(
                                    x: .value("Date", observation.observedAt),
                                    y: .value(basis.title, value)
                                )
                                .symbolSize(isLatest ? 82 : 50)
                                .foregroundStyle(isLatest ? Theme.accent : Theme.chartLine)
                                .annotation(position: .top, spacing: 1) {
                                    if showsEveryAnnotation || isLatest {
                                        Text(Format.number(displayValue, maxFraction: 2))
                                            .font(AppFont.inter(14, .semibold))
                                            .foregroundStyle(isLatest ? Theme.accent : Theme.primaryText)
                                    }
                                }
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXScale(domain: xDomain)
                .chartYScale(domain: domain)
                .chartYAxis {
                    AxisMarks(position: .leading, values: grid) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                            .foregroundStyle(Theme.separator)
                        AxisValueLabel {
                            if let raw = value.as(Double.self) {
                                Text(Format.number(Decimal(raw), maxFraction: ChartValues.axisFractionDigits(grid)))
                                    .font(AppFont.inter(13))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: dynamicTypeSize.isAccessibilitySize ? 2 : 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(ChartValues.dateLabel(date, in: xDomain))
                                    .font(AppFont.inter(13))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }
                .frame(height: height * max(1, textScale))
                .padding(.top, 12 * textScale)
                .modifier(OptionalChartSelection(selection: selectedDate))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chartAccessibilityLabel)
            }
        }
    }

    private var chartAccessibilityLabel: String {
        let parts = series.compactMap { observation -> String? in
            guard let displayValue = value(for: observation) else { return nil }
            let suffix = basis == .unit ? observation.baseUnitSymbol ?? "package" : "package"
            return "\(Format.date(observation.observedAt)): \(Format.number(displayValue, maxFraction: 2)) \(observation.currencyCode) per \(suffix)"
        }
        return "Price history. " + parts.joined(separator: ". ")
    }
}


private struct OptionalChartSelection: ViewModifier {
    let selection: Binding<Date?>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let selection {
            content.chartXSelection(value: selection)
        } else {
            content
        }
    }
}

/// Calculations shared by the plot, its selected point, and its text alternative.
enum ChartValues {
    static func recordedRange(_ observations: [PriceObservation], basis: ChartBasis) -> RecordedRange? {
        let points = observations.sortedChronologically.filter { amount($0, basis: basis) != nil }
        guard let latest = points.last,
              let minimum = points.min(by: { (amount($0, basis: basis) ?? 0) < (amount($1, basis: basis) ?? 0) }),
              let maximum = points.max(by: { (amount($0, basis: basis) ?? 0) < (amount($1, basis: basis) ?? 0) }) else { return nil }
        return RecordedRange(minimum: minimum, maximum: maximum, latest: latest)
    }

    static func amount(_ observation: PriceObservation, basis: ChartBasis) -> Decimal? {
        basis == .unit ? observation.unitPrice : observation.effectivePackagePrice
    }

    static func percentChange(_ observations: [PriceObservation], basis: ChartBasis) -> Decimal? {
        let points = observations.sortedChronologically.filter { amount($0, basis: basis) != nil }
        guard let first = points.first, let last = points.last, first.id != last.id,
              PriceMath.sameConditions(first, last), first.currencyCode == last.currencyCode,
              first.store?.id == last.store?.id,
              let start = amount(first, basis: basis), let end = amount(last, basis: basis), start > 0
        else { return nil }
        if basis == .unit, !PriceMath.compatibleUnits(first, last) { return nil }
        return (end - start) / start * 100
    }

    static func range(_ observations: [PriceObservation], basis: ChartBasis) -> ClosedRange<Decimal>? {
        let amounts = observations.compactMap { amount($0, basis: basis) }
        guard let minimum = amounts.min(), let maximum = amounts.max() else { return nil }
        return minimum...maximum
    }

    static func rangePosition(minimum: Decimal, maximum: Decimal, value: Decimal) -> Double {
        guard maximum > minimum else { return 0.5 }
        return min(1, max(0, NSDecimalNumber(decimal: (value - minimum) / (maximum - minimum)).doubleValue))
    }

    static func axisTicks(_ values: [Double]) -> [Double] {
        let finite = values.filter(\.isFinite)
        guard let minimum = finite.min(), let maximum = finite.max() else { return [0, 0.5, 1] }
        let span = maximum - minimum
        let padding = span > 0 ? span * 0.12 : max(abs(minimum) * 0.1, 0.01)
        let lower = max(0, minimum - padding)
        let upper = maximum + padding
        let rawStep = max((upper - lower) / 4, Double.leastNormalMagnitude)
        let magnitude = pow(10, floor(log10(rawStep)))
        let normalized = rawStep / magnitude
        let multiplier: Double = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10
        let step = multiplier * magnitude
        let start = floor(lower / step) * step
        let end = ceil(upper / step) * step
        let count = max(1, Int(((end - start) / step).rounded()))
        return (0...count).map { start + Double($0) * step }
    }

    static func axisFractionDigits(_ ticks: [Double]) -> Int {
        guard ticks.count > 1 else { return 2 }
        let step = ticks[1] - ticks[0]
        guard step > 0 else { return 2 }
        return max(0, min(8, Int(ceil(-log10(step)))))
    }

    static func dateDomain(_ dates: [Date]) -> ClosedRange<Date> {
        guard let first = dates.min(), let last = dates.max() else {
            return Date.now.addingTimeInterval(-43_200)...Date.now.addingTimeInterval(43_200)
        }
        let span = last.timeIntervalSince(first)
        let padding = span > 0 ? max(1, span * 0.08) : 43_200
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }

    static func dateLabel(_ date: Date, in domain: ClosedRange<Date>) -> String {
        if domain.upperBound.timeIntervalSince(domain.lowerBound) < 86_400 {
            return Format.time(date, includesSeconds: domain.upperBound.timeIntervalSince(domain.lowerBound) < 300)
        }
        if domain.upperBound.timeIntervalSince(domain.lowerBound) > 366 * 86_400 {
            return Format.date(date)
        }
        return Format.shortDate(date)
    }

    static func packageSizeChange(_ observations: [PriceObservation]) -> (PriceObservation, PriceObservation)? {
        let points = observations.sortedChronologically
        guard points.count > 1 else { return nil }
        return Array(zip(points, points.dropFirst())).last { previous, current in
            guard PriceMath.compatibleUnits(previous, current),
                  let before = previous.baseQuantity, let after = current.baseQuantity else { return false }
            return before != after
        }
    }
}
