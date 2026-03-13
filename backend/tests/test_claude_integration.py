"""Integration tests that hit the real Claude API.

These tests verify that ClaudeService correctly communicates with the
Anthropic Messages API.  They require a valid CLAUDE_API_KEY in the
environment (or .env.local).

Run selectively:
    pytest tests/test_claude_integration.py -v -m integration
"""

import os

import pytest
from pydantic import BaseModel

from app.config import Settings
from app.services.claude_service import ClaudeService

# Ensure required env vars are set so Settings() doesn't blow up in CI.
os.environ.setdefault("JWT_SECRET", "test-secret-not-for-production")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

SYSTEM_PROMPT = "You are a concise financial advisor. Keep answers brief."


@pytest.fixture(scope="module")
def claude_service() -> ClaudeService:
    """Create a single ClaudeService instance for the module."""
    settings = Settings()
    if not settings.claude_api_key:
        pytest.skip("CLAUDE_API_KEY not set — skipping integration tests")
    return ClaudeService(settings)


# ---------------------------------------------------------------------------
# P.10 — Advisory chat generates a response
# ---------------------------------------------------------------------------


@pytest.mark.integration
class TestClaudeGenerate:
    """Verify that generate() returns real content from the API."""

    async def test_generate_returns_nonempty_response(
        self, claude_service: ClaudeService
    ) -> None:
        """Call generate() with a simple financial question and assert meaningful content."""
        response = await claude_service.generate(
            system_prompt=SYSTEM_PROMPT,
            user_message="What is dollar cost averaging?",
            max_tokens=200,
        )

        assert isinstance(response, str)
        assert len(response) > 50, (
            f"Expected substantive response (>50 chars), got {len(response)} chars"
        )


# ---------------------------------------------------------------------------
# P.11 — Structured generate returns typed output
# ---------------------------------------------------------------------------


class FinancialTip(BaseModel):
    """Test schema for structured output."""

    title: str
    explanation: str
    risk_level: str


@pytest.mark.integration
class TestClaudeStructured:
    """Verify that structured_generate() returns a typed Pydantic instance."""

    async def test_structured_generate_returns_pydantic_model(
        self, claude_service: ClaudeService
    ) -> None:
        """Request a FinancialTip and validate all fields are populated."""
        result = await claude_service.structured_generate(
            system_prompt=SYSTEM_PROMPT,
            user_message="Give me one financial tip for a beginning investor.",
            output_schema=FinancialTip,
            max_tokens=200,
        )

        assert isinstance(result, FinancialTip)
        assert len(result.title) > 0, "title should be non-empty"
        assert len(result.explanation) > 0, "explanation should be non-empty"
        assert len(result.risk_level) > 0, "risk_level should be non-empty"


# ---------------------------------------------------------------------------
# P.12 — Streaming advisory works end-to-end
# ---------------------------------------------------------------------------


@pytest.mark.integration
class TestClaudeStreaming:
    """Verify that stream() yields multiple text chunks."""

    async def test_stream_yields_multiple_chunks(
        self, claude_service: ClaudeService
    ) -> None:
        """Collect streamed chunks and assert we got real, multi-chunk output."""
        chunks: list[str] = []
        async for chunk in claude_service.stream(
            system_prompt=SYSTEM_PROMPT,
            user_message="Explain compound interest in three sentences.",
            max_tokens=200,
        ):
            chunks.append(chunk)

        assert len(chunks) >= 3, (
            f"Expected at least 3 streamed chunks, got {len(chunks)}"
        )

        full_text = "".join(chunks)
        assert len(full_text) > 50, (
            f"Expected substantive streamed response (>50 chars), got {len(full_text)} chars"
        )
