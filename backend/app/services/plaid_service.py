"""Plaid integration service using plaid-python SDK."""

from __future__ import annotations

import uuid

import plaid
from plaid.api import plaid_api
from plaid.model.accounts_balance_get_request import AccountsBalanceGetRequest
from plaid.model.country_code import CountryCode
from plaid.model.item_public_token_exchange_request import (
    ItemPublicTokenExchangeRequest,
)
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.products import Products
from plaid.model.sandbox_public_token_create_request import (
    SandboxPublicTokenCreateRequest,
)
from plaid.model.transactions_sync_request import TransactionsSyncRequest

from app.config import get_settings

_PLAID_ENV_MAP = {
    "sandbox": plaid.Environment.Sandbox,
    "production": plaid.Environment.Production,
}


class PlaidService:
    """Service for interacting with the Plaid API.

    Wraps plaid-python SDK calls for link token creation, token exchange,
    transaction sync, and account balance retrieval.
    """

    def __init__(
        self,
        client_id: str | None = None,
        secret: str | None = None,
        environment: str | None = None,
    ) -> None:
        """Initialize Plaid API client.

        Args:
            client_id: Plaid client ID. Defaults to settings value.
            secret: Plaid secret key. Defaults to settings value.
            environment: Plaid environment (sandbox/development/production).
        """
        settings = get_settings()
        cid = client_id or settings.plaid_client_id
        sec = secret or settings.plaid_active_secret
        env = environment or settings.plaid_env

        configuration = plaid.Configuration(
            host=_PLAID_ENV_MAP.get(env, plaid.Environment.Sandbox),
            api_key={"clientId": cid, "secret": sec},
        )
        api_client = plaid.ApiClient(configuration)
        self._client = plaid_api.PlaidApi(api_client)

    def create_link_token(self, user_id: uuid.UUID) -> str:
        """Create a Plaid Link token for the given user.

        Args:
            user_id: The authenticated user's UUID.

        Returns:
            A Plaid link_token string for initializing Link on the client.
        """
        request = LinkTokenCreateRequest(
            products=[Products("transactions")],
            client_name="Wealth Manager",
            country_codes=[CountryCode("US")],
            language="en",
            user=LinkTokenCreateRequestUser(client_user_id=str(user_id)),
        )
        response = self._client.link_token_create(request)
        return response.link_token

    def exchange_public_token(self, public_token: str) -> tuple[str, str]:
        """Exchange a Plaid public token for an access token.

        Args:
            public_token: The public_token from Plaid Link's onSuccess callback.

        Returns:
            Tuple of (access_token, item_id).
        """
        request = ItemPublicTokenExchangeRequest(public_token=public_token)
        response = self._client.item_public_token_exchange(request)
        return response.access_token, response.item_id

    def sync_transactions(
        self, access_token: str, cursor: str | None = None
    ) -> dict:
        """Sync transactions for an account using Plaid's transactions/sync.

        Args:
            access_token: The Plaid access token for the item.
            cursor: Optional cursor from a previous sync call.

        Returns:
            Dict with keys: added, modified, removed, next_cursor, has_more.
        """
        request = TransactionsSyncRequest(
            access_token=access_token,
            cursor=cursor or "",
        )
        response = self._client.transactions_sync(request)
        return {
            "added": [t.to_dict() for t in response.added],
            "modified": [t.to_dict() for t in response.modified],
            "removed": [r.to_dict() if hasattr(r, "to_dict") else r for r in response.removed],
            "next_cursor": response.next_cursor,
            "has_more": response.has_more,
        }

    def create_sandbox_public_token(
        self,
        institution_id: str = "ins_109508",
        initial_products: list[str] | None = None,
    ) -> str:
        """Create a sandbox public token without going through Link.

        Only works in the sandbox environment. Useful for integration
        testing the token exchange and sync flows end-to-end.

        Args:
            institution_id: Sandbox institution ID. Defaults to
                "ins_109508" (First Platypus Bank — all products).
            initial_products: Products to enable. Defaults to ["transactions"].

        Returns:
            A public_token string ready for exchange.
        """
        products = [Products(p) for p in (initial_products or ["transactions"])]
        request = SandboxPublicTokenCreateRequest(
            institution_id=institution_id,
            initial_products=products,
        )
        response = self._client.sandbox_public_token_create(request)
        return response.public_token

    def get_accounts(self, access_token: str) -> list[dict]:
        """Fetch account balances from Plaid.

        Args:
            access_token: The Plaid access token for the item.

        Returns:
            List of account dicts with balances.
        """
        request = AccountsBalanceGetRequest(access_token=access_token)
        response = self._client.accounts_balance_get(request)
        return [acct.to_dict() for acct in response.accounts]


def get_plaid_service() -> PlaidService:
    """Factory function returning a PlaidService instance.

    Used as a FastAPI dependency to allow easy mocking in tests.
    """
    return PlaidService()
