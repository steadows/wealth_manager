"""Claude API service wrapper using the Anthropic Python SDK."""

from collections.abc import AsyncGenerator
from typing import TypeVar

from anthropic import AsyncAnthropic
from pydantic import BaseModel

from app.config import Settings

T = TypeVar("T", bound=BaseModel)

_DEFAULT_MODEL = "claude-sonnet-4-5"
_DEFAULT_MAX_TOKENS = 2000


class ClaudeService:
    """Async wrapper around the Anthropic Messages API."""

    def __init__(self, settings: Settings) -> None:
        self._client = AsyncAnthropic(api_key=settings.claude_api_key)
        self._model = getattr(settings, "claude_model", _DEFAULT_MODEL)

    async def generate(
        self,
        system_prompt: str,
        user_message: str,
        *,
        max_tokens: int = _DEFAULT_MAX_TOKENS,
    ) -> str:
        """Send a single message and return the full text response."""
        message = await self._client.messages.create(
            model=self._model,
            max_tokens=max_tokens,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        if not message.content:
            return ""
        return message.content[0].text

    async def stream(
        self,
        system_prompt: str,
        user_message: str,
        *,
        max_tokens: int = _DEFAULT_MAX_TOKENS,
    ) -> AsyncGenerator[str, None]:
        """Stream a response, yielding text chunks as they arrive."""
        async with self._client.messages.stream(
            model=self._model,
            max_tokens=max_tokens,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        ) as stream:
            async for text in stream.text_stream:
                yield text

    async def structured_generate(
        self,
        system_prompt: str,
        user_message: str,
        output_schema: type[T],
        *,
        max_tokens: int = _DEFAULT_MAX_TOKENS,
    ) -> T:
        """Generate a structured response parsed into a Pydantic model."""
        parsed = await self._client.messages.parse(
            model=self._model,
            max_tokens=max_tokens,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
            output_format=output_schema,
        )
        return parsed.parsed_output
