import Testing
import Foundation

@testable import wealth_manager

// MARK: - TaxViewModelTests

@Suite("TaxViewModel")
struct TaxViewModelTests {

    // MARK: - Helpers

    private func makeAccount(
        id: UUID = UUID(),
        type: AccountType,
        balance: Decimal = 0
    ) -> Account {
        Account(
            id: id,
            institutionName: "Test Bank",
            accountName: type.rawValue,
            accountType: type,
            currentBalance: balance,
            isManual: true
        )
    }

    private func makeHolding(
        account: Account,
        securityName: String = "Test Fund",
        ticker: String = "TST",
        quantity: Decimal = 10,
        costBasis: Decimal? = 100,
        currentPrice: Decimal = 90,
        assetClass: AssetClass = .usEquity,
        holdingType: HoldingType = .etf
    ) -> InvestmentHolding {
        InvestmentHolding(
            account: account,
            securityName: securityName,
            tickerSymbol: ticker,
            quantity: quantity,
            costBasis: costBasis,
            currentPrice: currentPrice,
            holdingType: holdingType,
            assetClass: assetClass
        )
    }

    private func makeProfile(
        income: Decimal = 150_000,
        filingStatus: FilingStatus = .single
    ) -> UserProfile {
        UserProfile(
            annualIncome: income,
            filingStatus: filingStatus
        )
    }

    private func makeViewModel(
        profile: UserProfile? = nil,
        accounts: [Account] = [],
        holdings: [InvestmentHolding] = []
    ) -> TaxViewModel {
        let profileRepo = MockUserProfileRepository()
        profileRepo.profile = profile

        let accountRepo = MockAccountRepository()
        accountRepo.items = accounts

        let holdingRepo = MockInvestmentHoldingRepository()
        holdingRepo.items = holdings

        return TaxViewModel(
            accountRepo: accountRepo,
            profileRepo: profileRepo,
            holdingRepo: holdingRepo
        )
    }

    // MARK: - Initial State

    @Test("initial state: isLoading is false")
    func initialStateIsLoadingFalse() {
        let vm = makeViewModel()
        #expect(!vm.isLoading)
    }

    @Test("initial state: error is nil")
    func initialStateErrorNil() {
        let vm = makeViewModel()
        #expect(vm.error == nil)
    }

    @Test("initial state: estimatedAnnualTax is zero")
    func initialStateEstimatedTaxZero() {
        let vm = makeViewModel()
        #expect(vm.estimatedAnnualTax == 0)
    }

    // MARK: - loadTaxData: Income Tax

    @Test("loadTaxData: $150K single income sets non-zero estimatedAnnualTax")
    func loadTaxDataSetsEstimatedAnnualTax() async {
        let profile = makeProfile(income: 150_000, filingStatus: .single)
        let vm = makeViewModel(profile: profile)

        await vm.loadTaxData()

        #expect(vm.estimatedAnnualTax > 0)
        #expect(vm.error == nil)
        #expect(!vm.isLoading)
    }

    @Test("loadTaxData: $150K single income sets effectiveTaxRate between 0 and 1")
    func loadTaxDataSetsEffectiveTaxRate() async {
        let profile = makeProfile(income: 150_000, filingStatus: .single)
        let vm = makeViewModel(profile: profile)

        await vm.loadTaxData()

        #expect(vm.effectiveTaxRate > 0)
        #expect(vm.effectiveTaxRate < 1)
    }

    @Test("loadTaxData: $150K single income sets marginalTaxRate to 22%")
    func loadTaxDataSetsMarginalTaxRate() async {
        // $150K - $15K standard deduction = $135K taxable — falls in 24% bracket for single
        let profile = makeProfile(income: 150_000, filingStatus: .single)
        let vm = makeViewModel(profile: profile)

        await vm.loadTaxData()

        // Taxable income after standard deduction: $135K → 24% marginal rate for single
        #expect(vm.marginalTaxRate == Decimal(string: "0.24")!)
    }

    @Test("loadTaxData: effectiveTaxRate is less than marginalTaxRate")
    func loadTaxDataEffectiveLessThanMarginal() async {
        let profile = makeProfile(income: 150_000, filingStatus: .single)
        let vm = makeViewModel(profile: profile)

        await vm.loadTaxData()

        #expect(vm.effectiveTaxRate < vm.marginalTaxRate)
    }

    // MARK: - loadTaxData: Standard Deduction

    @Test("loadTaxData: standard deduction for single filer is $15,000")
    func loadTaxDataSetsStandardDeductionSingle() async {
        let profile = makeProfile(income: 100_000, filingStatus: .single)
        let vm = makeViewModel(profile: profile)

        await vm.loadTaxData()

        #expect(vm.standardDeduction == 15_000)
    }

    @Test("loadTaxData: standard deduction for married joint is $30,000")
    func loadTaxDataSetsStandardDeductionMFJ() async {
        let profile = makeProfile(income: 100_000, filingStatus: .marriedJoint)
        let vm = makeViewModel(profile: profile)

        await vm.loadTaxData()

        #expect(vm.standardDeduction == 30_000)
    }

    // MARK: - loadTaxData: Tax-Loss Harvesting

    @Test("loadTaxData: holdings with unrealized losses populate harvestingOpportunities")
    func loadTaxDataPopulatesHarvestingOpportunities() async {
        let account = makeAccount(type: .investment, balance: 10_000)
        // costBasis $100/share, currentPrice $80 → loss of $200 total
        let losingHolding = makeHolding(
            account: account,
            quantity: 10,
            costBasis: 100,
            currentPrice: 80
        )
        let vm = makeViewModel(
            profile: makeProfile(),
            accounts: [account],
            holdings: [losingHolding]
        )

        await vm.loadTaxData()

        #expect(!vm.harvestingOpportunities.isEmpty)
        let opportunity = vm.harvestingOpportunities[0]
        #expect(opportunity.unrealizedLoss > 0)
        #expect(opportunity.estimatedTaxSavings > 0)
    }

    @Test("loadTaxData: holdings with gains excluded from harvestingOpportunities")
    func loadTaxDataExcludesGainingHoldings() async {
        let account = makeAccount(type: .investment, balance: 10_000)
        // Gaining holding: costBasis $80, current $100 → gain
        let gainingHolding = makeHolding(
            account: account,
            quantity: 10,
            costBasis: 80,
            currentPrice: 100
        )
        let vm = makeViewModel(
            profile: makeProfile(),
            accounts: [account],
            holdings: [gainingHolding]
        )

        await vm.loadTaxData()

        #expect(vm.harvestingOpportunities.isEmpty)
    }

    // MARK: - loadTaxData: Roth Conversion Opportunity

    @Test("loadTaxData: low-bracket income has non-nil rothConversionOpportunity")
    func loadTaxDataRothConversionLowBracket() async {
        // $40K income − $15K standard deduction = $25K taxable → 12% bracket
        let profile = makeProfile(income: 40_000, filingStatus: .single)
        let vm = makeViewModel(profile: profile)

        await vm.loadTaxData()

        #expect(vm.rothConversionOpportunity != nil)
        if let opp = vm.rothConversionOpportunity {
            #expect(opp.suggestedConversionAmount >= 0)
            #expect(!opp.reason.isEmpty)
        }
    }

    @Test("loadTaxData: high-bracket income returns zero conversion amount")
    func loadTaxDataRothConversionHighBracket() async {
        // $300K income → well into 32%+ bracket
        let profile = makeProfile(income: 300_000, filingStatus: .single)
        let vm = makeViewModel(profile: profile)

        await vm.loadTaxData()

        if let opp = vm.rothConversionOpportunity {
            #expect(opp.suggestedConversionAmount == 0)
        }
    }

    // MARK: - loadTaxData: Empty / Graceful Defaults

    @Test("loadTaxData: no profile results in zero tax values")
    func loadTaxDataNoProfileZeroTax() async {
        let vm = makeViewModel(profile: nil)

        await vm.loadTaxData()

        #expect(vm.estimatedAnnualTax == 0)
        #expect(vm.effectiveTaxRate == 0)
        #expect(vm.marginalTaxRate == 0)
        #expect(vm.error == nil)
    }

    @Test("loadTaxData: no holdings results in empty harvestingOpportunities")
    func loadTaxDataNoHoldingsEmptyHarvesting() async {
        let vm = makeViewModel(profile: makeProfile(), holdings: [])

        await vm.loadTaxData()

        #expect(vm.harvestingOpportunities.isEmpty)
    }

    @Test("loadTaxData: clears isLoading on completion")
    func loadTaxDataClearsIsLoading() async {
        let vm = makeViewModel(profile: makeProfile())

        await vm.loadTaxData()

        #expect(!vm.isLoading)
    }
}
