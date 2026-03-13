import Foundation

/// Protocol defining the contract for all data export operations.
protocol DataExportServiceProtocol {
    /// Exports accounts to CSV-formatted data.
    func exportAccountsCSV(accounts: [Account]) throws -> Data

    /// Exports transactions to CSV-formatted data.
    func exportTransactionsCSV(transactions: [Transaction]) throws -> Data

    /// Exports net worth snapshots to CSV-formatted data.
    func exportNetWorthHistoryCSV(snapshots: [NetWorthSnapshot]) throws -> Data

    /// Renders a PDF briefing document from titled sections.
    func exportBriefingPDF(title: String, sections: [(String, String)]) throws -> Data
}
