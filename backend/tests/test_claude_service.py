"""Tests for Claude API service wrapper (4.1)."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from pydantic import BaseModel


class SimpleResponse(BaseModel):
    """Simple Pydantic model for structured output tests."""

    title: str
    score: int


@pytest.fixture
def mock_settings():
    """Settings with a test API key."""
    settings = MagicMock()
    settings.claude_api_key = "test-key-not-real"
    settings.claude_model = "claude-sonnet-4-5"
    return settings


@pytest.mark.asyncio
class TestClaudeService:
    """Tests for ClaudeService."""

    async def test_init_creates_async_client(self, mock_settings):
        """Service should create an AsyncAnthropic client with the configured key."""
        with patch("app.services.claude_service.AsyncAnthropic") as mock_cls:
            from app.services.claude_service import ClaudeService

            service = ClaudeService(mock_settings)
            mock_cls.assert_called_once_with(api_key="test-key-not-real")
            assert service._client is not None

    async def test_generate_returns_text(self, mock_settings):
        """generate() should return the text content from Claude's response."""
        with patch("app.services.claude_service.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_cls.return_value = mock_client

            # Mock the response
            mock_message = MagicMock()
            mock_content_block = MagicMock()
            mock_content_block.text = "Here is my financial advice."
            mock_message.content = [mock_content_block]
            mock_client.messages.create = AsyncMock(return_value=mock_message)

            from app.services.claude_service import ClaudeService

            service = ClaudeService(mock_settings)
            result = await service.generate(
                system_prompt="You are a financial advisor.",
                user_message="What should I do with $10k?",
            )

            assert result == "Here is my financial advice."
            mock_client.messages.create.assert_called_once()
            call_kwargs = mock_client.messages.create.call_args.kwargs
            assert call_kwargs["model"] == "claude-sonnet-4-5"
            assert call_kwargs["system"] == "You are a financial advisor."

    async def test_generate_respects_max_tokens(self, mock_settings):
        """generate() should pass max_tokens to the API."""
        with patch("app.services.claude_service.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_cls.return_value = mock_client

            mock_message = MagicMock()
            mock_content_block = MagicMock()
            mock_content_block.text = "Short."
            mock_message.content = [mock_content_block]
            mock_client.messages.create = AsyncMock(return_value=mock_message)

            from app.services.claude_service import ClaudeService

            service = ClaudeService(mock_settings)
            await service.generate("sys", "msg", max_tokens=500)

            call_kwargs = mock_client.messages.create.call_args.kwargs
            assert call_kwargs["max_tokens"] == 500

    async def test_stream_yields_text_chunks(self, mock_settings):
        """stream() should yield text chunks from the streaming response."""
        with patch("app.services.claude_service.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_cls.return_value = mock_client

            # Mock the streaming context manager
            chunks = ["Hello", " world", "!"]

            async def mock_text_stream():
                for chunk in chunks:
                    yield chunk

            mock_stream = AsyncMock()
            mock_stream.text_stream = mock_text_stream()

            mock_stream_ctx = AsyncMock()
            mock_stream_ctx.__aenter__ = AsyncMock(return_value=mock_stream)
            mock_stream_ctx.__aexit__ = AsyncMock(return_value=False)
            mock_client.messages.stream = MagicMock(return_value=mock_stream_ctx)

            from app.services.claude_service import ClaudeService

            service = ClaudeService(mock_settings)
            collected = []
            async for text in service.stream("system", "message"):
                collected.append(text)

            assert collected == ["Hello", " world", "!"]

    async def test_structured_generate_returns_pydantic_model(self, mock_settings):
        """structured_generate() should return a typed Pydantic instance."""
        with patch("app.services.claude_service.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_cls.return_value = mock_client

            # Mock the parse response
            mock_parsed = MagicMock()
            mock_parsed.parsed_output = SimpleResponse(title="Test", score=85)
            mock_client.messages.parse = AsyncMock(return_value=mock_parsed)

            from app.services.claude_service import ClaudeService

            service = ClaudeService(mock_settings)
            result = await service.structured_generate(
                system_prompt="You are helpful.",
                user_message="Analyze this.",
                output_schema=SimpleResponse,
            )

            assert isinstance(result, SimpleResponse)
            assert result.title == "Test"
            assert result.score == 85
            call_kwargs = mock_client.messages.parse.call_args.kwargs
            assert call_kwargs["output_format"] is SimpleResponse

    async def test_generate_handles_empty_content(self, mock_settings):
        """generate() should handle empty content blocks gracefully."""
        with patch("app.services.claude_service.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_cls.return_value = mock_client

            mock_message = MagicMock()
            mock_message.content = []
            mock_client.messages.create = AsyncMock(return_value=mock_message)

            from app.services.claude_service import ClaudeService

            service = ClaudeService(mock_settings)
            result = await service.generate("sys", "msg")

            assert result == ""
