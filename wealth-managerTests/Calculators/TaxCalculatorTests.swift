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

    // MARK: - iraContributionLimit

    @Test("iraContributionLimit: age 40 returns $7,000 base limit")
    func iraContributionLimitAge40() {
        let limit = TaxCalculator.iraContributionLimit(age: 40, year: 2025)
        #expect(limit == 7_000)
    }

    @Test("iraContributionLimit: age 55 returns $8,000 with catch-up")
    func iraContributionLimitAge55() {
        let limit = TaxCalculator.iraContributionLimit(age: 55, year: 2025)
        #expect(limit == 8_000)
    }

    @Test("iraContributionLimit: age 50 exactly returns $8,000 catch-up threshold")
    func iraContributionLimitAge50() {
        let limit = TaxCalculator.iraContributionLimit(age: 50, year: 2025)
        #expect(limit == 8_000)
    }

    @Test("iraContributionLimit: age 49 returns $7,000 no catch-up")
    func iraContributionLimitAge49() {
        let limit = TaxCalculator.iraContributionLimit(age: 49, year: 2025)
        #expect(limit == 7_000)
    }

    // MARK: - backdoorRothEligible

    @Test("backdoorRothEligible: single $200K income returns true (backdoor needed)")
    func backdoorRothEligibleSingleHighIncome() {
        let eligible = TaxCalculator.backdoorRothEligible(
            modifiedAGI: 200_000,
            filingStatus: .single
        )
        #expect(eligible == true)
    }

    @Test("backdoorRothEligible: single $100K income returns false (direct contribution ok)")
    func backdoorRothEligibleSingleLowIncome() {
        let eligible = TaxCalculator.backdoorRothEligible(
            modifiedAGI: 100_000,
            filingStatus: .single
        )
        #expect(eligible == false)
    }

    @Test("backdoorRothEligible: married joint $250K returns true (above $246K phase-out)")
    func backdoorRothEligibleMFJHighIncome() {
        let eligible = TaxCalculator.backdoorRothEligible(
            modifiedAGI: 250_000,
            filingStatus: .marriedJoint
        )
        #expect(eligible == true)
    }

    @Test("backdoorRothEligible: married joint $200K returns false (below $236K phase-out start)")
    func backdoorRothEligibleMFJLowIncome() {
        let eligible = TaxCalculator.backdoorRothEligible(
            modifiedAGI: 200_000,
            filingStatus: .marriedJoint
        )
        #expect(eligible == false)
    }

    // MARK: - rothConversionOpportunity

    @Test("rothConversionOpportunity: low bracket taxpayer has conversion room")
    func rothConversionOpportunityLowBracket() {
        // $40K income is in the 12% bracket (up to $48,475 for single)
        // Room = $48,475 - $40,000 = $8,475
        let result = TaxCalculator.rothConversionOpportunity(
            currentTaxableIncome: 40_000,
            filingStatus: .single,
            traditionalIRABalance: 50_000
        )
        #expect(result.suggestedConversionAmount > 0)
        #expect(result.marginalRate == Decimal(string: "0.12")!)
    }

    @Test("rothConversionOpportunity: high bracket taxpayer returns 0 conversion")
    func rothConversionOpportunityHighBracket() {
        // $120K income is in the 22% bracket for single
        let result = TaxCalculator.rothConversionOpportunity(
            currentTaxableIncome: 120_000,
            filingStatus: .single,
            traditionalIRABalance: 100_000
        )
        #expect(result.suggestedConversionAmount == 0)
        #expect(!result.reason.isEmpty)
    }

    @Test("rothConversionOpportunity: conversion capped at IRA balance")
    func rothConversionOpportunityCapAtBalance() {
        // $10K income in 10% bracket (room up to $11,925), but IRA balance only $500
        let result = TaxCalculator.rothConversionOpportunity(
            currentTaxableIncome: 10_000,
            filingStatus: .single,
            traditionalIRABalance: 500
        )
        #expect(result.suggestedConversionAmount <= 500)
    }

    // MARK: - standardDeduction

    @Test("standardDeduction: single filer 2025 is $15,000")
    func standardDeductionSingle() {
        let deduction = TaxCalculator.standardDeduction(filingStatus: .single, year: 2025)
        #expect(deduction == 15_000)
    }

    @Test("standardDeduction: married filing jointly 2025 is $30,000")
    func standardDeductionMFJ() {
        let deduction = TaxCalculator.standardDeduction(filingStatus: .marriedJoint, year: 2025)
        #expect(deduction == 30_000)
    }

    @Test("standardDeduction: married filing separately 2025 is $15,000")
    func standardDeductionMFS() {
        let deduction = TaxCalculator.standardDeduction(filingStatus: .marriedSeparate, year: 2025)
        #expect(deduction == 15_000)
    }

    @Test("standardDeduction: head of household 2025 is $22,500")
    func standardDeductionHOH() {
        let deduction = TaxCalculator.standardDeduction(filingStatus: .headOfHousehold, year: 2025)
        #expect(deduction == 22_500)
    }
}
