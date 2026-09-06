import SwiftUI
import Charts

struct TrendChart: View {
    let points: [DayPoint]

    private var recent: [DayPoint] { Array(points.suffix(30)) }

    private var delta: Int64? {
        guard recent.count >= 2 else { return nil }
        return recent[recent.count - 1].livre - recent[recent.count - 2].livre
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Espaço livre")
                    .font(.headline)
                Spacer()
                if let d = delta {
                    Text(d >= 0 ? "+\(Fmt.bytes(d)) desde ontem"
                                : "−\(Fmt.bytes(-d)) desde ontem")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(d >= 0 ? .green : .orange)
                }
            }

            if recent.count < 2 {
                Text("A linha aparece a partir do segundo relatório. Hoje tem \(recent.count).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
                    .background(Color.secondary.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 8))
            } else {
                Chart(recent) { p in
                    AreaMark(
                        x: .value("Dia", p.date),
                        y: .value("Livre", Double(p.livre) / 1_000_000_000)
                    )
                    .foregroundStyle(
                        .linearGradient(colors: [.accentColor.opacity(0.35), .accentColor.opacity(0.02)],
                                        startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Dia", p.date),
                        y: .value("Livre", Double(p.livre) / 1_000_000_000)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(.init(lineWidth: 2))
                    .interpolationMethod(.monotone)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { v in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.18))
                        AxisValueLabel {
                            if let gb = v.as(Double.self) {
                                Text("\(Int(gb)) GB").font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { v in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 130)
            }
        }
    }
}
