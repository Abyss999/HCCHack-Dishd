from fastapi import APIRouter, Depends, Request, Response

from config import get_settings
from deps import get_current_user
from models.user import User
from schemas.recommendation import RecommendationOut, RecommendationRequest
from security import limiter
from services.recommendation_service import (
    RecommendationService,
    get_recommendation_service,
)

router = APIRouter(prefix="/recommendations", tags=["recommendations"])
_settings = get_settings()


@router.post("", response_model=list[RecommendationOut])
@limiter.limit(_settings.rate_limit_restaurants)
async def recommend(
    request: Request,
    response: Response,
    body: RecommendationRequest,
    current: User = Depends(get_current_user),
    recs: RecommendationService = Depends(get_recommendation_service),
) -> list[RecommendationOut]:
    return await recs.top(body)
