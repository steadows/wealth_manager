import Foundation

/// Pure-function CSV export service. No external dependencies.
struct CSVExportService: DataExportServiceProtocol {

    // MARK: - DataExportServiceProtocol

    /// Exports accounts to CSV. Columns: Institution, Account Name, Account Type, Balance, Currency, Manual.
    func exportAccountsCSV(accounts: [Account]) throws -> Data {
        var rows: [String] = []
        rows.append(csvRow(["Institution", "Account Name", "Account Type", "Balance", "Currency", "Manual"]))
        for account in accounts {
            rows.append(csvRow([
                account.institutionName,
                account.accountName,
                account.accountType.displayName,
                formatDecimal(account.currentBalance),
                account.currency,
                account.isManual ? "Yes" : "No",
            ]))
        }
        return joinRows(rows)
    }

    /// Exports transactions to CSV. Columns: Date, Merchant, Category, Amount, Pending, Recurring.
    func exportTransactionsCSV(transactions: [Transaction]) throws -> Data {
        var rows: [String] = []
        rows.append(csvRow(["Date", "Merchant", "Category", "Amount", "Pending", "Recurring"]))
        for tx in transactions {
            rows.append(csvRow([
                formatDate(tx.date),
                tx.merchantName ?? "",
                tx.category.displayName,
                formatDecimal(tx.amount),
                tx.isPending ? "Yes" : "No",
                tx.isRecurring ? "Yes" : "No",
            ]))
        }
        return joinRows(rows)
    }

    /// Exports net worth snapshots to CSV sorted ascending by date.
    func exportNetWorthHistoryCSV(snapshots: [NetWorthSnapshot]) throws -> Data {
        let sorted = snapshots.sorted { $0.date < $1.date }
        var rows: [String] = []
        rows.append(csvRow(["Date", "Total Assets", "Total Liabilities", "Net Worth"]))
        for snapshot in sorted {
            rows.append(csvRow([
                formatDate(snapshot.date),
                formatDecimal(snapshot.totalAssets),
                formatDecimal(snapshot.totalLiabilities),
                formatDecimal(snapshot.netWorth),
            ]))
        }
        return joinRows(rows)
    }

    /// Not CSV — delegates to PDFExportService. Satisfies protocol but should not be called on this type.
    func exportBriefingPDF(title: String, sections: [(String, String)]) throws -> Data {
        try PDFExportService().exportBriefingPDF(title: title, sections: sections)
    }

    // MARK: - Private Helpers

    /// Formats a single CSV row, escaping values that contain commas, quotes, or newlines.
    private func csvRow(_ fields: [String]) -> String {
        fields.map { escapeCSVField($0) }.joined(separator: ",")
    }

    /// Wraps a field in double quotes and doubles any internal double-quote characters.
    private func escapeCSVField(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        guard needsQuoting else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Formats a Decimal as a plain decimal string without scientific notation or locale separators.
    /// Uses NSDecimalNumber stringValue (always plain notation) then pads to 2 decimal places.
    private func formatDecimal(_ value: Decimal) -> String {
        // NSDecimalNumber.stringValue always produces plain notation without grouping separators.
        let raw = (value as NSDecimalNumber).stringValue
        // Ensure at least 2 decimal places.
        if raw.contains(".") {
            let parts = raw.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let fraction = parts[1]
            if fraction.count < 2 {
                return raw + String(repeating: "0", count: 2 - fraction.count)
            }
            return raw
        } else {
            return raw + ".00"
        }
    }

    /// Formats a Date as ISO 8601 full-date string (YYYY-MM-DD).
    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    /// Joins rows with newline characters and encodes as UTF-8 data.
    private func joinRows(_ rows: [String]) -> Data {
        let text = rows.joined(separator: "\n")
        return text.data(using: .utf8) ?? Data()
    }
}
