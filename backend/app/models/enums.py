"""Python str enums matching Swift rawValues exactly (camelCase)."""

from enum import StrEnum


class AccountType(StrEnum):
    """Account classification matching Swift AccountType rawValues."""

    CHECKING = "checking"
    SAVINGS = "savings"
    CREDIT_CARD = "creditCard"
    INVESTMENT = "investment"
    LOAN = "loan"
    RETIREMENT = "retirement"
    OTHER = "other"


class TransactionCategory(StrEnum):
    """Transaction category matching Swift TransactionCategory rawValues."""

    INCOME = "income"
    HOUSING = "housing"
    TRANSPORTATION = "transportation"
    FOOD = "food"
    UTILITIES = "utilities"
    HEALTHCARE = "healthcare"
    ENTERTAINMENT = "entertainment"
    SHOPPING = "shopping"
    EDUCATION = "education"
    PERSONAL_CARE = "personalCare"
    TRAVEL = "travel"
    GIFTS = "gifts"
    FEES = "fees"
    TRANSFER = "transfer"
    OTHER = "other"


class GoalType(StrEnum):
    """Goal type matching Swift GoalType rawValues."""

    RETIREMENT = "retirement"
    EMERGENCY_FUND = "emergencyFund"
    HOME_PURCHASE = "homePurchase"
    DEBT_PAYOFF = "debtPayoff"
    EDUCATION = "education"
    TRAVEL = "travel"
    INVESTMENT = "investment"
    CUSTOM = "custom"


class DebtType(StrEnum):
    """Debt classification matching Swift DebtType rawValues."""

    MORTGAGE = "mortgage"
    AUTO = "auto"
    STUDENT = "student"
    CREDIT_CARD = "creditCard"
    PERSONAL = "personal"
    MEDICAL = "medical"
    OTHER = "other"


class HoldingType(StrEnum):
    """Investment holding type matching Swift HoldingType rawValues."""

    STOCK = "stock"
    BOND = "bond"
    ETF = "etf"
    MUTUAL_FUND = "mutualFund"
    CRYPTO = "crypto"
    CASH = "cash"
    REIT = "reit"
    OTHER = "other"


class AssetClass(StrEnum):
    """Asset class matching Swift AssetClass rawValues."""

    US_EQUITY = "usEquity"
    INTL_EQUITY = "intlEquity"
    FIXED_INCOME = "fixedIncome"
    REAL_ESTATE = "realEstate"
    COMMODITIES = "commodities"
    CASH = "cash"
    ALTERNATIVE = "alternative"


class FilingStatus(StrEnum):
    """Tax filing status matching Swift FilingStatus rawValues."""

    SINGLE = "single"
    MARRIED_JOINT = "marriedJoint"
    MARRIED_SEPARATE = "marriedSeparate"
    HEAD_OF_HOUSEHOLD = "headOfHousehold"


class RiskTolerance(StrEnum):
    """Investment risk tolerance matching Swift RiskTolerance rawValues."""

    CONSERVATIVE = "conservative"
    MODERATE = "moderate"
    AGGRESSIVE = "aggressive"
