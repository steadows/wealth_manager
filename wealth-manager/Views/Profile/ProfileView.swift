import SwiftUI

/// Local draft struct mirroring UserProfile fields for edit-then-save.
private struct ProfileDraft {
    var dateOfBirth: Date?
    var annualIncome: Decimal?
    var monthlyExpenses: Decimal?
    var filingStatus: FilingStatus = FilingStatus.single
    var stateOfResidence: String?
    var retirementAge: Int = 65
    var riskTolerance: RiskTolerance = RiskTolerance.moderate
    var dependents: Int = 0
    var hasSpouse: Bool = false
    var spouseIncome: Decimal?

    init(from profile: UserProfile) {
        dateOfBirth = profile.dateOfBirth
        annualIncome = profile.annualIncome
        monthlyExpenses = profile.monthlyExpenses
        filingStatus = profile.filingStatus
        stateOfResidence = profile.stateOfResidence
        retirementAge = profile.retirementAge
        riskTolerance = profile.riskTolerance
        dependents = profile.dependents
        hasSpouse = profile.hasSpouse
        spouseIncome = profile.spouseIncome
    }

    init() {}

    /// Applies draft values back to a UserProfile model.
    func apply(to profile: UserProfile) {
        profile.dateOfBirth = dateOfBirth
        profile.annualIncome = annualIncome
        profile.monthlyExpenses = monthlyExpenses
        profile.filingStatus = filingStatus
        profile.stateOfResidence = stateOfResidence
        profile.retirementAge = retirementAge
        profile.riskTolerance = riskTolerance
        profile.dependents = dependents
        profile.hasSpouse = hasSpouse
        profile.spouseIncome = spouseIncome
    }

    var age: Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
    }

    var yearsToRetirement: Int? {
        guard let currentAge = age else { return nil }
        return max(0, retirementAge - currentAge)
    }

    var householdIncome: Decimal? {
        guard let income = annualIncome else { return nil }
        if hasSpouse, let spouseIncome { return income + spouseIncome }
        return income
    }
}

/// Detail view for editing user profile settings.
struct ProfileView: View {
    @Bindable var viewModel: ProfileViewModel
    @State private var draft = ProfileDraft()
    @State private var hasDraft = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.profile != nil {
                    profileForm
                }
            }
            .padding()
        }
        .task {
            await viewModel.ensureProfile()
            if let profile = viewModel.profile {
                draft = ProfileDraft(from: profile)
                hasDraft = true
            }
        }
    }

    // MARK: - Form

    @ViewBuilder
    private var profileForm: some View {
        personalSection
        taxSection
        retirementSection
        familySection
        saveSection
    }

    // MARK: - Personal Section

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Personal", icon: "person.fill")

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Date of Birth")
                DatePicker(
                    "Date of Birth",
                    selection: Binding(
                        get: { draft.dateOfBirth ?? Date() },
                        set: { draft.dateOfBirth = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.field)

                if let age = draft.age {
                    Text("Age: \(age)")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                }
            }

            decimalField(label: "Annual Income", value: $draft.annualIncome)
            decimalField(label: "Monthly Expenses", value: $draft.monthlyExpenses)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Tax Section

    private var taxSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Tax", icon: "doc.text.fill")

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Filing Status")
                Picker("Filing Status", selection: $draft.filingStatus) {
                    ForEach(FilingStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("State of Residence")
                TextField(
                    "e.g. California",
                    text: Binding(
                        get: { draft.stateOfResidence ?? "" },
                        set: { draft.stateOfResidence = $0.isEmpty ? nil : $0 }
                    )
                )
                .textFieldStyle(.plain)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Retirement Section

    private var retirementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Retirement", icon: "clock.fill")

            HStack {
                fieldLabel("Retirement Age")
                Spacer()
                Stepper("\(draft.retirementAge)", value: $draft.retirementAge, in: 50...90)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
            }

            if let years = draft.yearsToRetirement {
                Text("\(years) years to retirement")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Risk Tolerance")
                Picker("Risk Tolerance", selection: $draft.riskTolerance) {
                    ForEach(RiskTolerance.allCases) { tolerance in
                        Text(tolerance.displayName).tag(tolerance)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Family Section

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Family", icon: "person.2.fill")

            HStack {
                fieldLabel("Dependents")
                Spacer()
                Stepper("\(draft.dependents)", value: $draft.dependents, in: 0...20)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
            }

            Toggle(isOn: $draft.hasSpouse) {
                fieldLabel("Has Spouse / Partner")
            }

            if draft.hasSpouse {
                decimalField(label: "Spouse Income", value: $draft.spouseIncome)
            }

            if let household = draft.householdIncome {
                HStack {
                    Text("Household Income")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    Spacer()
                    CurrencyText(amount: household, font: WMTypography.subheading)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Save

    private var saveSection: some View {
        HStack {
            Spacer()

            if viewModel.isSaving {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }

            GlassButton(label: "Save Profile", icon: "checkmark") {
                guard let profile = viewModel.profile else { return }
                draft.apply(to: profile)
                Task {
                    await viewModel.saveProfile()
                }
            }
            .disabled(viewModel.isSaving)
            .opacity(viewModel.isSaving ? 0.5 : 1.0)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(WMColors.primary)
            Text(title)
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(WMTypography.caption)
            .foregroundStyle(WMColors.textMuted)
    }

    private func decimalField(label: String, value: Binding<Decimal?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label)
            HStack {
                Text("$")
                    .foregroundStyle(WMColors.textMuted)
                TextField(
                    "0.00",
                    text: Binding(
                        get: {
                            value.wrappedValue.map { "\($0)" } ?? ""
                        },
                        set: { text in
                            value.wrappedValue = text.isEmpty ? nil : Decimal(string: text)
                        }
                    )
                )
                .textFieldStyle(.plain)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
            }
        }
    }
}
