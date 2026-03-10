"""Tests for plaid_service — Plaid API interactions with mocked SDK."""

from __future__ import annotations

import os
import uuid
from unittest.mock import MagicMock

import pytest

os.environ.setdefault("JWT_SECRET", "test-secret-not-for-production")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

from app.services.plaid_service import PlaidService


@pytest.fixture
def plaid_service() -> PlaidService:
    """Create a PlaidService with mocked Plaid API client."""
    service = PlaidService(
        client_id="test-client-id",
        secret="test-secret",
        environment="sandbox",
    )
    return service


class TestCreateLinkToken:
    """Tests for create_link_token."""

    def test_returns_link_token_string(self, plaid_service: PlaidService) -> None:
        """create_link_token should return a link_token string."""
        mock_response = MagicMock()
        mock_response.link_token = "link-sandbox-abc123"

        plaid_service._client.link_token_create = MagicMock(
            return_value=mock_response
        )
        result = plaid_service.create_link_token(uuid.uuid4())
        assert result == "link-sandbox-abc123"

    def test_passes_user_id_to_plaid(self, plaid_service: PlaidService) -> None:
        """create_link_token should pass user_id as client_user_id."""
        mock_response = MagicMock()
        mock_response.link_token = "link-sandbox-abc123"

        plaid_service._client.link_token_create = MagicMock(
            return_value=mock_response
        )
        user_id = uuid.uuid4()
        plaid_service.create_link_token(user_id)
        call_args = plaid_service._client.link_token_create.call_args
        request = call_args[0][0]
        assert request.user.client_user_id == str(user_id)


class TestExchangePublicToken:
    """Tests for exchange_public_token."""

    def test_returns_access_token_and_item_id(
        self, plaid_service: PlaidService
    ) -> None:
        """exchange_public_token should return (access_token, item_id)."""
        mock_response = MagicMock()
        mock_response.access_token = "access-sandbox-xyz789"
        mock_response.item_id = "item-sandbox-abc"

        plaid_service._client.item_public_token_exchange = MagicMock(
            return_value=mock_response
        )
        access_token, item_id = plaid_service.exchange_public_token(
            "public-sandbox-123"
        )
        assert access_token == "access-sandbox-xyz789"
        assert item_id == "item-sandbox-abc"


class TestSyncTransactions:
    """Tests for sync_transactions."""

    def test_returns_transaction_data(self, plaid_service: PlaidService) -> None:
        """sync_transactions should return added/modified/removed + cursor."""
        mock_added = MagicMock()
        mock_added.to_dict.return_value = {"transaction_id": "tx1", "amount": 42.0}

        mock_response = MagicMock()
        mock_response.added = [mock_added]
        mock_response.modified = []
        mock_response.removed = []
        mock_response.next_cursor = "cursor-next"
        mock_response.has_more = False

        plaid_service._client.transactions_sync = MagicMock(
            return_value=mock_response
        )
        result = plaid_service.sync_transactions("access-token-123", cursor=None)
        assert len(result["added"]) == 1
        assert result["next_cursor"] == "cursor-next"
        assert result["has_more"] is False

    def test_passes_cursor_when_provided(self, plaid_service: PlaidService) -> None:
        """sync_transactions should pass cursor to Plaid API."""
        mock_response = MagicMock()
        mock_response.added = []
        mock_response.modified = []
        mock_response.removed = []
        mock_response.next_cursor = "cursor-next-2"
        mock_response.has_more = False

        plaid_service._client.transactions_sync = MagicMock(
            return_value=mock_response
        )
        plaid_service.sync_transactions("access-token", cursor="cursor-1")
        call_args = plaid_service._client.transactions_sync.call_args
        request = call_args[0][0]
        assert request.cursor == "cursor-1"


class TestGetAccounts:
    """Tests for get_accounts."""

    def test_returns_account_list(self, plaid_service: PlaidService) -> None:
        """get_accounts should return a list of account dicts."""
        mock_acct = MagicMock()
        mock_acct.to_dict.return_value = {
            "account_id": "acct1",
            "name": "Checking",
            "balances": {"current": 1000.0},
        }

        mock_response = MagicMock()
        mock_response.accounts = [mock_acct]

        plaid_service._client.accounts_balance_get = MagicMock(
            return_value=mock_response
        )
        result = plaid_service.get_accounts("access-token-123")
        assert len(result) == 1
        assert result[0]["account_id"] == "acct1"

    def test_returns_multiple_accounts(self, plaid_service: PlaidService) -> None:
        """get_accounts should return multiple account dicts."""
        mock_accts = []
        for i in range(3):
            acct = MagicMock()
            acct.to_dict.return_value = {
                "account_id": f"acct{i}",
                "name": f"Account {i}",
                "balances": {"current": 1000.0 * (i + 1)},
            }
            mock_accts.append(acct)

        mock_response = MagicMock()
        mock_response.accounts = mock_accts

        plaid_service._client.accounts_balance_get = MagicMock(
            return_value=mock_response
        )
        result = plaid_service.get_accounts("access-token-123")
        assert len(result) == 3
        assert result[2]["account_id"] == "acct2"

    def test_returns_empty_list_when_no_accounts(
        self, plaid_service: PlaidService
    ) -> None:
        """get_accounts should return an empty list when Plaid has no accounts."""
        mock_response = MagicMock()
        mock_response.accounts = []

        plaid_service._client.accounts_balance_get = MagicMock(
            return_value=mock_response
        )
        result = plaid_service.get_accounts("access-token-123")
        assert result == []


class TestSyncTransactionsAdvanced:
    """Additional tests for sync_transactions edge cases."""

    def test_handles_modified_transactions(self, plaid_service: PlaidService) -> None:
        """sync_transactions returns modified transactions."""
        mock_modified = MagicMock()
        mock_modified.to_dict.return_value = {
            "transaction_id": "tx-mod-1",
            "amount": 55.0,
        }

        mock_response = MagicMock()
        mock_response.added = []
        mock_response.modified = [mock_modified]
        mock_response.removed = []
        mock_response.next_cursor = "cursor-mod"
        mock_response.has_more = False

        plaid_service._client.transactions_sync = MagicMock(
            return_value=mock_response
        )
        result = plaid_service.sync_transactions("access-token", cursor="prev")
        assert len(result["modified"]) == 1
        assert result["modified"][0]["transaction_id"] == "tx-mod-1"
        assert len(result["added"]) == 0

    def test_handles_removed_transactions(self, plaid_service: PlaidService) -> None:
        """sync_transactions returns removed transaction IDs."""
        mock_removed = MagicMock()
        mock_removed.to_dict.return_value = {"transaction_id": "tx-rm-1"}

        mock_response = MagicMock()
        mock_response.added = []
        mock_response.modified = []
        mock_response.removed = [mock_removed]
        mock_response.next_cursor = "cursor-rm"
        mock_response.has_more = False

        plaid_service._client.transactions_sync = MagicMock(
            return_value=mock_response
        )
        result = plaid_service.sync_transactions("access-token", cursor="prev")
        assert len(result["removed"]) == 1

    def test_has_more_flag(self, plaid_service: PlaidService) -> None:
        """sync_transactions reports has_more=True when there are more pages."""
        mock_response = MagicMock()
        mock_response.added = []
        mock_response.modified = []
        mock_response.removed = []
        mock_response.next_cursor = "cursor-paged"
        mock_response.has_more = True

        plaid_service._client.transactions_sync = MagicMock(
            return_value=mock_response
        )
        result = plaid_service.sync_transactions("access-token")
        assert result["has_more"] is True
        assert result["next_cursor"] == "cursor-paged"

    def test_empty_cursor_sends_empty_string(
        self, plaid_service: PlaidService
    ) -> None:
        """sync_transactions with cursor=None sends empty string to Plaid."""
        mock_response = MagicMock()
        mock_response.added = []
        mock_response.modified = []
        mock_response.removed = []
        mock_response.next_cursor = "first-cursor"
        mock_response.has_more = False

        plaid_service._client.transactions_sync = MagicMock(
            return_value=mock_response
        )
        plaid_service.sync_transactions("access-token", cursor=None)
        call_args = plaid_service._client.transactions_sync.call_args
        request = call_args[0][0]
        assert request.cursor == ""


class TestPlaidServiceErrorHandling:
    """Tests for Plaid API error propagation."""

    def test_link_token_api_error_propagates(
        self, plaid_service: PlaidService
    ) -> None:
        """Plaid API errors from link_token_create propagate to caller."""
        plaid_service._client.link_token_create = MagicMock(
            side_effect=Exception("Plaid API error")
        )
        with pytest.raises(Exception, match="Plaid API error"):
            plaid_service.create_link_token(uuid.uuid4())

    def test_exchange_token_api_error_propagates(
        self, plaid_service: PlaidService
    ) -> None:
        """Plaid API errors from item_public_token_exchange propagate to caller."""
        plaid_service._client.item_public_token_exchange = MagicMock(
            side_effect=Exception("Exchange failed")
        )
        with pytest.raises(Exception, match="Exchange failed"):
            plaid_service.exchange_public_token("bad-token")

    def test_sync_transactions_api_error_propagates(
        self, plaid_service: PlaidService
    ) -> None:
        """Plaid API errors from transactions_sync propagate to caller."""
        plaid_service._client.transactions_sync = MagicMock(
            side_effect=Exception("Sync failed")
        )
        with pytest.raises(Exception, match="Sync failed"):
            plaid_service.sync_transactions("access-token")

    def test_get_accounts_api_error_propagates(
        self, plaid_service: PlaidService
    ) -> None:
        """Plaid API errors from accounts_balance_get propagate to caller."""
        plaid_service._client.accounts_balance_get = MagicMock(
            side_effect=Exception("Balance fetch failed")
        )
        with pytest.raises(Exception, match="Balance fetch failed"):
            plaid_service.get_accounts("access-token")
