import SwiftUI
import SwiftData

@main
struct wealth_managerApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Account.self, Transaction.self, InvestmentHolding.self,
            Debt.self, FinancialGoal.self, UserProfile.self,
            NetWorthSnapshot.self, FinancialHealthScore.self,
            BudgetCategory.self, ChatMessageRecord.self
        ])
        let config = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
