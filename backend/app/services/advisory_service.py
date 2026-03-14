"""Advisory service — orchestrates AI analysis with financial context."""

from collections.abc import AsyncGenerator

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
    ) -> None:
        self._claude = claude_service
        self._prompts = prompt_manager

    async def chat(
        self,
        *,
        snapshot: UserFinancialSnapshot,
        user_message: str,
    ) -> AsyncGenerator[str, None]:
        """Stream a chat response with full financial context injected."""
        context = self._prompts.build_financial_context(snapshot)
        system_prompt = self._prompts.load_system_prompt("financial_advisor")
        full_system = f"{system_prompt}\n\nUser's Financial Data:\n{context}"

        async for chunk in self._claude.stream(full_system, user_message):
            yield chunk

    async def analyze_retirement(
        self,
        *,
        snapshot: UserFinancialSnapshot,
    ) -> RetirementAnalysis:
        """Generate a structured retirement analysis."""
        context = self._prompts.build_financial_context(snapshot)
        system_prompt = self._prompts.load_system_prompt("financial_advisor")
        user_message = f"Analyze my retirement readiness based on this data:\n{context}"

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
        context = self._prompts.build_financial_context(snapshot)
        system_prompt = self._prompts.load_system_prompt("tax_advisor")
        user_message = f"Analyze my tax optimization opportunities:\n{context}"

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
        context = self._prompts.build_financial_context(snapshot)
        system_prompt = self._prompts.load_system_prompt("debt_strategist")
        user_message = f"Analyze my debt situation and recommend a strategy:\n{context}"

        return await self._claude.structured_generate(
            system_prompt=system_prompt,
            user_message=user_message,
            output_schema=DebtAnalysis,
        )
