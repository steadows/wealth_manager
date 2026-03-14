import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

/// Provides timeline entries for the Net Worth widget.
struct NetWorthTimelineProvider: TimelineProvider {
    private let store: WidgetDataStoreProtocol

    init(store: WidgetDataStoreProtocol = AppGroupWidgetDataStore()) {
        self.store = store
    }

    func placeholder(in context: Context) -> NetWorthWidgetEntry {
        NetWorthWidgetEntry(
            date: Date(),
            data: NetWorthWidgetData(
                netWorth: "250000",
                dailyChange: "1500",
                dailyChangePercent: "0.006",
                isPositive: true,
                lastUpdated: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NetWorthWidgetEntry) -> Void) {
        let entry = NetWorthWidgetEntry(
            date: Date(),
            data: store.loadNetWorthData()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NetWorthWidgetEntry>) -> Void) {
        let entry = NetWorthWidgetEntry(
            date: Date(),
            data: store.loadNetWorthData()
        )
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View

/// Small widget showing current net worth with daily change.
struct NetWorthWidgetView: View {
    let entry: NetWorthWidgetEntry

    var body: some View {
        if let data = entry.data {
            VStack(alignment: .leading, spacing: 4) {
                Text("NET WORTH")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.6))

                Text(formattedCurrency(data.netWorthDecimal))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: data.isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)

                    Text(formattedCurrency(abs(data.dailyChangeDecimal)))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(data.isPositive ? Color.green : Color.red)

                Text(formattedPercent(data.dailyChangePercentDecimal))
                    .font(.caption2)
                    .foregroundStyle(data.isPositive ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .widgetBackground()
        } else {
            emptyStateView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "banknote")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.4))
            Text("Open app to\nload data")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground()
    }

    // MARK: - Formatters

    private func formattedCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func formattedPercent(_ value: Decimal) -> String {
        let absValue = abs(NSDecimalNumber(decimal: value).doubleValue)
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        let sign = value >= 0 ? "+" : "-"
        let formatted = formatter.string(from: NSNumber(value: absValue)) ?? "0.00%"
        return "\(sign)\(formatted)"
    }
}

// MARK: - Widget Definition

/// Small WidgetKit widget displaying current net worth and daily change.
struct NetWorthWidget: Widget {
    let kind: String = "NetWorthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NetWorthTimelineProvider()) { entry in
            NetWorthWidgetView(entry: entry)
        }
        .configurationDisplayName("Net Worth")
        .description("Shows your current net worth and daily change.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Background Modifier

private extension View {
    /// Applies the Holographic JARVIS dark background for widgets.
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
            return self.containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color(red: 7 / 255, green: 11 / 255, blue: 20 / 255),
                        Color(red: 12 / 255, green: 18 / 255, blue: 32 / 255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            return self.background(
                LinearGradient(
                    colors: [
                        Color(red: 7 / 255, green: 11 / 255, blue: 20 / 255),
                        Color(red: 12 / 255, green: 18 / 255, blue: 32 / 255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    NetWorthWidget()
} timeline: {
    NetWorthWidgetEntry(
        date: Date(),
        data: NetWorthWidgetData(
            netWorth: "342567",
            dailyChange: "2150",
            dailyChangePercent: "0.0063",
            isPositive: true,
            lastUpdated: Date()
        )
    )
    NetWorthWidgetEntry(
        date: Date(),
        data: nil
    )
}
