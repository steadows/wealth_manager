import SwiftUI

/// Modal sheet for adding a new account, either via Plaid link or manual entry.
struct AddAccountView: View {

    @Environment(\.dismiss) private var dismiss

    /// Called with the newly created `Account` on save.
    var onSave: (Account) -> Void

    /// Called with accounts linked via Plaid (multiple accounts possible).
    var onPlaidLinked: (([Account]) -> Void)?

    /// Optional Plaid link service for bank account linking.
    var plaidService: PlaidLinkServiceProtocol?

    /// Optional Plaid link handler for native iOS link flow.
    var plaidLinkHandler: PlaidLinkHandlerProtocol?

    // MARK: - State

    @State private var step: Step = .choose
    @State private var plaidViewModel: PlaidLinkViewModel?

    // Manual form fields
    @State private var accountType: AccountType = .checking
    @State private var institutionName: String = ""
    @State private var accountName: String = ""
    @State private var balanceText: String = ""
    @State private var currency: String = "USD"
    @State private var validationError: String?

    private var isPlaidAvailable: Bool {
        plaidService != nil
    }

    private enum Step {
        case choose
        case manual
        case plaidLink
    }

    private static let supportedCurrencies = ["USD", "EUR", "GBP", "CAD"]

    // MARK: - Validation

    private var parsedBalance: Decimal? {
        Decimal(string: balanceText)
    }

    private var isFormValid: Bool {
        !institutionName.trimmingCharacters(in: .whitespaces).isEmpty
            && !accountName.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedBalance != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(WMColors.glassBorder)

            switch step {
            case .choose:
                chooseMethodContent
            case .manual:
                manualFormContent
            case .plaidLink:
                plaidLinkContent
            }
        }
        #if os(macOS)
        .frame(width: 480, height: step == .choose ? 340 : 460)
        #endif
        .background(WMColors.backgroundStart)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if step == .manual || step == .plaidLink {
                Button {
                    step = .choose
                    validationError = nil
                    plaidViewModel?.handleExit()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(WMColors.primary)
            }

            Spacer()

            Text(headerTitle)
                .font(.headline)
                .foregroundStyle(WMColors.textPrimary)

            Spacer()

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(16)
    }

    private var headerTitle: String {
        switch step {
        case .choose: return "Add Account"
        case .manual: return "Manual Account"
        case .plaidLink: return "Link Bank Account"
        }
    }

    // MARK: - Choose Method

    private var chooseMethodContent: some View {
        HStack(spacing: 16) {
            plaidCard
            manualCard
        }
        .padding(24)
        .frame(maxHeight: .infinity)
    }

    private var plaidCard: some View {
        Group {
            if isPlaidAvailable {
                Button {
                    startPlaidLink()
                } label: {
                    plaidCardContent(enabled: true)
                }
                .buttonStyle(.plain)
            } else {
                plaidCardContent(enabled: false)
                    .opacity(0.5)
            }
        }
    }

    private func plaidCardContent(enabled: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(enabled ? WMColors.primary : WMColors.textMuted)
            Text("Link Account")
                .font(.headline)
                .foregroundStyle(enabled ? WMColors.textPrimary : WMColors.textMuted)
            Text("Connect via Plaid")
                .font(.caption)
                .foregroundStyle(WMColors.textMuted)
            if !enabled {
                Text("Not configured")
                    .font(.caption2)
                    .foregroundStyle(WMColors.negative.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .glassCard()
    }

    private var manualCard: some View {
        Button {
            step = .manual
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(WMColors.primary)
                Text("Add Manually")
                    .font(.headline)
                    .foregroundStyle(WMColors.textPrimary)
                Text("Enter account details")
                    .font(.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manual Form

    private var manualFormContent: some View {
        VStack(spacing: 16) {
            Form {
                Section {
                    Picker("Account Type", selection: $accountType) {
                        ForEach(AccountType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    TextField("Institution Name", text: $institutionName)
                    TextField("Account Name", text: $accountName)

                    HStack {
                        TextField("Current Balance", text: $balanceText)
                            .onChange(of: balanceText) {
                                validationError = nil
                            }
                        Text(currency)
                            .foregroundStyle(WMColors.textMuted)
                    }

                    Picker("Currency", selection: $currency) {
                        ForEach(Self.supportedCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(WMColors.negative)
                    .padding(.horizontal, 24)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(WMColors.textMuted)

                Button("Save") { saveAccount() }
                    .buttonStyle(.borderedProminent)
                    .tint(WMColors.primary)
                    .disabled(!isFormValid)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Plaid Link Content

    private var plaidLinkContent: some View {
        VStack(spacing: 16) {
            if let vm = plaidViewModel {
                if vm.isLoading {
                    ProgressView("Connecting to Plaid...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.state == .linkReady, let url = vm.currentLinkURL {
                    #if os(macOS)
                    PlaidLinkWebView(
                        url: url,
                        onSuccess: { publicToken, _ in
                            Task {
                                await vm.handlePublicToken(publicToken)
                                handlePlaidResult(vm)
                            }
                        },
                        onExit: { _, _ in
                            vm.handleExit()
                            step = .choose
                        }
                    )
                    #elseif os(iOS)
                    PlaidLinkiOSContentView(
                        linkToken: vm.linkToken ?? "",
                        handler: plaidLinkHandler,
                        onResult: { result in
                            Task {
                                await vm.handleLinkResult(result)
                                handlePlaidResult(vm)
                            }
                        },
                        onExit: {
                            vm.handleExit()
                            step = .choose
                        }
                    )
                    #endif
                } else if vm.state == .linked {
                    plaidSuccessView(accounts: vm.linkedAccounts)
                } else if let error = vm.error {
                    plaidErrorView(message: error)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func plaidSuccessView(accounts: [Account]) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(WMColors.positive)
            Text("Accounts Linked")
                .font(.headline)
                .foregroundStyle(WMColors.textPrimary)
            Text("\(accounts.count) account(s) added")
                .font(.subheadline)
                .foregroundStyle(WMColors.textMuted)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(WMColors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func plaidErrorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(WMColors.negative)
            Text("Connection Failed")
                .font(.headline)
                .foregroundStyle(WMColors.textPrimary)
            Text(message)
                .font(.caption)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                startPlaidLink()
            }
            .buttonStyle(.borderedProminent)
            .tint(WMColors.primary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func startPlaidLink() {
        guard let plaidService else { return }
        let vm = PlaidLinkViewModel(plaidService: plaidService)
        plaidViewModel = vm
        step = .plaidLink
        Task {
            await vm.startLinking()
        }
    }

    private func handlePlaidResult(_ vm: PlaidLinkViewModel) {
        guard vm.state == .linked else { return }
        onPlaidLinked?(vm.linkedAccounts)
    }

    private func saveAccount() {
        guard !institutionName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Institution name is required."
            return
        }
        guard !accountName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Account name is required."
            return
        }
        guard let balance = parsedBalance else {
            validationError = "Balance must be a valid number."
            return
        }

        let account = Account(
            institutionName: institutionName.trimmingCharacters(in: .whitespaces),
            accountName: accountName.trimmingCharacters(in: .whitespaces),
            accountType: accountType,
            currentBalance: balance,
            currency: currency,
            isManual: true
        )

        onSave(account)
        dismiss()
    }
}
