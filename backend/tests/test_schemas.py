"""Tests for Pydantic schema validation across all request/response models."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.models.enums import AccountType
from app.schemas.account import AccountCreate, AccountResponse, AccountUpdate
from app.schemas.auth import LoginRequest, LoginResponse, TokenResponse, UserResponse
from app.schemas.common import APIResponse, ErrorResponse, PaginatedResponse
from app.schemas.debt import DebtCreate, DebtUpdate
from app.schemas.goal import GoalCreate, GoalUpdate
from app.schemas.holding import HoldingCreate
from app.schemas.plaid import PlaidExchangeRequest, PlaidLinkResponse
from app.schemas.snapshot import SnapshotCreate
from app.schemas.sync import ClientChanges, SyncResponse, SyncResult
from app.schemas.transaction import TransactionCreate, TransactionUpdate


class TestAccountSchemas:
    """Validation tests for AccountCreate, AccountUpdate, AccountResponse."""

    def test_account_create_valid(self) -> None:
        """AccountCreate accepts valid data with required fields."""
        data = AccountCreate(
            institution_name="Test Bank",
            account_name="Checking",
            account_type=AccountType.CHECKING,
            current_balance=Decimal("5000.00"),
        )
        assert data.institution_name == "Test Bank"
        assert data.is_manual is True  # default
        assert data.currency == "USD"  # default

    def test_account_create_missing_institution(self) -> None:
        """AccountCreate rejects missing institution_name."""
        with pytest.raises(ValidationError) as exc_info:
            AccountCreate(
                account_name="Check",
                account_type=AccountType.CHECKING,
                current_balance=Decimal("100"),
            )
        assert "institution_name" in str(exc_info.value)

    def test_account_create_missing_account_name(self) -> None:
        """AccountCreate rejects missing account_name."""
        with pytest.raises(ValidationError):
            AccountCreate(
                institution_name="Bank",
                account_type=AccountType.CHECKING,
                current_balance=Decimal("100"),
            )

    def test_account_create_missing_balance(self) -> None:
        """AccountCreate rejects missing current_balance."""
        with pytest.raises(ValidationError):
            AccountCreate(
                institution_name="Bank",
                account_name="Acct",
                account_type=AccountType.CHECKING,
            )

    def test_account_create_negative_balance(self) -> None:
        """AccountCreate allows negative balances (overdraft)."""
        data = AccountCreate(
            institution_name="Bank",
            account_name="Overdraft",
            account_type=AccountType.CHECKING,
            current_balance=Decimal("-250.50"),
        )
        assert data.current_balance == Decimal("-250.50")

    def test_account_create_very_large_balance(self) -> None:
        """AccountCreate accepts very large monetary values."""
        data = AccountCreate(
            institution_name="Trust",
            account_name="Big Account",
            account_type=AccountType.SAVINGS,
            current_balance=Decimal("999999999999999.9999"),
        )
        assert data.current_balance == Decimal("999999999999999.9999")

    def test_account_create_zero_balance(self) -> None:
        """AccountCreate accepts zero balance."""
        data = AccountCreate(
            institution_name="Bank",
            account_name="Empty",
            account_type=AccountType.SAVINGS,
            current_balance=Decimal("0"),
        )
        assert data.current_balance == Decimal("0")

    def test_account_update_partial(self) -> None:
        """AccountUpdate allows partial updates (all fields optional)."""
        data = AccountUpdate(account_name="New Name")
        assert data.account_name == "New Name"
        assert data.institution_name is None
        assert data.current_balance is None

    def test_account_update_empty(self) -> None:
        """AccountUpdate accepts empty payload (no changes)."""
        data = AccountUpdate()
        assert data.model_dump(exclude_none=True) == {}

    def test_account_response_from_attributes(self) -> None:
        """AccountResponse can be created from ORM-like attributes."""

        class FakeAccount:
            id = uuid.uuid4()
            plaid_account_id = None
            institution_name = "Bank"
            account_name = "Checking"
            account_type = "checking"
            current_balance = Decimal("5000.00")
            available_balance = None
            currency = "USD"
            is_manual = True
            is_hidden = False
            last_synced_at = None
            created_at = datetime.now(UTC)
            updated_at = datetime.now(UTC)

        resp = AccountResponse.model_validate(FakeAccount(), from_attributes=True)
        assert resp.institution_name == "Bank"
        assert resp.is_hidden is False


class TestDebtSchemas:
    """Validation tests for DebtCreate, DebtUpdate, DebtResponse."""

    def test_debt_create_valid(self) -> None:
        """DebtCreate accepts valid required fields."""
        data = DebtCreate(
            debt_name="Car Loan",
            debt_type="auto",
            original_balance=Decimal("25000.00"),
            current_balance=Decimal("15000.00"),
            interest_rate=Decimal("0.05"),
            minimum_payment=Decimal("450.00"),
            is_fixed_rate=True,
        )
        assert data.debt_name == "Car Loan"
        assert data.account_id is None

    def test_debt_create_missing_name(self) -> None:
        """DebtCreate rejects missing debt_name."""
        with pytest.raises(ValidationError):
            DebtCreate(
                debt_type="auto",
                original_balance=Decimal("25000.00"),
                current_balance=Decimal("15000.00"),
                interest_rate=Decimal("0.05"),
                minimum_payment=Decimal("450.00"),
                is_fixed_rate=True,
            )

    def test_debt_create_zero_interest(self) -> None:
        """DebtCreate accepts zero interest rate (0% APR promo)."""
        data = DebtCreate(
            debt_name="Promo Card",
            debt_type="creditCard",
            original_balance=Decimal("3000.00"),
            current_balance=Decimal("3000.00"),
            interest_rate=Decimal("0.00"),
            minimum_payment=Decimal("50.00"),
            is_fixed_rate=True,
        )
        assert data.interest_rate == Decimal("0.00")

    def test_debt_update_partial(self) -> None:
        """DebtUpdate allows partial field updates."""
        data = DebtUpdate(current_balance=Decimal("12000.00"))
        assert data.current_balance == Decimal("12000.00")
        assert data.debt_name is None


class TestGoalSchemas:
    """Validation tests for GoalCreate, GoalUpdate, GoalResponse."""

    def test_goal_create_valid(self) -> None:
        """GoalCreate accepts valid required fields."""
        data = GoalCreate(
            goal_name="Emergency Fund",
            goal_type="emergencyFund",
            target_amount=Decimal("20000.00"),
            priority=1,
        )
        assert data.current_amount == Decimal("0")  # default
        assert data.is_active is True  # default

    def test_goal_create_missing_priority(self) -> None:
        """GoalCreate rejects missing priority."""
        with pytest.raises(ValidationError):
            GoalCreate(
                goal_name="No Priority",
                goal_type="custom",
                target_amount=Decimal("5000.00"),
            )

    def test_goal_create_with_notes(self) -> None:
        """GoalCreate accepts optional notes field."""
        data = GoalCreate(
            goal_name="Travel",
            goal_type="travel",
            target_amount=Decimal("3000.00"),
            priority=2,
            notes="Summer vacation fund",
        )
        assert data.notes == "Summer vacation fund"

    def test_goal_update_partial(self) -> None:
        """GoalUpdate allows partial updates."""
        data = GoalUpdate(current_amount=Decimal("7500.00"))
        assert data.goal_name is None


class TestTransactionSchemas:
    """Validation tests for TransactionCreate, TransactionUpdate."""

    def test_transaction_create_valid(self) -> None:
        """TransactionCreate accepts valid data."""
        acct_id = uuid.uuid4()
        data = TransactionCreate(
            account_id=acct_id,
            amount=Decimal("-42.50"),
            date=datetime.now(UTC),
            category="food",
        )
        assert data.account_id == acct_id
        assert data.is_recurring is False
        assert data.is_pending is False

    def test_transaction_create_missing_category(self) -> None:
        """TransactionCreate rejects missing category."""
        with pytest.raises(ValidationError):
            TransactionCreate(
                account_id=uuid.uuid4(),
                amount=Decimal("-10.00"),
                date=datetime.now(UTC),
            )

    def test_transaction_update_partial(self) -> None:
        """TransactionUpdate allows partial updates."""
        data = TransactionUpdate(amount=Decimal("-99.99"))
        assert data.category is None


class TestSnapshotSchemas:
    """Validation tests for SnapshotCreate, SnapshotResponse."""

    def test_snapshot_create_valid(self) -> None:
        """SnapshotCreate accepts valid data."""
        data = SnapshotCreate(
            date=datetime.now(UTC),
            total_assets=Decimal("100000.00"),
            total_liabilities=Decimal("30000.00"),
        )
        assert data.total_assets == Decimal("100000.00")

    def test_snapshot_create_missing_assets(self) -> None:
        """SnapshotCreate rejects missing total_assets."""
        with pytest.raises(ValidationError):
            SnapshotCreate(
                date=datetime.now(UTC),
                total_liabilities=Decimal("10000.00"),
            )


class TestHoldingSchemas:
    """Validation tests for HoldingCreate, HoldingUpdate."""

    def test_holding_create_valid(self) -> None:
        """HoldingCreate accepts valid data."""
        data = HoldingCreate(
            account_id=uuid.uuid4(),
            security_name="Apple Inc.",
            quantity=Decimal("10.00"),
            current_price=Decimal("175.00"),
            holding_type="stock",
            asset_class="usEquity",
        )
        assert data.ticker_symbol is None
        assert data.cost_basis is None

    def test_holding_create_missing_security_name(self) -> None:
        """HoldingCreate rejects missing security_name."""
        with pytest.raises(ValidationError):
            HoldingCreate(
                account_id=uuid.uuid4(),
                quantity=Decimal("10.00"),
                current_price=Decimal("175.00"),
                holding_type="stock",
                asset_class="usEquity",
            )


class TestAuthSchemas:
    """Validation tests for auth-related schemas."""

    def test_login_request_valid(self) -> None:
        """LoginRequest accepts a valid identity_token."""
        data = LoginRequest(identity_token="some-jwt-token")
        assert data.identity_token == "some-jwt-token"

    def test_login_request_missing_token(self) -> None:
        """LoginRequest rejects missing identity_token."""
        with pytest.raises(ValidationError):
            LoginRequest()

    def test_login_response_defaults(self) -> None:
        """LoginResponse defaults token_type to bearer."""
        data = LoginResponse(access_token="abc123")
        assert data.token_type == "bearer"

    def test_token_response_defaults(self) -> None:
        """TokenResponse defaults token_type to bearer."""
        data = TokenResponse(access_token="xyz789")
        assert data.token_type == "bearer"

    def test_user_response_optional_email(self) -> None:
        """UserResponse accepts None email."""

        class FakeUser:
            id = uuid.uuid4()
            email = None
            created_at = datetime.now(UTC)

        resp = UserResponse.model_validate(FakeUser(), from_attributes=True)
        assert resp.email is None


class TestPlaidSchemas:
    """Validation tests for Plaid-related schemas."""

    def test_plaid_exchange_request_valid(self) -> None:
        """PlaidExchangeRequest accepts a valid public_token."""
        data = PlaidExchangeRequest(public_token="public-sandbox-123")
        assert data.public_token == "public-sandbox-123"

    def test_plaid_exchange_request_missing_token(self) -> None:
        """PlaidExchangeRequest rejects missing public_token."""
        with pytest.raises(ValidationError):
            PlaidExchangeRequest()

    def test_plaid_link_response(self) -> None:
        """PlaidLinkResponse serializes link_token."""
        data = PlaidLinkResponse(link_token="link-sandbox-abc")
        assert data.link_token == "link-sandbox-abc"


class TestCommonSchemas:
    """Validation tests for APIResponse, PaginatedResponse, ErrorResponse."""

    def test_api_response_success_default(self) -> None:
        """APIResponse defaults success=True."""
        resp = APIResponse(data={"key": "value"})
        assert resp.success is True
        assert resp.error is None

    def test_api_response_with_error(self) -> None:
        """APIResponse can represent an error."""
        resp = APIResponse(success=False, data=None, error="Something went wrong")
        assert resp.success is False
        assert resp.error == "Something went wrong"

    def test_error_response_defaults(self) -> None:
        """ErrorResponse defaults success=False, data=None."""
        resp = ErrorResponse(error="Not found")
        assert resp.success is False
        assert resp.data is None
        assert resp.error == "Not found"

    def test_paginated_response(self) -> None:
        """PaginatedResponse includes pagination metadata."""
        resp = PaginatedResponse(
            data=["item1", "item2"],
            total=50,
            page=1,
            limit=10,
        )
        assert resp.success is True
        assert resp.total == 50
        assert len(resp.data) == 2


class TestSyncSchemas:
    """Validation tests for sync-related schemas."""

    def test_sync_response_defaults(self) -> None:
        """SyncResponse defaults to empty lists."""
        now = datetime.now(UTC)
        data = SyncResponse(synced_at=now)
        assert data.accounts == []
        assert data.transactions == []
        assert data.goals == []
        assert data.debts == []
        assert data.snapshots == []

    def test_client_changes_defaults(self) -> None:
        """ClientChanges defaults to empty lists."""
        data = ClientChanges()
        assert data.accounts == []
        assert data.goals == []
        assert data.debts == []

    def test_sync_result_defaults(self) -> None:
        """SyncResult defaults counts to 0."""
        now = datetime.now(UTC)
        data = SyncResult(synced_at=now)
        assert data.applied_accounts == 0
        assert data.applied_goals == 0
        assert data.applied_debts == 0

    def test_client_changes_with_account_data(self) -> None:
        """ClientChanges accepts valid AccountCreate items."""
        data = ClientChanges(
            accounts=[
                AccountCreate(
                    institution_name="Mobile Bank",
                    account_name="Mobile Checking",
                    account_type=AccountType.CHECKING,
                    current_balance=Decimal("3000.00"),
                )
            ],
        )
        assert len(data.accounts) == 1
        assert data.accounts[0].institution_name == "Mobile Bank"

    def test_sync_response_missing_synced_at(self) -> None:
        """SyncResponse requires synced_at."""
        with pytest.raises(ValidationError):
            SyncResponse()
