import Testing
import Foundation

@testable import wealth_manager

// MARK: - NetWorthWidgetData Tests

@Suite("NetWorthWidgetData")
struct NetWorthWidgetDataTests {

    @Test("netWorthDecimal parses valid string")
    func netWorthDecimalParsesValid() {
        let data = NetWorthWidgetData(
            netWorth: "250000.50",
            dailyChange: "1200.75",
            dailyChangePercent: "0.0048",
            isPositive: true,
            lastUpdated: Date()
        )

        #expect(data.netWorthDecimal == Decimal(string: "250000.50")!)
    }

    @Test("dailyChangeDecimal parses valid string")
    func dailyChangeDecimalParsesValid() {
        let data = NetWorthWidgetData(
            netWorth: "250000",
            dailyChange: "-500.25",
            dailyChangePercent: "-0.002",
            isPositive: false,
            lastUpdated: Date()
        )

        #expect(data.dailyChangeDecimal == Decimal(string: "-500.25")!)
    }

    @Test("dailyChangePercentDecimal parses valid string")
    func dailyChangePercentDecimalParsesValid() {
        let data = NetWorthWidgetData(
            netWorth: "100000",
            dailyChange: "234",
            dailyChangePercent: "0.00234",
            isPositive: true,
            lastUpdated: Date()
        )

        #expect(data.dailyChangePercentDecimal == Decimal(string: "0.00234")!)
    }

    @Test("decimal properties return zero for invalid strings")
    func decimalPropertiesReturnZeroForInvalid() {
        let data = NetWorthWidgetData(
            netWorth: "invalid",
            dailyChange: "nope",
            dailyChangePercent: "bad",
            isPositive: false,
            lastUpdated: Date()
        )

        #expect(data.netWorthDecimal == Decimal.zero)
        #expect(data.dailyChangeDecimal == Decimal.zero)
        #expect(data.dailyChangePercentDecimal == Decimal.zero)
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = NetWorthWidgetData(
            netWorth: "500000",
            dailyChange: "1500",
            dailyChangePercent: "0.003",
            isPositive: true,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(NetWorthWidgetData.self, from: encoded)

        #expect(decoded == original)
    }
}

// MARK: - HealthScoreWidgetData Tests

@Suite("HealthScoreWidgetData")
struct HealthScoreWidgetDataTests {

    @Test("scoreFraction converts score to 0-1 range")
    func scoreFractionConversion() {
        let data = HealthScoreWidgetData(
            overallScore: 85,
            scoreLabel: "Great",
            lastUpdated: Date()
        )

        #expect(data.scoreFraction == 0.85)
    }

    @Test("scoreFraction returns zero for score of 0")
    func scoreFractionZero() {
        let data = HealthScoreWidgetData(
            overallScore: 0,
            scoreLabel: "Needs Work",
            lastUpdated: Date()
        )

        #expect(data.scoreFraction == 0.0)
    }

    @Test("scoreFraction returns 1.0 for score of 100")
    func scoreFractionMax() {
        let data = HealthScoreWidgetData(
            overallScore: 100,
            scoreLabel: "Excellent",
            lastUpdated: Date()
        )

        #expect(data.scoreFraction == 1.0)
    }

    @Test("tierLabel returns Excellent for 90-100")
    func tierLabelExcellent() {
        #expect(HealthScoreWidgetData.tierLabel(for: 90) == "Excellent")
        #expect(HealthScoreWidgetData.tierLabel(for: 95) == "Excellent")
        #expect(HealthScoreWidgetData.tierLabel(for: 100) == "Excellent")
    }

    @Test("tierLabel returns Great for 75-89")
    func tierLabelGreat() {
        #expect(HealthScoreWidgetData.tierLabel(for: 75) == "Great")
        #expect(HealthScoreWidgetData.tierLabel(for: 89) == "Great")
    }

    @Test("tierLabel returns Good for 60-74")
    func tierLabelGood() {
        #expect(HealthScoreWidgetData.tierLabel(for: 60) == "Good")
        #expect(HealthScoreWidgetData.tierLabel(for: 74) == "Good")
    }

    @Test("tierLabel returns Fair for 40-59")
    func tierLabelFair() {
        #expect(HealthScoreWidgetData.tierLabel(for: 40) == "Fair")
        #expect(HealthScoreWidgetData.tierLabel(for: 59) == "Fair")
    }

    @Test("tierLabel returns Needs Work for 0-39")
    func tierLabelNeedsWork() {
        #expect(HealthScoreWidgetData.tierLabel(for: 0) == "Needs Work")
        #expect(HealthScoreWidgetData.tierLabel(for: 39) == "Needs Work")
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = HealthScoreWidgetData(
            overallScore: 78,
            scoreLabel: "Great",
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(HealthScoreWidgetData.self, from: encoded)

        #expect(decoded == original)
    }
}

// MARK: - MilestoneWidgetData Tests

@Suite("MilestoneWidgetData")
struct MilestoneWidgetDataTests {

    @Test("targetAmountDecimal parses valid string")
    func targetAmountParsesValid() {
        let data = makeMilestone(targetAmount: "50000")

        #expect(data.targetAmountDecimal == Decimal(string: "50000")!)
    }

    @Test("currentAmountDecimal parses valid string")
    func currentAmountParsesValid() {
        let data = makeMilestone(currentAmount: "12500")

        #expect(data.currentAmountDecimal == Decimal(string: "12500")!)
    }

    @Test("remainingDecimal computes correctly")
    func remainingDecimalComputation() {
        let data = makeMilestone(targetAmount: "50000", currentAmount: "12500")

        #expect(data.remainingDecimal == Decimal(string: "37500")!)
    }

    @Test("progressDouble converts string to Double")
    func progressDoubleConversion() {
        let data = makeMilestone(progressPercent: "0.25")

        #expect(data.progressDouble == 0.25)
    }

    @Test("progressDouble returns zero for invalid string")
    func progressDoubleInvalid() {
        let data = makeMilestone(progressPercent: "invalid")

        #expect(data.progressDouble == 0.0)
    }

    @Test("decimal properties return zero for invalid strings")
    func decimalPropertiesReturnZeroForInvalid() {
        let data = MilestoneWidgetData(
            goalName: "Test",
            goalTypeRawValue: "custom",
            targetAmount: "bad",
            currentAmount: "nope",
            progressPercent: "invalid",
            targetDate: nil,
            lastUpdated: Date()
        )

        #expect(data.targetAmountDecimal == Decimal.zero)
        #expect(data.currentAmountDecimal == Decimal.zero)
        #expect(data.remainingDecimal == Decimal.zero)
    }

    @Test("Codable round-trip preserves all fields including nil targetDate")
    func codableRoundTripNilDate() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = makeMilestone(targetDate: nil)

        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(MilestoneWidgetData.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("Codable round-trip preserves all fields including non-nil targetDate")
    func codableRoundTripWithDate() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = makeMilestone(
            targetDate: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(MilestoneWidgetData.self, from: encoded)

        #expect(decoded == original)
    }

    // MARK: - Factory

    private func makeMilestone(
        goalName: String = "Emergency Fund",
        goalTypeRawValue: String = "emergencyFund",
        targetAmount: String = "50000",
        currentAmount: String = "12500",
        progressPercent: String = "0.25",
        targetDate: Date? = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> MilestoneWidgetData {
        MilestoneWidgetData(
            goalName: goalName,
            goalTypeRawValue: goalTypeRawValue,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            progressPercent: progressPercent,
            targetDate: targetDate,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
