from collections.abc import Generator
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.core.security import decode_access_token
from app.api.users.schemas import TokenPayload, UserOut


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user_id(
    token: str = Depends(oauth2_scheme),
) -> UUID:
    """
    Zwraca UUID użytkownika wyciągnięty z JWT.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = decode_access_token(token)
        token_data = TokenPayload(**payload)
    except JWTError:
        raise credentials_exception

    if token_data.sub is None:
        raise credentials_exception

    try:
        user_id = UUID(token_data.sub)
    except ValueError:
        raise credentials_exception

    return user_id


def get_current_user(
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> UserOut:
    """
    Zwraca profil aktualnego użytkownika
    """
    row = db.execute(
        text("SELECT * FROM fn_get_user_profile(:user_id)"),
        {"user_id": current_user_id},
    ).mappings().first()

    if row is None:
        # Token poprawny, ale user nie istnieje w DB → traktujemy jak 401
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return UserOut.model_validate(row)
