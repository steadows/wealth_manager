"""Financial goals CRUD endpoints."""

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.schemas.common import APIResponse
from app.schemas.goal import GoalCreate, GoalResponse
from app.services.goal_service import GoalService

router = APIRouter(prefix="/goals", tags=["goals"])


@router.post("/", response_model=APIResponse[GoalResponse], status_code=201)
async def create_goal(
    data: GoalCreate,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
) -> APIResponse[GoalResponse]:
    """Create a new financial goal for the authenticated user."""
    service = GoalService(db)
    goal = await service.create_goal(user_id, data)
    return APIResponse(data=GoalResponse.model_validate(goal))
