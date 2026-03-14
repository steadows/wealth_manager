import SwiftUI

/// Displays a Decimal amount formatted as currency.
struct CurrencyText: View {
    let amount: Decimal
    var currencyCode: String = "USD"
    var showSign: Bool = false
    var font: Font = WMTypography.body

    var body: some View {
        Text(formattedAmount)
            .font(font)
            .foregroundStyle(textColor)
            .accessibilityLabel(formattedAmount)
    }

    // MARK: - Private

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()

    private var formattedAmount: String {
        let formatter = Self.currencyFormatter.copy() as! NumberFormatter
        formatter.currencyCode = currencyCode
        if showSign && amount > 0 {
            formatter.positivePrefix = "+\(formatter.positivePrefix ?? "")"
        }
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    private var textColor: Color {
        guard showSign else { return WMColors.textPrimary }
        if amount > 0 { return WMColors.positive }
        if amount < 0 { return WMColors.negative }
        return WMColors.textPrimary
    }
}
