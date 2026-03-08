import SwiftUI
import SwiftData

// MARK: - App Sections

/// Navigation sections for the sidebar.
enum AppSection: String, CaseIterable, Identifiable {
    case dashboard, netWorth, accounts, budget, goals, aiAdvisor, reports, planning

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: "Dashboard"
        case .netWorth: "Net Worth"
        case .accounts: "Accounts"
        case .budget: "Budget"
        case .goals: "Goals"
        case .aiAdvisor: "AI Advisor"
        case .reports: "Reports"
        case .planning: "Planning"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "house"
        case .netWorth: "chart.line.uptrend.xyaxis"
        case .accounts: "building.columns"
        case .budget: "wallet.bifold"
        case .goals: "target"
        case .aiAdvisor: "bubble.left.and.bubble.right"
        case .reports: "doc.text"
        case .planning: "calendar"
        }
    }

    /// Keyboard shortcut key for Cmd+1 through Cmd+8.
    var shortcutKey: KeyEquivalent {
        let allCases = AppSection.allCases
        guard let index = allCases.firstIndex(of: self) else { return "1" }
        let number = index + 1
        return KeyEquivalent(Character("\(number)"))
    }
}

// MARK: - Main Split View

/// Three-column NavigationSplitView serving as the app shell.
struct MainSplitView: View {
    @State private var selectedSection: AppSection? = .dashboard
    @State private var selectedAccount: Account?
    @State private var selectedGoal: FinancialGoal?
    @State private var isReady: Bool = false

    @Environment(\.modelContext) private var modelContext

    /// Detects if the app is running as a test host.
    static let isRunningTests: Bool = {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }()

    // MARK: - ViewModels (created once via .task)

    @State private var dashboardVM: DashboardViewModel?
    @State private var accountsVM: AccountsViewModel?
    @State private var accountDetailVM: AccountDetailViewModel?
    @State private var goalsVM: GoalsViewModel?
    @State private var budgetVM: BudgetViewModel?
    @State private var profileVM: ProfileViewModel?

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .background(sectionShortcuts)
        .task {
            guard !Self.isRunningTests else { return }
            ensureViewModels()
        }
        .onChange(of: selectedAccount) {
            rebuildAccountDetailVM()
        }
    }

    // MARK: - ViewModel Factory

    /// Creates all ViewModels once from the model container.
    private func ensureViewModels() {
        guard !isReady else { return }
        let container = modelContext.container

        dashboardVM = DashboardViewModel(
            accountRepo: SwiftDataAccountRepository(modelContainer: container),
            transactionRepo: SwiftDataTransactionRepository(modelContainer: container),
            snapshotRepo: SwiftDataSnapshotRepository(modelContainer: container),
            healthScoreRepo: SwiftDataHealthScoreRepository(modelContainer: container),
            goalRepo: SwiftDataGoalRepository(modelContainer: container)
        )
        accountsVM = AccountsViewModel(
            accountRepo: SwiftDataAccountRepository(modelContainer: container)
        )
        goalsVM = GoalsViewModel(
            goalRepo: SwiftDataGoalRepository(modelContainer: container)
        )
        budgetVM = BudgetViewModel(
            budgetRepo: SwiftDataBudgetCategoryRepository(modelContainer: container),
            transactionRepo: SwiftDataTransactionRepository(modelContainer: container)
        )
        profileVM = ProfileViewModel(
            profileRepo: SwiftDataUserProfileRepository(modelContainer: container)
        )
        isReady = true
    }

    /// Rebuilds AccountDetailViewModel only when selectedAccount changes.
    private func rebuildAccountDetailVM() {
        guard let account = selectedAccount else {
            accountDetailVM = nil
            return
        }
        let container = modelContext.container
        accountDetailVM = AccountDetailViewModel(
            account: account,
            transactionRepo: SwiftDataTransactionRepository(modelContainer: container)
        )
    }

    // MARK: - Keyboard Shortcuts

    /// Hidden buttons providing Cmd+1 through Cmd+8 shortcuts.
    private var sectionShortcuts: some View {
        ZStack {
            ForEach(AppSection.allCases) { section in
                Button("") {
                    selectedSection = section
                }
                .keyboardShortcut(section.shortcutKey, modifiers: .command)
                .hidden()
            }
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            sectionList
            Divider().overlay(WMColors.glassBorder)
            userFooter
        }
        .background(WMColors.background)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
    }

    private var sectionList: some View {
        List(AppSection.allCases, selection: $selectedSection) { section in
            Label(section.label, systemImage: section.icon)
                .foregroundStyle(
                    selectedSection == section
                        ? WMColors.primary
                        : WMColors.textPrimary
                )
                .tag(section)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var userFooter: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [WMColors.primary, WMColors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Text("SM")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                )

            Text("Steve M.")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Content Column

    @ViewBuilder
    private var contentColumn: some View {
        switch selectedSection {
        case .accounts:
            if let vm = accountsVM {
                AccountsListView(viewModel: vm, selection: $selectedAccount)
            }
        case .goals:
            if let vm = goalsVM {
                GoalsListView(viewModel: vm, selectedGoal: $selectedGoal)
            }
        default:
            Text("Select an item")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WMColors.background)
        }
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        switch selectedSection {
        case .dashboard:
            if let vm = dashboardVM {
                DashboardView(viewModel: vm)
            } else {
                ProgressView("Loading dashboard...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WMColors.background)
            }
        case .netWorth:
            placeholderView(title: "Net Worth", icon: "chart.line.uptrend.xyaxis")
        case .accounts:
            accountDetail
        case .budget:
            budgetDetail
        case .goals:
            goalDetail
        case .aiAdvisor:
            placeholderView(title: "AI Advisor", icon: "bubble.left.and.bubble.right")
        case .reports:
            placeholderView(title: "Reports", icon: "doc.text")
        case .planning:
            PlanningView()
        case nil:
            placeholderView(title: "Wealth Manager", icon: "dollarsign.circle")
        }
    }

    @ViewBuilder
    private var accountDetail: some View {
        if let vm = accountDetailVM {
            AccountDetailView(viewModel: vm)
        } else {
            placeholderView(title: "Select an Account", icon: "building.columns")
        }
    }

    @ViewBuilder
    private var budgetDetail: some View {
        if let vm = budgetVM {
            BudgetView(viewModel: vm)
        } else {
            placeholderView(title: "Budget", icon: "wallet.bifold")
        }
    }

    @ViewBuilder
    private var goalDetail: some View {
        if let goal = selectedGoal {
            GoalDetailView(goal: goal)
        } else {
            placeholderView(title: "Select a Goal", icon: "target")
        }
    }

    private func placeholderView(title: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(WMColors.textMuted)

            Text(title)
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Text("Coming soon")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WMColors.background)
    }
}