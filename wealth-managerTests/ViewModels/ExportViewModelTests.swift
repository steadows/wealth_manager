import Testing
import Foundation

@testable import wealth_manager

// MARK: - ExportViewModelTests

@Suite("ExportViewModel", .serialized)
struct ExportViewModelTests {

    // MARK: - Helpers

    private func makeAccount(
        institutionName: String = "Chase",
        accountName: String = "Checking",
        balance: Decimal = 1_000
    ) -> Account {
        Account(
            institutionName: institutionName,
            accountName: accountName,
            accountType: .checking,
            currentBalance: balance,
            isManual: true
        )
    }

    private func makeSnapshot(
        totalAssets: Decimal = 100_000,
        totalLiabilities: Decimal = 10_000
    ) -> NetWorthSnapshot {
        NetWorthSnapshot(date: Date(), totalAssets: totalAssets, totalLiabilities: totalLiabilities)
    }

    // MARK: - Initial State

    @Test("initialState: isExporting is false, exportedData is nil")
    func initialState_notExporting() {
        let vm = ExportViewModel()
        #expect(!vm.isExporting)
        #expect(vm.exportedData == nil)
        #expect(vm.error == nil)
    }

    // MARK: - Export Accounts

    @Test("exportAccounts: sets exportedData on success")
    func exportAccounts_setsExportedData() throws {
        let vm = ExportViewModel()
        let accounts = [makeAccount(), makeAccount(accountName: "Savings", balance: 5_000)]

        try vm.exportAccounts(accounts)

        #expect(vm.exportedData != nil)
        #expect(vm.exportedData!.count > 0)
        #expect(vm.error == nil)
    }

    @Test("exportAccounts: isExporting is false after completion")
    func exportAccounts_setsIsExporting_thenClears() throws {
        let vm = ExportViewModel()
        // isExporting should be false before
        #expect(!vm.isExporting)

        try vm.exportAccounts([makeAccount()])

        // isExporting should be false after synchronous completion
        #expect(!vm.isExporting)
        #expect(vm.exportedData != nil)
    }

    // MARK: - Export Transactions

    @Test("exportTransactions: sets exportedData on success")
    func exportTransactions_setsExportedData() throws {
        let vm = ExportViewModel()
        let account = makeAccount()
        let transactions = [
            Transaction(account: account, amount: 50, date: Date(), merchantName: "Amazon", category: .shopping),
            Transaction(account: account, amount: -200, date: Date(), merchantName: "Salary", category: .income),
        ]

        try vm.exportTransactions(transactions)

        #expect(vm.exportedData != nil)
        #expect(vm.error == nil)
    }

    // MARK: - Export Net Worth

    @Test("exportNetWorth: sets exportedData on success")
    func exportNetWorth_setsExportedData() throws {
        let vm = ExportViewModel()
        let snapshots = [makeSnapshot(), makeSnapshot(totalAssets: 110_000, totalLiabilities: 9_000)]

        try vm.exportNetWorth(snapshots)

        #expect(vm.exportedData != nil)
        #expect(vm.error == nil)
    }

    // MARK: - Export Format

    @Test("exportFormat: defaults to csv")
    func exportFormat_defaultsToCSV() {
        let vm = ExportViewModel()
        #expect(vm.exportFormat == .csv)
    }

    @Test("exportFormat: can be changed to pdf")
    func exportFormat_canBeChangedToPDF() {
        let vm = ExportViewModel()
        vm.exportFormat = .pdf
        #expect(vm.exportFormat == .pdf)
    }
}
