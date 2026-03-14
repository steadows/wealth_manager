"""Advisory service — orchestrates AI analysis with financial context."""

from collections.abc import AsyncGenerator

from app.config import Settings, get_settings
from app.schemas.advisory import (
    DebtAnalysis,
    RetirementAnalysis,
    TaxAnalysis,
    UserFinancialSnapshot,
)
from app.services.claude_service import ClaudeService
from app.services.prompt_manager import PromptManager


class AdvisoryService:
    """Orchestrates AI-powered financial advisory features."""

    def __init__(
        self,
        claude_service: ClaudeService,
        prompt_manager: PromptManager,
        settings: Settings | None = None,
    ) -> None:
        self._claude = claude_service
        self._prompts = prompt_manager
        self._settings = settings if settings is not None else get_settings()

    def _build_context(self, snapshot: UserFinancialSnapshot) -> str:
        """Return financial context text, anonymizing PII when configured."""
        if self._settings.anonymize_pii_for_ai:
            return self._prompts.build_financial_context(snapshot, anonymize=True)
        return self._prompts.build_financial_context(snapshot)

    async def chat(
        self,
        *,
        snapshot: UserFinancialSnapshot,
        user_message: str,
    ) -> AsyncGenerator[str, None]:
        """Stream a chat response with financial context injected via user message.

        The financial context is placed inside the user message (delimited by
        XML tags) rather than the system prompt.  This prevents an attacker
        who controls account/debt/goal names from injecting instructions into
        the privileged system-prompt position (CWE-74).
        """
        context = self._build_context(snapshot)
        system_prompt = self._prompts.load_system_prompt("financial_advisor")
        augmented_user_message = (
            f"<financial_data>\n{context}\n</financial_data>\n\n"
            f"<user_question>\n{user_message}\n</user_question>"
        )

        async for chunk in self._claude.stream(system_prompt, augmented_user_message):
            yield chunk

    async def analyze_retirement(
        self,
        *,
        snapshot: UserFinancialSnapshot,
    ) -> RetirementAnalysis:
        """Generate a structured retirement analysis."""
        context = self._build_context(snapshot)
        system_prompt = self._prompts.load_system_prompt("financial_advisor")
        user_message = (
            f"<financial_data>\n{context}\n</financial_data>\n\n"
            "<user_question>\n"
            "Analyze my retirement readiness based on the financial data above."
            "\n</user_question>"
        )

        return await self._claude.structured_generate(
            system_prompt=system_prompt,
            user_message=user_message,
            output_schema=RetirementAnalysis,
        )

    async def analyze_tax(
        self,
        *,
        snapshot: UserFinancialSnapshot,
    ) -> TaxAnalysis:
        """Generate a structured tax analysis."""
        context = self._build_context(snapshot)
        system_prompt = self._prompts.load_system_prompt("tax_advisor")
        user_message = (
            f"<financial_data>\n{context}\n</financial_data>\n\n"
            "<user_question>\n"
            "Analyze my tax optimization opportunities based on the financial data above."
            "\n</user_question>"
        )

        return await self._claude.structured_generate(
            system_prompt=system_prompt,
            user_message=user_message,
            output_schema=TaxAnalysis,
        )

    async def analyze_debt(
        self,
        *,
        snapshot: UserFinancialSnapshot,
    ) -> DebtAnalysis:
        """Generate a structured debt strategy analysis."""
        context = self._build_context(snapshot)
        system_prompt = self._prompts.load_system_prompt("debt_strategist")
        user_message = (
            f"<financial_data>\n{context}\n</financial_data>\n\n"
            "<user_question>\n"
            "Analyze my debt situation and recommend a strategy based on the financial data above."
            "\n</user_question>"
        )

        return await self._claude.structured_generate(
            system_prompt=system_prompt,
            user_message=user_message,
            output_schema=DebtAnalysis,
        )
