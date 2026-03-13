"""Plaid sandbox integration tests — hit real Plaid sandbox API.

Run separately from fast unit tests:
    pytest tests/test_plaid_sandbox_integration.py -v -m integration
"""

from __future__ import annotations

from decimal import Decimal

import pytest

from app.routers.plaid import _map_plaid_account_type
from app.services.plaid_service import PlaidService

# ---------------------------------------------------------------------------
# Module-scoped fixtures — shared across all test classes
# ---------------------------------------------------------------------------

FIRST_PLATYPUS_BANK = "ins_109508"
FIRST_GINGHAM_CU = "ins_109509"


@pytest.fixture(scope="module")
def plaid_service() -> PlaidService:
    """Return a PlaidService pointed at the Plaid sandbox."""
    return PlaidService()


@pytest.fixture(scope="module")
def platypus_tokens(plaid_service: PlaidService) -> tuple[str, str]:
    """Create and exchange a sandbox token for First Platypus Bank.

    Returns:
        Tuple of (access_token, item_id).
    """
    public_token = plaid_service.create_sandbox_public_token(
        institution_id=FIRST_PLATYPUS_BANK,
    )
    access_token, item_id = plaid_service.exchange_public_token(public_token)
    return access_token, item_id


# ---------------------------------------------------------------------------
# P.1 — Full link-exchange flow
# ---------------------------------------------------------------------------


@pytest.mark.integration
class TestPlaidLinkExchange:
    """Verify the sandbox public-token create and exchange flow."""

    def test_create_sandbox_public_token(self, plaid_service: PlaidService) -> None:
        """Create a sandbox public token and verify it is a non-empty string."""
        token = plaid_service.create_sandbox_public_token(
            institution_id=FIRST_PLATYPUS_BANK,
        )
        assert isinstance(token, str)
        assert len(token) > 0

    def test_exchange_public_token(self, plaid_service: PlaidService) -> None:
        """Exchange a sandbox public token and verify access_token + item_id."""
        public_token = plaid_service.create_sandbox_public_token(
            institution_id=FIRST_PLATYPUS_BANK,
        )
        access_token, item_id = plaid_service.exchange_public_token(public_token)

        assert isinstance(access_token, str)
        assert len(access_token) > 0
        assert isinstance(item_id, str)
        assert len(item_id) > 0


# ---------------------------------------------------------------------------
# P.2 — Transaction sync round-trip
# ---------------------------------------------------------------------------


@pytest.mark.integration
class TestTransactionSync:
    """Verify transaction sync returns expected keys and supports pagination."""

    def test_sync_returns_expected_keys(
        self,
        plaid_service: PlaidService,
        platypus_tokens: tuple[str, str],
    ) -> None:
        """First sync call returns dict with required keys."""
        access_token, _ = platypus_tokens
        result = plaid_service.sync_transactions(access_token)

        expected_keys = {"added", "modified", "removed", "next_cursor", "has_more"}
        assert expected_keys == set(result.keys())

    def test_added_is_list(
        self,
        plaid_service: PlaidService,
        platypus_tokens: tuple[str, str],
    ) -> None:
        """Sandbox returns a list of added transactions."""
        access_token, _ = platypus_tokens
        result = plaid_service.sync_transactions(access_token)

        assert isinstance(result["added"], list)

    def test_pagination_with_cursor(
        self,
        plaid_service: PlaidService,
        platypus_tokens: tuple[str, str],
    ) -> None:
        """Calling sync repeatedly with cursors always returns a valid response.

        In the sandbox, the first sync may return an empty cursor if no
        transactions are immediately available. This test verifies that
        follow-up calls with any cursor (empty or not) return the
        correct response shape without errors.
        """
        access_token, _ = platypus_tokens

        # First call
        result = plaid_service.sync_transactions(access_token)
        cursor = result["next_cursor"]
        assert isinstance(cursor, str)

        # Follow-up call — pass the cursor even if empty; API should handle it
        result2 = plaid_service.sync_transactions(access_token, cursor=cursor)
        expected_keys = {"added", "modified", "removed", "next_cursor", "has_more"}
        assert expected_keys == set(result2.keys())
        assert isinstance(result2["added"], list)
        assert isinstance(result2["has_more"], bool)


# ---------------------------------------------------------------------------
# P.3 — Account balance fetch + type mapping
# ---------------------------------------------------------------------------


@pytest.mark.integration
class TestAccountBalances:
    """Verify account fetch, balance precision, and type mapping."""

    def test_get_accounts_count(
        self,
        plaid_service: PlaidService,
        platypus_tokens: tuple[str, str],
    ) -> None:
        """First Platypus Bank sandbox returns exactly 12 accounts."""
        access_token, _ = platypus_tokens
        accounts = plaid_service.get_accounts(access_token)

        assert len(accounts) == 12

    def test_balance_current_is_number(
        self,
        plaid_service: PlaidService,
        platypus_tokens: tuple[str, str],
    ) -> None:
        """Every account has a numeric current balance."""
        access_token, _ = platypus_tokens
        accounts = plaid_service.get_accounts(access_token)

        for acct in accounts:
            balances = acct.get("balances", {})
            current = balances.get("current")
            assert current is not None, f"Account {acct.get('name')} missing current balance"
            assert isinstance(current, (int, float)), (
                f"current balance is {type(current)}, expected number"
            )

    def test_account_type_mapping(
        self,
        plaid_service: PlaidService,
        platypus_tokens: tuple[str, str],
    ) -> None:
        """All Plaid account types map to a known AccountType value."""
        access_token, _ = platypus_tokens
        accounts = plaid_service.get_accounts(access_token)

        valid_types = {
            "checking", "savings", "creditCard", "investment",
            "loan", "retirement", "other",
        }
        for acct in accounts:
            mapped = _map_plaid_account_type(
                acct.get("type", "other"),
                acct.get("subtype"),
            )
            assert mapped in valid_types, (
                f"Unmapped type: type={acct.get('type')}, "
                f"subtype={acct.get('subtype')} -> {mapped}"
            )

    def test_decimal_precision(
        self,
        plaid_service: PlaidService,
        platypus_tokens: tuple[str, str],
    ) -> None:
        """Balance values convert to Decimal via str() without float artifacts."""
        access_token, _ = platypus_tokens
        accounts = plaid_service.get_accounts(access_token)

        for acct in accounts:
            current = acct["balances"]["current"]
            d = Decimal(str(current))
            # Round-trip: converting Decimal back to float and to str(Decimal)
            # should not introduce float noise like 0.30000000000000004
            assert str(d) == str(current), (
                f"Decimal precision issue: {current!r} -> {d}"
            )


# ---------------------------------------------------------------------------
# P.4 — Multi-institution isolation
# ---------------------------------------------------------------------------


@pytest.mark.integration
class TestMultiInstitution:
    """Verify two sandbox institutions produce distinct, isolated data."""

    def test_different_items(self, plaid_service: PlaidService) -> None:
        """Two institutions produce different item_ids."""
        pub1 = plaid_service.create_sandbox_public_token(
            institution_id=FIRST_PLATYPUS_BANK,
        )
        pub2 = plaid_service.create_sandbox_public_token(
            institution_id=FIRST_GINGHAM_CU,
        )
        _, item_id_1 = plaid_service.exchange_public_token(pub1)
        _, item_id_2 = plaid_service.exchange_public_token(pub2)

        assert item_id_1 != item_id_2

    def test_different_account_sets(self, plaid_service: PlaidService) -> None:
        """Two institutions return non-overlapping account ID sets."""
        pub1 = plaid_service.create_sandbox_public_token(
            institution_id=FIRST_PLATYPUS_BANK,
        )
        pub2 = plaid_service.create_sandbox_public_token(
            institution_id=FIRST_GINGHAM_CU,
        )
        at1, _ = plaid_service.exchange_public_token(pub1)
        at2, _ = plaid_service.exchange_public_token(pub2)

        accounts_1 = plaid_service.get_accounts(at1)
        accounts_2 = plaid_service.get_accounts(at2)

        ids_1 = {a["account_id"] for a in accounts_1}
        ids_2 = {a["account_id"] for a in accounts_2}

        assert ids_1.isdisjoint(ids_2), "Account IDs should not overlap across institutions"
        assert len(accounts_1) > 0
        assert len(accounts_2) > 0
