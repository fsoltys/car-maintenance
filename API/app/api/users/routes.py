from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.api.users.schemas import UserOut

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
def read_current_user(current_user: UserOut = Depends(get_current_user)) -> UserOut:
    """
    Zwraca dane aktualnie zalogowanego użytkownika.
    """
    return current_user