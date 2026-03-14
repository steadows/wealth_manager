"""Plaid integration service using plaid-python SDK."""

from __future__ import annotations

import hashlib
import logging
import time
import uuid

import plaid
import jwt as pyjwt
from jwt.exceptions import PyJWTError
from plaid.api import plaid_api
from plaid.model.accounts_balance_get_request import AccountsBalanceGetRequest
from plaid.model.country_code import CountryCode
from plaid.model.item_public_token_exchange_request import (
    ItemPublicTokenExchangeRequest,
)
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.products import Products
from plaid.model.sandbox_item_fire_webhook_request import (
    SandboxItemFireWebhookRequest,
)
from plaid.model.sandbox_item_reset_login_request import (
    SandboxItemResetLoginRequest,
)
from plaid.model.sandbox_public_token_create_request import (
    SandboxPublicTokenCreateRequest,
)
from plaid.model.sandbox_public_token_create_request_options import (
    SandboxPublicTokenCreateRequestOptions,
)
from plaid.model.transactions_sync_request import TransactionsSyncRequest
from plaid.model.webhook_verification_key_get_request import (
    WebhookVerificationKeyGetRequest,
)

from app.config import get_settings

logger = logging.getLogger(__name__)

# Cache verification keys to avoid repeated API calls (key_id -> JWK dict)
_jwk_cache: dict[str, tuple[dict, float]] = {}
_JWK_CACHE_TTL_SECONDS = 3600  # 1 hour

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

    def sync_transactions(self, access_token: str, cursor: str | None = None) -> dict:
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
        webhook: str | None = None,
    ) -> str:
        """Create a sandbox public token without going through Link.

        Only works in the sandbox environment. Useful for integration
        testing the token exchange and sync flows end-to-end.

        Args:
            institution_id: Sandbox institution ID. Defaults to
                "ins_109508" (First Platypus Bank — all products).
            initial_products: Products to enable. Defaults to ["transactions"].
            webhook: Optional webhook URL to register on the sandbox item.
                Required if you plan to call fire_sandbox_webhook later.

        Returns:
            A public_token string ready for exchange.
        """
        products = [Products(p) for p in (initial_products or ["transactions"])]
        kwargs: dict = {
            "institution_id": institution_id,
            "initial_products": products,
        }
        if webhook:
            kwargs["options"] = SandboxPublicTokenCreateRequestOptions(
                webhook=webhook,
            )
        request = SandboxPublicTokenCreateRequest(**kwargs)
        response = self._client.sandbox_public_token_create(request)
        return response.public_token

    def fire_sandbox_webhook(
        self,
        access_token: str,
        webhook_code: str = "SYNC_UPDATES_AVAILABLE",
    ) -> dict:
        """Fire a sandbox webhook for testing. Only works in sandbox.

        Args:
            access_token: The Plaid access token for the item.
            webhook_code: The webhook code to fire. Defaults to
                "SYNC_UPDATES_AVAILABLE".

        Returns:
            Dict with webhook_fired status from the Plaid API response.
        """
        request = SandboxItemFireWebhookRequest(
            access_token=access_token,
            webhook_code=webhook_code,
        )
        response = self._client.sandbox_item_fire_webhook(request)
        return {"webhook_fired": response.webhook_fired}

    def reset_sandbox_login(self, access_token: str) -> dict:
        """Reset a sandbox item's login credentials. Only works in sandbox.

        Forces the item into an ITEM_LOGIN_REQUIRED error state,
        useful for testing the re-authentication flow.

        Args:
            access_token: The Plaid access token for the item.

        Returns:
            Dict with reset_login status (True on success).
        """
        request = SandboxItemResetLoginRequest(access_token=access_token)
        response = self._client.sandbox_item_reset_login(request)
        return {"reset_login": response.reset_login}

    def _get_verification_key(self, key_id: str) -> dict:
        """Fetch a Plaid webhook verification key by key_id, with caching.

        Args:
            key_id: The key ID from the JWT header.

        Returns:
            A JWK dict suitable for jose JWT verification.

        Raises:
            ValueError: If the key cannot be fetched.
        """
        now = time.time()
        cached = _jwk_cache.get(key_id)
        if cached and (now - cached[1]) < _JWK_CACHE_TTL_SECONDS:
            return cached[0]

        request = WebhookVerificationKeyGetRequest(key_id=key_id)
        response = self._client.webhook_verification_key_get(request)
        jwk = response.key.to_dict()
        _jwk_cache[key_id] = (jwk, now)
        return jwk

    def verify_webhook_body(self, body: bytes, plaid_verification_header: str) -> bool:
        """Verify a Plaid webhook request's signature.

        Plaid signs webhooks with a JWT in the Plaid-Verification header.
        The JWT contains a request_body_sha256 claim that must match the
        SHA-256 hash of the raw request body.

        Args:
            body: The raw request body bytes.
            plaid_verification_header: The value of the Plaid-Verification header.

        Returns:
            True if the signature is valid.

        Raises:
            ValueError: If verification fails for any reason.
        """
        try:
            # Decode JWT header to get key_id (kid)
            unverified_header = pyjwt.get_unverified_header(plaid_verification_header)
            key_id = unverified_header.get("kid")
            if not key_id:
                raise ValueError("Missing kid in JWT header")

            # Fetch the verification key from Plaid
            jwk = self._get_verification_key(key_id)

            # Verify the JWT signature (Plaid uses ES256)
            public_key = pyjwt.algorithms.ECAlgorithm.from_jwk(jwk)
            claims = pyjwt.decode(
                plaid_verification_header,
                public_key,
                algorithms=["ES256"],
            )

            # Verify the body hash
            expected_hash = claims.get("request_body_sha256")
            if not expected_hash:
                raise ValueError("Missing request_body_sha256 claim in JWT")

            actual_hash = hashlib.sha256(body).hexdigest()
            if actual_hash != expected_hash:
                raise ValueError("Request body hash mismatch")

            return True

        except PyJWTError as exc:
            raise ValueError(f"JWT verification failed: {exc}") from exc

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
