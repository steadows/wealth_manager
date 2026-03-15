#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - iOS Tab View

/// Tab-based navigation shell for iOS, mirroring the macOS sidebar sections.
struct MainTabView: View {
    @State private var selectedTab: TabSection = .dashboard
    @State private var isReady: Bool = false

    @Environment(\.modelContext) private var modelContext

    // MARK: - ViewModels (created once via .task)

    @State private var dashboardVM: DashboardViewModel?
    @State private var accountsVM: AccountsViewModel?
    @State private var goalsVM: GoalsViewModel?
    @State private var budgetVM: BudgetViewModel?
    @State private var profileVM: ProfileViewModel?
    @State private var advisorChatVM: AdvisorChatViewModel?
    @State private var briefingVM: CFOBriefingViewModel?
    @State private var alertsVM: AlertsViewModel?
    @State private var plaidService: PlaidLinkServiceProtocol?

    // MARK: - Tab Sections

    /// Primary tabs shown in the tab bar. "More" hosts secondary sections.
    enum TabSection: Hashable {
        case dashboard, accounts, goals, aiAdvisor, more
    }

    /// Sections available under the "More" tab.
    enum MoreSection: String, CaseIterable, Identifiable {
        case netWorth, budget, reports, planning, profile

        var id: String { rawValue }

        var label: String {
            switch self {
            case .netWorth: "Net Worth"
            case .budget: "Budget"
            case .reports: "Reports"
            case .planning: "Planning"
            case .profile: "Profile"
            }
        }

        var icon: String {
            switch self {
            case .netWorth: "chart.line.uptrend.xyaxis"
            case .budget: "wallet.bifold"
            case .reports: "doc.text"
            case .planning: "calendar"
            case .profile: "person.circle"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
            accountsTab
            goalsTab
            aiAdvisorTab
            moreTab
        }
        .tint(WMColors.primary)
        .task {
            ensureViewModels()
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

        // Advisory services (AI Advisor + Reports)
        let backendURL = AppEnvironment.backendBaseURL
        let tokenStore = KeychainTokenStore()
        let bootstrapProvider = StoredTokenProvider(store: tokenStore)
        let authClient = APIClient(baseURL: backendURL, tokenProvider: bootstrapProvider)
        let authService = AuthService(apiClient: authClient, tokenStore: tokenStore)
        let advisoryAPIClient = APIClient(baseURL: backendURL, tokenProvider: authService)
        let advisorService = AdvisorService(
            apiClient: advisoryAPIClient,
            baseURL: backendURL,
            tokenProvider: authService
        )

        advisorChatVM = AdvisorChatViewModel(advisoryService: advisorService, modelContext: modelContext)
        briefingVM = CFOBriefingViewModel(advisoryService: advisorService)
        alertsVM = AlertsViewModel(advisoryService: advisorService)
        plaidService = PlaidLinkService(apiClient: advisoryAPIClient)

        isReady = true
    }

    // MARK: - Dashboard Tab

    private var dashboardTab: some View {
        NavigationStack {
            if let vm = dashboardVM {
                DashboardView(viewModel: vm)
                    .navigationTitle("Dashboard")
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tabItem {
            Label("Dashboard", systemImage: AppSection.dashboard.icon)
        }
        .tag(TabSection.dashboard)
    }

    // MARK: - Accounts Tab

    private var accountsTab: some View {
        NavigationStack {
            if let vm = accountsVM {
                AccountsListView(viewModel: vm, selection: .constant(nil), plaidService: plaidService)
                    .navigationTitle("Accounts")
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tabItem {
            Label("Accounts", systemImage: AppSection.accounts.icon)
        }
        .tag(TabSection.accounts)
    }

    // MARK: - Goals Tab

    private var goalsTab: some View {
        NavigationStack {
            if let vm = goalsVM {
                GoalsListView(viewModel: vm, selectedGoal: .constant(nil))
                    .navigationTitle("Goals")
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tabItem {
            Label("Goals", systemImage: AppSection.goals.icon)
        }
        .tag(TabSection.goals)
    }

    // MARK: - AI Advisor Tab

    private var aiAdvisorTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let chatVM = advisorChatVM {
                    AdvisorChatView(viewModel: chatVM)
                }
                if let alertsVM {
                    Divider()
                    AlertsListView(viewModel: alertsVM)
                        .frame(maxHeight: 200)
                }
            }
            .navigationTitle("AI Advisor")
        }
        .tabItem {
            Label("AI Advisor", systemImage: AppSection.aiAdvisor.icon)
        }
        .tag(TabSection.aiAdvisor)
    }

    // MARK: - More Tab

    private var moreTab: some View {
        NavigationStack {
            List {
                ForEach(MoreSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.label, systemImage: section.icon)
                            .foregroundStyle(WMColors.textPrimary)
                    }
                }
            }
            .navigationTitle("More")
            .navigationDestination(for: MoreSection.self) { section in
                moreDestination(for: section)
            }
        }
        .tabItem {
            Label("More", systemImage: "ellipsis.circle")
        }
        .tag(TabSection.more)
    }

    // MARK: - More Destinations

    @ViewBuilder
    private func moreDestination(for section: MoreSection) -> some View {
        switch section {
        case .netWorth:
            netWorthContent
                .navigationTitle("Net Worth")
        case .budget:
            if let vm = budgetVM {
                BudgetView(viewModel: vm)
                    .navigationTitle("Budget")
            }
        case .reports:
            if let vm = briefingVM {
                CFOBriefingView(viewModel: vm)
                    .navigationTitle("Reports")
            }
        case .planning:
            PlanningView()
                .navigationTitle("Planning")
        case .profile:
            if let vm = profileVM {
                ProfileView(viewModel: vm)
                    .navigationTitle("Profile")
            }
        }
    }

    // MARK: - Net Worth Sub-Views

    @State private var netWorthTab: Int = 0

    @ViewBuilder
    private var netWorthContent: some View {
        let container = modelContext.container
        let accountRepo = SwiftDataAccountRepository(modelContainer: container)
        let snapshotRepo = SwiftDataSnapshotRepository(modelContainer: container)
        let profileRepo = SwiftDataUserProfileRepository(modelContainer: container)

        VStack(spacing: 0) {
            Picker("View", selection: $netWorthTab) {
                Text("Net Worth").tag(0)
                Text("Projections").tag(1)
                Text("What If").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            switch netWorthTab {
            case 0:
                NetWorthView(
                    accountRepo: accountRepo,
                    snapshotRepo: snapshotRepo,
                    profileRepo: profileRepo
                )
            case 1:
                ProjectionView(
                    accountRepo: accountRepo,
                    profileRepo: profileRepo
                )
            case 2:
                WhatIfView(
                    accountRepo: accountRepo,
                    profileRepo: profileRepo
                )
            default:
                EmptyView()
            }
        }
    }
}
#endif
