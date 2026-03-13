import Foundation
import Observation

/// Supported export file formats.
enum ExportFormat: String, CaseIterable, Identifiable {
    case csv
    case pdf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .csv: "CSV"
        case .pdf: "PDF"
        }
    }
}

/// ViewModel managing export state and delegating export work to service layer.
@Observable
final class ExportViewModel {

    // MARK: - State

    /// Whether an export operation is in progress.
    var isExporting: Bool = false

    /// The last successfully exported data blob, ready for sharing.
    var exportedData: Data?

    /// The currently selected export format.
    var exportFormat: ExportFormat = .csv

    /// A user-facing error message, set when export fails.
    var error: String?

    // MARK: - Dependencies

    private let csvService: CSVExportService
    private let pdfService: PDFExportService

    // MARK: - Init

    init(
        csvService: CSVExportService = CSVExportService(),
        pdfService: PDFExportService = PDFExportService()
    ) {
        self.csvService = csvService
        self.pdfService = pdfService
    }

    // MARK: - Export Actions

    /// Exports accounts to the currently selected format.
    func exportAccounts(_ accounts: [Account]) throws {
        isExporting = true
        error = nil
        defer { isExporting = false }

        do {
            exportedData = try csvService.exportAccountsCSV(accounts: accounts)
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    /// Exports transactions to the currently selected format.
    func exportTransactions(_ transactions: [Transaction]) throws {
        isExporting = true
        error = nil
        defer { isExporting = false }

        do {
            exportedData = try csvService.exportTransactionsCSV(transactions: transactions)
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    /// Exports net worth history snapshots to the currently selected format.
    func exportNetWorth(_ snapshots: [NetWorthSnapshot]) throws {
        isExporting = true
        error = nil
        defer { isExporting = false }

        do {
            exportedData = try csvService.exportNetWorthHistoryCSV(snapshots: snapshots)
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
}
