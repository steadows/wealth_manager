import Testing
import Foundation

@testable import wealth_manager

// MARK: - CSVExportServiceTests

@Suite("CSVExportService", .serialized)
struct CSVExportServiceTests {

    // MARK: - Helpers

    private let service = CSVExportService()

    private func makeAccount(
        institutionName: String = "Chase",
        accountName: String = "Checking",
        accountType: AccountType = .checking,
        currentBalance: Decimal = 1_000,
        isManual: Bool = true
    ) -> Account {
        Account(
            institutionName: institutionName,
            accountName: accountName,
            accountType: accountType,
            currentBalance: currentBalance,
            isManual: isManual
        )
    }

    private func makeAccount(balance: Decimal) -> Account {
        makeAccount(currentBalance: balance)
    }

    private func makeTransaction(
        amount: Decimal = 50,
        date: Date = Date(),
        merchantName: String? = "Amazon",
        category: TransactionCategory = .shopping
    ) -> Transaction {
        let account = makeAccount()
        return Transaction(
            account: account,
            amount: amount,
            date: date,
            merchantName: merchantName,
            category: category
        )
    }

    private func makeSnapshot(
        date: Date,
        totalAssets: Decimal,
        totalLiabilities: Decimal
    ) -> NetWorthSnapshot {
        NetWorthSnapshot(date: date, totalAssets: totalAssets, totalLiabilities: totalLiabilities)
    }

    private func lines(from data: Data) -> [String] {
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    // MARK: - Accounts CSV

    @Test("exportAccountsCSV: header row contains expected columns")
    func exportAccountsCSV_headerRow_containsExpectedColumns() throws {
        let data = try service.exportAccountsCSV(accounts: [])
        let header = lines(from: data).first ?? ""
        #expect(header.contains("Institution"))
        #expect(header.contains("Account Name"))
        #expect(header.contains("Account Type"))
        #expect(header.contains("Balance"))
        #expect(header.contains("Manual"))
    }

    @Test("exportAccountsCSV: correct row count (n accounts = n+1 lines)")
    func exportAccountsCSV_correctRowCount() throws {
        let accounts = [makeAccount(), makeAccount(), makeAccount()]
        let data = try service.exportAccountsCSV(accounts: accounts)
        let allLines = lines(from: data)
        #expect(allLines.count == accounts.count + 1)
    }

    @Test("exportAccountsCSV: Decimal formatting — no scientific notation")
    func exportAccountsCSV_decimalFormatting_noScientificNotation() throws {
        // Use Decimal(string:) to avoid floating-point precision loss in literals.
        let balance = Decimal(string: "1234567.89")!
        let account = makeAccount(balance: balance)
        let data = try service.exportAccountsCSV(accounts: [account])
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("1234567.89"))
        // Verify the balance field itself does not use scientific notation.
        // Extract balance field from the data row (second line, 4th column).
        let dataLines = lines(from: data).dropFirst()
        let balanceField = dataLines.first.flatMap { line -> String? in
            let fields = line.components(separatedBy: ",")
            return fields.count >= 4 ? fields[3] : nil
        } ?? ""
        #expect(!balanceField.contains("E"))
        #expect(!balanceField.contains("e+") && !balanceField.contains("e-"))
    }

    @Test("exportAccountsCSV: empty accounts returns header only")
    func exportAccountsCSV_emptyAccounts_returnsHeaderOnly() throws {
        let data = try service.exportAccountsCSV(accounts: [])
        let allLines = lines(from: data)
        #expect(allLines.count == 1)
    }

    @Test("exportAccountsCSV: special characters are escaped")
    func exportAccountsCSV_specialCharacters_escaped() throws {
        let account = makeAccount(
            institutionName: "Bank, \"National\"",
            accountName: "My Account, Savings"
        )
        let data = try service.exportAccountsCSV(accounts: [account])
        let text = String(data: data, encoding: .utf8) ?? ""
        // Values containing commas or quotes must be wrapped in double quotes
        #expect(text.contains("\"Bank, \"\"National\"\"\""))
        #expect(text.contains("\"My Account, Savings\""))
    }

    // MARK: - Transactions CSV

    @Test("exportTransactionsCSV: date formatting is ISO 8601")
    func exportTransactionsCSV_dateFormatting_iso8601() throws {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15
        let date = Calendar.current.date(from: components)!
        let transaction = makeTransaction(date: date)
        let data = try service.exportTransactionsCSV(transactions: [transaction])
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("2025-06-15"))
    }

    @Test("exportTransactionsCSV: negative amounts are formatted correctly")
    func exportTransactionsCSV_negativeAmounts_formatted() throws {
        let transaction = makeTransaction(amount: -500)
        let data = try service.exportTransactionsCSV(transactions: [transaction])
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("-500.00"))
    }

    // MARK: - Net Worth CSV

    @Test("exportNetWorthCSV: snapshots sorted chronologically ascending")
    func exportNetWorthCSV_chronologicalOrder() throws {
        let calendar = Calendar.current
        let now = Date()
        let older = calendar.date(byAdding: .month, value: -2, to: now)!
        let newer = calendar.date(byAdding: .month, value: -1, to: now)!

        let snapshots = [
            makeSnapshot(date: newer, totalAssets: 200_000, totalLiabilities: 5_000),
            makeSnapshot(date: older, totalAssets: 180_000, totalLiabilities: 5_000),
        ]

        let data = try service.exportNetWorthHistoryCSV(snapshots: snapshots)
        let allLines = lines(from: data)

        // Skip header, check that older date row comes before newer date row
        let dataLines = Array(allLines.dropFirst())
        #expect(dataLines.count == 2)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let olderStr = iso.string(from: older)
        let newerStr = iso.string(from: newer)

        let firstDataLine = dataLines[0]
        let secondDataLine = dataLines[1]
        #expect(firstDataLine.contains(olderStr))
        #expect(secondDataLine.contains(newerStr))
    }

    @Test("exportNetWorthCSV: header includes Net Worth column")
    func exportNetWorthCSV_includesNetWorthColumn() throws {
        let data = try service.exportNetWorthHistoryCSV(snapshots: [])
        let header = lines(from: data).first ?? ""
        #expect(header.contains("Net Worth"))
    }
}
