import Testing
import Foundation

@testable import wealth_manager

// MARK: - TaxCalculatorTests

@Suite("TaxCalculator")
struct TaxCalculatorTests {

    // MARK: - federalTax

    @Test("federalTax: $100K single filer matches bracket math")
    func federalTax100KSingle() {
        // 2025 brackets for single:
        // 10% on first $11,925 = $1,192.50
        // 12% on $11,925–$48,475 = $4,386.00
        // 22% on $48,475–$100,000 = $11,335.50
        // Total = $16,914.00
        let tax = TaxCalculator.federalTax(
            taxableIncome: 100_000,
            filingStatus: .single
        )
        let taxDouble = NSDecimalNumber(decimal: tax).doubleValue
        #expect(abs(taxDouble - 16_914.0) < 1)
    }

    @Test("federalTax: zero income returns 0")
    func federalTaxZeroIncome() {
        let tax = TaxCalculator.federalTax(taxableIncome: 0, filingStatus: .single)
        #expect(tax == 0)
    }

    @Test("federalTax: negative income returns 0")
    func federalTaxNegativeIncome() {
        let tax = TaxCalculator.federalTax(taxableIncome: -50_000, filingStatus: .single)
        #expect(tax == 0)
    }

    @Test("federalTax: married joint $100K")
    func federalTax100KMarriedJoint() {
        // 10% on first $23,850 = $2,385.00
        // 12% on $23,850–$96,950 = $8,772.00
        // 22% on $96,950–$100,000 = $671.00
        // Total = $11,828.00
        let tax = TaxCalculator.federalTax(
            taxableIncome: 100_000,
            filingStatus: .marriedJoint
        )
        let taxDouble = NSDecimalNumber(decimal: tax).doubleValue
        #expect(abs(taxDouble - 11_828.0) < 1)
    }

    // MARK: - taxRates

    @Test("taxRates: $100K single marginal is 22%")
    func taxRatesMarginal() {
        let rates = TaxCalculator.taxRates(
            taxableIncome: 100_000,
            filingStatus: .single
        )
        #expect(rates.marginal == Decimal(string: "0.22")!)
    }

    @Test("taxRates: effective rate is less than marginal")
    func taxRatesEffectiveLessThanMarginal() {
        let rates = TaxCalculator.taxRates(
            taxableIncome: 100_000,
            filingStatus: .single
        )
        #expect(rates.effective < rates.marginal)
        #expect(rates.effective > 0)
    }

    @Test("taxRates: zero income returns zero rates")
    func taxRatesZeroIncome() {
        let rates = TaxCalculator.taxRates(taxableIncome: 0, filingStatus: .single)
        #expect(rates.marginal == 0)
        #expect(rates.effective == 0)
    }

    // MARK: - capitalGainsTax

    @Test("capitalGainsTax: short-term taxed as ordinary income")
    func capitalGainsShortTerm() {
        let tax = TaxCalculator.capitalGainsTax(
            gains: 10_000,
            holdingPeriodMonths: 6,
            ordinaryIncome: 80_000,
            filingStatus: .single
        )
        // Short-term: taxed at ordinary income rates on top of $80K
        // $80K is in the 22% bracket, $10K more is still in the 22% bracket
        let taxDouble = NSDecimalNumber(decimal: tax).doubleValue
        #expect(taxDouble > 0)
        #expect(abs(taxDouble - 2_200) < 100) // approx 22% of $10K
    }

    @Test("capitalGainsTax: long-term uses 0/15/20% brackets")
    func capitalGainsLongTerm() {
        let tax = TaxCalculator.capitalGainsTax(
            gains: 10_000,
            holdingPeriodMonths: 12,
            ordinaryIncome: 80_000,
            filingStatus: .single
        )
        // $80K + $10K = $90K total income, above 15% LTCG threshold ($48,350)
        // All gains should be at 15%
        let taxDouble = NSDecimalNumber(decimal: tax).doubleValue
        #expect(abs(taxDouble - 1_500) < 100) // 15% of $10K
    }

    @Test("capitalGainsTax: long-term 0% for low income")
    func capitalGainsLongTermZeroRate() {
        let tax = TaxCalculator.capitalGainsTax(
            gains: 10_000,
            holdingPeriodMonths: 24,
            ordinaryIncome: 30_000,
            filingStatus: .single
        )
        // $30K + $10K = $40K total, below $48,350 threshold -> 0% rate
        #expect(tax == 0)
    }

    @Test("capitalGainsTax: zero gains returns 0")
    func capitalGainsZeroGains() {
        let tax = TaxCalculator.capitalGainsTax(
            gains: 0,
            holdingPeriodMonths: 12,
            ordinaryIncome: 80_000,
            filingStatus: .single
        )
        #expect(tax == 0)
    }

    // MARK: - rothConversionAnalysis

    @Test("rothConversionAnalysis: $50K conversion")
    func rothConversion50K() {
        let result = TaxCalculator.rothConversionAnalysis(
            conversionAmount: 50_000,
            currentTaxableIncome: 80_000,
            filingStatus: .single,
            yearsToRetirement: 20,
            expectedRetirementTaxRate: Decimal(string: "0.15")!
        )
        // Tax cost now = tax on $130K - tax on $80K
        #expect(result.taxCostNow > 0)
        // Projected savings = $50K * 0.15 = $7,500
        #expect(result.projectedTaxSavings == 7_500)
    }

    @Test("rothConversionAnalysis: zero conversion returns zeros")
    func rothConversionZero() {
        let result = TaxCalculator.rothConversionAnalysis(
            conversionAmount: 0,
            currentTaxableIncome: 80_000,
            filingStatus: .single,
            yearsToRetirement: 20,
            expectedRetirementTaxRate: Decimal(string: "0.15")!
        )
        #expect(result.taxCostNow == 0)
        #expect(result.projectedTaxSavings == 0)
        #expect(result.netBenefit == 0)
    }

    // MARK: - estimatedAnnualTax

    @Test("estimatedAnnualTax: combined sources")
    func estimatedAnnualTaxCombined() {
        let tax = TaxCalculator.estimatedAnnualTax(
            salary: 100_000,
            capitalGains: 20_000,
            dividends: 5_000,
            filingStatus: .single,
            deductions: 15_000
        )
        // Should be positive and include income tax + cap gains tax + dividend tax
        #expect(tax > 0)
        // Ordinary income = $85K
        let incomeTax = TaxCalculator.federalTax(taxableIncome: 85_000, filingStatus: .single)
        #expect(tax > incomeTax) // Should be more than just income tax
    }

    @Test("estimatedAnnualTax: salary only")
    func estimatedAnnualTaxSalaryOnly() {
        let tax = TaxCalculator.estimatedAnnualTax(
            salary: 75_000,
            capitalGains: 0,
            dividends: 0,
            filingStatus: .single,
            deductions: 15_000
        )
        let expectedIncomeTax = TaxCalculator.federalTax(
            taxableIncome: 60_000,
            filingStatus: .single
        )
        #expect(tax == expectedIncomeTax)
    }
}
