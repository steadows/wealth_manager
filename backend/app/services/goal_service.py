"""Goal service — business logic for financial goals."""

import uuid
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.goal import FinancialGoal
from app.repositories.goal_repository import GoalRepository
from app.schemas.goal import GoalCreate


class GoalService:
    """Service layer for financial goal operations."""

    def __init__(self, session: AsyncSession) -> None:
        self._repo = GoalRepository(session)

    async def create_goal(self, user_id: uuid.UUID, data: GoalCreate) -> FinancialGoal:
        """Create a new financial goal for a user.

        Args:
            user_id: The authenticated user's UUID.
            data: Validated goal creation payload.

        Returns:
            The persisted FinancialGoal instance.
        """
        now = datetime.now(UTC)
        goal = FinancialGoal(
            id=uuid.uuid4(),
            user_id=user_id,
            goal_name=data.goal_name,
            goal_type=data.goal_type.value,
            target_amount=data.target_amount,
            current_amount=data.current_amount,
            target_date=data.target_date,
            monthly_contribution=data.monthly_contribution,
            priority=data.priority.value,
            is_active=data.is_active,
            notes=data.notes,
            created_at=now,
            updated_at=now,
        )
        return await self._repo.create(goal)
