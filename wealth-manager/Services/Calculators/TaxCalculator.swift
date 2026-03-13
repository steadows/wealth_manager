import Foundation

// MARK: - TaxCalculator

/// Pure calculator for federal income tax, capital gains, Roth conversions,
/// tax-loss harvesting, and asset location optimization.
/// Uses 2025 federal tax brackets (IRS Rev. Proc. 2024-40).
nonisolated struct TaxCalculator: Sendable {

    // MARK: - Private Types

    /// A single federal income-tax bracket boundary.
    private struct TaxBracket {
        let lowerBound: Decimal
        let upperBound: Decimal  // Decimal.greatestFiniteMagnitude for top bracket
        let rate: Decimal
    }

    /// A single long-term capital-gains bracket boundary.
    private struct CapGainsBracket {
        let threshold: Decimal   // income above which this rate applies
        let rate: Decimal
    }

    // MARK: - 2025 Federal Income Tax Brackets (IRS Rev. Proc. 2024-40)

    private static func brackets(for status: FilingStatus) -> [TaxBracket] {
        switch status {
        case .single:
            return singleBrackets
        case .marriedJoint:
            return marriedJointBrackets
        case .marriedSeparate:
            return marriedSeparateBrackets
        case .headOfHousehold:
            return headOfHouseholdBrackets
        }
    }

    private static let singleBrackets: [TaxBracket] = [
        TaxBracket(lowerBound: 0,       upperBound: 11_925,    rate: Decimal(string: "0.10")!),
        TaxBracket(lowerBound: 11_925,   upperBound: 48_475,    rate: Decimal(string: "0.12")!),
        TaxBracket(lowerBound: 48_475,   upperBound: 103_350,   rate: Decimal(string: "0.22")!),
        TaxBracket(lowerBound: 103_350,  upperBound: 197_300,   rate: Decimal(string: "0.24")!),
        TaxBracket(lowerBound: 197_300,  upperBound: 250_525,   rate: Decimal(string: "0.32")!),
        TaxBracket(lowerBound: 250_525,  upperBound: 626_350,   rate: Decimal(string: "0.35")!),
        TaxBracket(lowerBound: 626_350,  upperBound: maxIncome, rate: Decimal(string: "0.37")!),
    ]

    private static let marriedJointBrackets: [TaxBracket] = [
        TaxBracket(lowerBound: 0,        upperBound: 23_850,    rate: Decimal(string: "0.10")!),
        TaxBracket(lowerBound: 23_850,   upperBound: 96_950,    rate: Decimal(string: "0.12")!),
        TaxBracket(lowerBound: 96_950,   upperBound: 206_700,   rate: Decimal(string: "0.22")!),
        TaxBracket(lowerBound: 206_700,  upperBound: 394_600,   rate: Decimal(string: "0.24")!),
        TaxBracket(lowerBound: 394_600,  upperBound: 501_050,   rate: Decimal(string: "0.32")!),
        TaxBracket(lowerBound: 501_050,  upperBound: 751_600,   rate: Decimal(string: "0.35")!),
        TaxBracket(lowerBound: 751_600,  upperBound: maxIncome, rate: Decimal(string: "0.37")!),
    ]

    private static let marriedSeparateBrackets: [TaxBracket] = [
        TaxBracket(lowerBound: 0,        upperBound: 11_925,    rate: Decimal(string: "0.10")!),
        TaxBracket(lowerBound: 11_925,   upperBound: 48_475,    rate: Decimal(string: "0.12")!),
        TaxBracket(lowerBound: 48_475,   upperBound: 103_350,   rate: Decimal(string: "0.22")!),
        TaxBracket(lowerBound: 103_350,  upperBound: 197_300,   rate: Decimal(string: "0.24")!),
        TaxBracket(lowerBound: 197_300,  upperBound: 250_525,   rate: Decimal(string: "0.32")!),
        TaxBracket(lowerBound: 250_525,  upperBound: 375_800,   rate: Decimal(string: "0.35")!),
        TaxBracket(lowerBound: 375_800,  upperBound: maxIncome, rate: Decimal(string: "0.37")!),
    ]

    private static let headOfHouseholdBrackets: [TaxBracket] = [
        TaxBracket(lowerBound: 0,        upperBound: 17_000,    rate: Decimal(string: "0.10")!),
        TaxBracket(lowerBound: 17_000,   upperBound: 64_850,    rate: Decimal(string: "0.12")!),
        TaxBracket(lowerBound: 64_850,   upperBound: 103_350,   rate: Decimal(string: "0.22")!),
        TaxBracket(lowerBound: 103_350,  upperBound: 197_300,   rate: Decimal(string: "0.24")!),
        TaxBracket(lowerBound: 197_300,  upperBound: 250_500,   rate: Decimal(string: "0.32")!),
        TaxBracket(lowerBound: 250_500,  upperBound: 626_350,   rate: Decimal(string: "0.35")!),
        TaxBracket(lowerBound: 626_350,  upperBound: maxIncome, rate: Decimal(string: "0.37")!),
    ]

    /// Sentinel for the top bracket upper bound.
    private static let maxIncome = Decimal(string: "999999999999")!

    // MARK: - 2025 Long-Term Capital Gains Brackets

    private static func capGainsThresholds(for status: FilingStatus) -> [CapGainsBracket] {
        switch status {
        case .single:
            return [
                CapGainsBracket(threshold: 0,       rate: 0),
                CapGainsBracket(threshold: 48_350,  rate: Decimal(string: "0.15")!),
                CapGainsBracket(threshold: 533_400, rate: Decimal(string: "0.20")!),
            ]
        case .marriedJoint:
            return [
                CapGainsBracket(threshold: 0,        rate: 0),
                CapGainsBracket(threshold: 96_700,   rate: Decimal(string: "0.15")!),
                CapGainsBracket(threshold: 600_050,  rate: Decimal(string: "0.20")!),
            ]
        case .marriedSeparate:
            return [
                CapGainsBracket(threshold: 0,        rate: 0),
                CapGainsBracket(threshold: 48_350,   rate: Decimal(string: "0.15")!),
                CapGainsBracket(threshold: 300_025,  rate: Decimal(string: "0.20")!),
            ]
        case .headOfHousehold:
            return [
                CapGainsBracket(threshold: 0,        rate: 0),
                CapGainsBracket(threshold: 64_750,   rate: Decimal(string: "0.15")!),
                CapGainsBracket(threshold: 566_700,  rate: Decimal(string: "0.20")!),
            ]
        }
    }

    // MARK: - Public API: Income Tax

    /// Calculate federal income tax for a given taxable income and filing status.
    ///
    /// - Parameters:
    ///   - taxableIncome: Adjusted gross income minus deductions.
    ///   - filingStatus: Federal filing status.
    /// - Returns: Total federal tax owed (never negative).
    static func federalTax(
        taxableIncome: Decimal,
        filingStatus: FilingStatus
    ) -> Decimal {
        guard taxableIncome > 0 else { return 0 }
        return calculateProgressiveTax(income: taxableIncome, brackets: brackets(for: filingStatus))
    }

    /// Marginal and effective federal tax rates.
    ///
    /// - Parameters:
    ///   - taxableIncome: Adjusted gross income minus deductions.
    ///   - filingStatus: Federal filing status.
    /// - Returns: The marginal rate (bracket rate) and effective rate (tax / income).
    static func taxRates(
        taxableIncome: Decimal,
        filingStatus: FilingStatus
    ) -> (marginal: Decimal, effective: Decimal) {
        guard taxableIncome > 0 else { return (marginal: 0, effective: 0) }

        let bracketList = brackets(for: filingStatus)
        let marginal = marginalRate(income: taxableIncome, brackets: bracketList)
        let tax = calculateProgressiveTax(income: taxableIncome, brackets: bracketList)
        let effective = tax / taxableIncome

        return (marginal: marginal, effective: effective)
    }

    // MARK: - Public API: Capital Gains

    /// Calculate capital gains tax (short-term or long-term).
    ///
    /// Short-term (held < 12 months) is taxed as ordinary income.
    /// Long-term uses the 0%/15%/20% tiered brackets.
    ///
    /// - Parameters:
    ///   - gains: Total capital gains amount.
    ///   - holdingPeriodMonths: Months the asset was held.
    ///   - ordinaryIncome: Other taxable income (determines bracket placement).
    ///   - filingStatus: Federal filing status.
    /// - Returns: Capital gains tax owed.
    static func capitalGainsTax(
        gains: Decimal,
        holdingPeriodMonths: Int,
        ordinaryIncome: Decimal,
        filingStatus: FilingStatus
    ) -> Decimal {
        guard gains > 0 else { return 0 }

        // Short-term: taxed as ordinary income
        if holdingPeriodMonths < 12 {
            let taxWithGains = federalTax(
                taxableIncome: ordinaryIncome + gains,
                filingStatus: filingStatus
            )
            let taxWithout = federalTax(
                taxableIncome: ordinaryIncome,
                filingStatus: filingStatus
            )
            return taxWithGains - taxWithout
        }

        // Long-term: tiered rate based on total income
        return calculateLongTermCapGainsTax(
            gains: gains,
            ordinaryIncome: ordinaryIncome,
            filingStatus: filingStatus
        )
    }

    // MARK: - Public API: Roth Conversion

    /// Analyze the trade-off of a Roth IRA conversion.
    ///
    /// - Parameters:
    ///   - conversionAmount: Amount to convert from traditional to Roth.
    ///   - currentTaxableIncome: Current year's taxable income before conversion.
    ///   - filingStatus: Federal filing status.
    ///   - yearsToRetirement: Years until retirement withdrawals begin.
    ///   - expectedRetirementTaxRate: Estimated effective tax rate in retirement.
    /// - Returns: Tax cost now, projected tax savings in retirement, and net benefit.
    static func rothConversionAnalysis(
        conversionAmount: Decimal,
        currentTaxableIncome: Decimal,
        filingStatus: FilingStatus,
        yearsToRetirement: Int,
        expectedRetirementTaxRate: Decimal
    ) -> (taxCostNow: Decimal, projectedTaxSavings: Decimal, netBenefit: Decimal) {
        guard conversionAmount > 0 else { return (0, 0, 0) }

        let taxWithConversion = federalTax(
            taxableIncome: currentTaxableIncome + conversionAmount,
            filingStatus: filingStatus
        )
        let taxWithout = federalTax(
            taxableIncome: currentTaxableIncome,
            filingStatus: filingStatus
        )
        let taxCostNow = taxWithConversion - taxWithout

        // In retirement, the converted amount grows tax-free; without conversion,
        // withdrawals would be taxed at the expected retirement rate.
        let projectedTaxSavings = conversionAmount * expectedRetirementTaxRate
        let netBenefit = projectedTaxSavings - taxCostNow

        return (
            taxCostNow: taxCostNow,
            projectedTaxSavings: projectedTaxSavings,
            netBenefit: netBenefit
        )
    }

    // MARK: - Public API: Tax-Loss Harvesting

    /// Identify holdings with unrealized losses suitable for tax-loss harvesting.
    ///
    /// - Parameter holdings: Array of `InvestmentHolding` model objects.
    /// - Returns: Holdings with unrealized losses and estimated tax savings at 15% LTCG rate.
    static func harvestingOpportunities(
        holdings: [InvestmentHolding]
    ) -> [(holding: InvestmentHolding, unrealizedLoss: Decimal, estimatedTaxSavings: Decimal)] {
        let harvestRate: Decimal = Decimal(string: "0.15")! // assumed LTCG rate for savings estimate

        return holdings.compactMap { holding in
            guard let gainLoss = holding.gainLoss, gainLoss < 0 else { return nil }
            let loss = abs(gainLoss)
            let savings = loss * harvestRate
            return (holding: holding, unrealizedLoss: loss, estimatedTaxSavings: savings)
        }
    }

    // MARK: - Public API: Asset Location

    /// Recommend optimal account placement for holdings to minimize taxes.
    ///
    /// General rules:
    /// - Tax-inefficient assets (bonds, REITs) → tax-advantaged accounts.
    /// - Tax-efficient assets (index equity, muni bonds) → taxable accounts.
    ///
    /// - Parameters:
    ///   - holdings: Array of `InvestmentHolding` model objects.
    ///   - taxableAccountIds: IDs of taxable brokerage accounts.
    ///   - taxAdvantagedAccountIds: IDs of tax-advantaged accounts (IRA, 401k).
    /// - Returns: Array of `AssetLocationSuggestion` for holdings that could be better placed.
    static func assetLocationRecommendation(
        holdings: [InvestmentHolding],
        taxableAccountIds: Set<UUID>,
        taxAdvantagedAccountIds: Set<UUID>
    ) -> [AssetLocationSuggestion] {
        holdings.compactMap { holding in
            classifyHoldingLocation(
                holding: holding,
                taxableAccountIds: taxableAccountIds,
                taxAdvantagedAccountIds: taxAdvantagedAccountIds
            )
        }
    }

    // MARK: - Public API: Estimated Annual Tax

    /// Estimate total annual federal tax from multiple income sources.
    ///
    /// - Parameters:
    ///   - salary: W-2 or self-employment income.
    ///   - capitalGains: Total long-term capital gains.
    ///   - dividends: Qualified dividend income.
    ///   - filingStatus: Federal filing status.
    ///   - deductions: Total deductions (standard or itemized).
    /// - Returns: Estimated total federal tax.
    static func estimatedAnnualTax(
        salary: Decimal,
        capitalGains: Decimal,
        dividends: Decimal,
        filingStatus: FilingStatus,
        deductions: Decimal
    ) -> Decimal {
        let ordinaryIncome = max(salary - deductions, 0)
        let incomeTax = federalTax(taxableIncome: ordinaryIncome, filingStatus: filingStatus)

        let ltcgTax = capitalGainsTax(
            gains: max(capitalGains, 0),
            holdingPeriodMonths: 12,
            ordinaryIncome: ordinaryIncome,
            filingStatus: filingStatus
        )

        // Qualified dividends taxed at LTCG rates
        let dividendTax = capitalGainsTax(
            gains: max(dividends, 0),
            holdingPeriodMonths: 12,
            ordinaryIncome: ordinaryIncome + max(capitalGains, 0),
            filingStatus: filingStatus
        )

        return incomeTax + ltcgTax + dividendTax
    }

    // MARK: - Public API: IRA Contribution Limit

    /// Returns the maximum IRA contribution limit for a given age and year.
    ///
    /// - Parameters:
    ///   - age: The taxpayer's age as of the tax year.
    ///   - year: The tax year (currently supports 2025 limits).
    /// - Returns: Base limit plus catch-up if age >= 50.
    static func iraContributionLimit(age: Int, year: Int) -> Decimal {
        // 2025 IRS limits (Rev. Proc. 2024-40)
        let base: Decimal = 7_000
        let catchUp: Decimal = 1_000
        return age >= 50 ? base + catchUp : base
    }

    // MARK: - Public API: Backdoor Roth Eligibility

    /// Determines whether the backdoor Roth IRA strategy makes sense for the taxpayer.
    ///
    /// Returns `true` when MAGI exceeds the direct-contribution phase-out range,
    /// meaning a direct Roth contribution is not possible and the backdoor conversion
    /// is the appropriate strategy. Returns `false` when income is below the phase-out
    /// threshold (direct contribution is still available).
    ///
    /// 2025 phase-out ranges (IRS Rev. Proc. 2024-40):
    ///   - Single / HoH: $150,000–$165,000
    ///   - Married Filing Jointly: $236,000–$246,000
    ///   - Married Filing Separately: $0–$10,000
    ///
    /// - Parameters:
    ///   - modifiedAGI: Modified adjusted gross income.
    ///   - filingStatus: Federal filing status.
    /// - Returns: `true` if backdoor Roth is the recommended strategy.
    static func backdoorRothEligible(
        modifiedAGI: Decimal,
        filingStatus: FilingStatus
    ) -> Bool {
        let phaseOutEnd: Decimal
        switch filingStatus {
        case .single, .headOfHousehold:
            phaseOutEnd = 165_000
        case .marriedJoint:
            phaseOutEnd = 246_000
        case .marriedSeparate:
            phaseOutEnd = 10_000
        }
        // Backdoor makes sense only when direct contribution is fully phased out
        return modifiedAGI > phaseOutEnd
    }

    // MARK: - Public API: Roth Conversion Opportunity

    /// Identifies how much of a traditional IRA balance can be converted to a Roth IRA
    /// while staying within the taxpayer's current federal income-tax bracket.
    ///
    /// If the taxpayer is already in the 22% bracket or higher, no conversion is suggested
    /// because the marginal cost is likely to exceed the long-term benefit.
    ///
    /// - Parameters:
    ///   - currentTaxableIncome: Taxable income before any conversion.
    ///   - filingStatus: Federal filing status.
    ///   - traditionalIRABalance: Current traditional IRA balance available to convert.
    /// - Returns: A tuple with the suggested conversion amount, the applicable marginal rate,
    ///   and a human-readable reason.
    static func rothConversionOpportunity(
        currentTaxableIncome: Decimal,
        filingStatus: FilingStatus,
        traditionalIRABalance: Decimal
    ) -> (suggestedConversionAmount: Decimal, marginalRate: Decimal, reason: String) {
        let bracketList = brackets(for: filingStatus)
        let currentMarginalRate = marginalRate(income: currentTaxableIncome, brackets: bracketList)

        // Only suggest conversions for taxpayers in the 10% or 12% bracket
        let conversionThresholdRate = Decimal(string: "0.22")!
        guard currentMarginalRate < conversionThresholdRate else {
            return (
                suggestedConversionAmount: 0,
                marginalRate: currentMarginalRate,
                reason: "You are already in the \(ratePercent(currentMarginalRate)) bracket. "
                    + "Roth conversion would be taxed at a high rate with limited long-term benefit."
            )
        }

        // Find the top of the current bracket
        let currentBracketTop = bracketList
            .first { $0.rate == currentMarginalRate }?
            .upperBound ?? currentTaxableIncome

        let roomInBracket = max(currentBracketTop - currentTaxableIncome, 0)
        let suggestedAmount = min(roomInBracket, traditionalIRABalance)

        return (
            suggestedConversionAmount: suggestedAmount,
            marginalRate: currentMarginalRate,
            reason: suggestedAmount > 0
                ? "You can convert up to \(formatDecimal(suggestedAmount)) and remain in "
                    + "the \(ratePercent(currentMarginalRate)) bracket, locking in today's low rate."
                : "No conversion room available in current bracket."
        )
    }

    // MARK: - Public API: Standard Deduction

    /// Returns the federal standard deduction for a given filing status and year.
    ///
    /// - Parameters:
    ///   - filingStatus: Federal filing status.
    ///   - year: The tax year (currently supports 2025 values).
    /// - Returns: Standard deduction amount in dollars.
    static func standardDeduction(filingStatus: FilingStatus, year: Int) -> Decimal {
        // 2025 IRS standard deductions (Rev. Proc. 2024-40)
        switch filingStatus {
        case .single:          return 15_000
        case .marriedJoint:    return 30_000
        case .marriedSeparate: return 15_000
        case .headOfHousehold: return 22_500
        }
    }

    // MARK: - Private Helpers

    private static func calculateProgressiveTax(
        income: Decimal,
        brackets: [TaxBracket]
    ) -> Decimal {
        var tax: Decimal = 0
        for bracket in brackets {
            guard income > bracket.lowerBound else { break }
            let taxableInBracket = min(income, bracket.upperBound) - bracket.lowerBound
            tax += taxableInBracket * bracket.rate
        }
        return tax
    }

    private static func marginalRate(
        income: Decimal,
        brackets: [TaxBracket]
    ) -> Decimal {
        for bracket in brackets.reversed() {
            if income > bracket.lowerBound {
                return bracket.rate
            }
        }
        return brackets.first?.rate ?? 0
    }

    private static func calculateLongTermCapGainsTax(
        gains: Decimal,
        ordinaryIncome: Decimal,
        filingStatus: FilingStatus
    ) -> Decimal {
        let thresholds = capGainsThresholds(for: filingStatus)
        let totalIncome = max(ordinaryIncome, 0)
        var remainingGains = gains
        var tax: Decimal = 0

        for i in (0..<thresholds.count).reversed() {
            let threshold = thresholds[i].threshold
            let rate = thresholds[i].rate

            // How much of the gains falls in this tier?
            let incomeInThisTier = max(totalIncome + gains - threshold, 0)
            let gainsInThisTier = min(remainingGains, incomeInThisTier)

            guard gainsInThisTier > 0 else { continue }

            tax += gainsInThisTier * rate
            remainingGains -= gainsInThisTier

            if remainingGains <= 0 { break }
        }

        return tax
    }

    private static func classifyHoldingLocation(
        holding: InvestmentHolding,
        taxableAccountIds: Set<UUID>,
        taxAdvantagedAccountIds: Set<UUID>
    ) -> AssetLocationSuggestion? {
        let accountId = holding.account.id
        let isInTaxable = taxableAccountIds.contains(accountId)
        let isInTaxAdvantaged = taxAdvantagedAccountIds.contains(accountId)

        // Only suggest moves for holdings in known account types
        guard isInTaxable || isInTaxAdvantaged else { return nil }

        let isTaxInefficient = taxInefficientAsset(holding)

        if isTaxInefficient && isInTaxable {
            return AssetLocationSuggestion(
                holdingId: holding.id,
                currentAccountId: accountId,
                suggestedAccountType: .retirement,
                reason: "\(holding.securityName) generates tax-inefficient income; "
                    + "consider holding in a tax-advantaged account.",
                estimatedAnnualTaxSavings: estimateTaxDrag(holding)
            )
        }

        if !isTaxInefficient && isInTaxAdvantaged {
            return AssetLocationSuggestion(
                holdingId: holding.id,
                currentAccountId: accountId,
                suggestedAccountType: .investment,
                reason: "\(holding.securityName) is tax-efficient; "
                    + "consider holding in a taxable account to free tax-advantaged space.",
                estimatedAnnualTaxSavings: estimateTaxDrag(holding)
            )
        }

        return nil
    }

    private static func taxInefficientAsset(_ holding: InvestmentHolding) -> Bool {
        switch holding.assetClass {
        case .fixedIncome, .realEstate:
            return true
        case .usEquity, .intlEquity, .cash, .commodities, .alternative:
            return holding.holdingType == .reit
        }
    }

    private static func estimateTaxDrag(_ holding: InvestmentHolding) -> Decimal {
        // Rough estimate: 2% yield taxed at 22% marginal = ~0.44% drag
        let estimatedYield: Decimal = Decimal(string: "0.02")!
        let assumedRate: Decimal = Decimal(string: "0.22")!
        return holding.currentValue * estimatedYield * assumedRate
    }

    /// Formats a Decimal rate (e.g. 0.12) as a percentage string (e.g. "12%").
    private static func ratePercent(_ rate: Decimal) -> String {
        let pct = NSDecimalNumber(decimal: rate * 100).intValue
        return "\(pct)%"
    }

    /// Formats a Decimal dollar amount as a short string (e.g. "$12,345").
    private static func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
