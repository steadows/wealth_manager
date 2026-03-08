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
}
