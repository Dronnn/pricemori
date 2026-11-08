import SwiftUI
import Charts

struct PriceChartView: View {
    let observations: [PriceObservation]
    var height: CGFloat = 174
    var showsUnitLabel = false
    var basis: ChartBasis = .unit
    var selectedDate: Binding<Date?>? = nil

    private var series: [PriceObservation] {
        observations
            .filter { basis == .unit ? $0.unitPrice != nil : true }
            .sortedChronologically
    }

    private func value(for observation: PriceObservation) -> Decimal? {
        basis == .unit ? observation.unitPrice : observation.effectivePackagePrice
    }

    private var values: [Double] {
        series.compactMap { value(for: $0).map { NSDecimalNumber(decimal: $0).doubleValue } }
    }

    private var grid: [Double] {
        guard let minimum = values.min(), let maximum = values.max() else { return [0, 1, 2] }
        if values.count == 1 {
            return [minimum - 20, minimum, minimum + 20]
        }
        let span = maximum - minimum
        let step: Double = span <= 80 ? 20 : span <= 200 ? 50 : 100
        let low = floor(minimum / step) * step
        let high = (ceil(maximum / step) + 1) * step
        guard high > low else { return [minimum - step, minimum, minimum + step] }
        return [low, (low + high) / 2, high]
    }

    private var domain: ClosedRange<Double> {
        let low = grid.first ?? 0
        let high = grid.last ?? 1
        return low...max(high, low + 1)
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = series.first?.observedAt, let last = series.last?.observedAt else {
            return Date.now.addingTimeInterval(-86_400)...Date.now.addingTimeInterval(86_400)
        }
        if first == last {
            return first.addingTimeInterval(-10 * 86_400)...first.addingTimeInterval(10 * 86_400)
        }
        return first.addingTimeInterval(-6 * 86_400)...last.addingTimeInterval(6 * 86_400)
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
                                y: .value("Unit price", value)
                            )
                            .interpolationMethod(.linear)
                            .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(Theme.chartLine)

                            if isLatest {
                                PointMark(
                                    x: .value("Date", observation.observedAt),
                                    y: .value("Unit price", value)
                                )
                                .symbolSize(420)
                                .foregroundStyle(Theme.chartHalo.opacity(0.13))
                            }

                            PointMark(
                                x: .value("Date", observation.observedAt),
                                y: .value("Unit price", value)
                            )
                            .symbolSize(isLatest ? 82 : 50)
                            .foregroundStyle(isLatest ? Theme.accent : Theme.chartLine)
                            .annotation(position: .top, spacing: 1) {
                                Text(Format.number(displayValue, maxFraction: 2))
                                    .font(AppFont.inter(14, .semibold))
                                    .foregroundStyle(isLatest ? Theme.accent : Theme.primaryText)
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
                                Text(Format.number(Decimal(raw), maxFraction: 0))
                                    .font(AppFont.inter(13))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }
                .chartXAxis {
                    if series.count > 6 {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(Format.shortDate(date))
                                        .font(AppFont.inter(13))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    } else {
                        AxisMarks(values: series.map(\.observedAt)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(Format.shortDate(date))
                                        .font(AppFont.inter(13))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }
                }
                .frame(height: height)
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
