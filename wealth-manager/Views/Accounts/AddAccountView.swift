import SwiftUI

/// Modal sheet for adding a new account, either via Plaid link or manual entry.
struct AddAccountView: View {

    @Environment(\.dismiss) private var dismiss

    /// Called with the newly created `Account` on save.
    var onSave: (Account) -> Void

    // MARK: - State

    @State private var step: Step = .choose

    // Manual form fields
    @State private var accountType: AccountType = .checking
    @State private var institutionName: String = ""
    @State private var accountName: String = ""
    @State private var balanceText: String = ""
    @State private var currency: String = "USD"
    @State private var validationError: String?

    private enum Step {
        case choose
        case manual
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
            }
        }
        .frame(width: 480, height: step == .choose ? 340 : 460)
        .background(WMColors.backgroundStart)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if step == .manual {
                Button {
                    step = .choose
                    validationError = nil
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(WMColors.primary)
            }

            Spacer()

            Text(step == .choose ? "Add Account" : "Manual Account")
                .font(.headline)
                .foregroundStyle(WMColors.textPrimary)

            Spacer()

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(16)
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
        VStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(WMColors.textMuted)
            Text("Link Account")
                .font(.headline)
                .foregroundStyle(WMColors.textMuted)
            Text("Connect via Plaid")
                .font(.caption)
                .foregroundStyle(WMColors.textMuted)
            Text("Coming in Sprint 5")
                .font(.caption2)
                .foregroundStyle(WMColors.negative.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .glassCard()
        .opacity(0.5)
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

    // MARK: - Actions

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
