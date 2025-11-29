from __future__ import annotations

from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.api.users.schemas import UserCreate, UserOut, Token
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
) -> UserOut:
    """
    Rejestracja nowego użytkownika.
    """
    user_id = uuid4()
    password_hash = get_password_hash(payload.password)

    try:
        db.execute(
            text(
                """
                SELECT fn_register_user(
                    :user_id,
                    :email,
                    :password_hash,
                    :display_name
                )
                """
            ),
            {
                "user_id": user_id,
                "email": payload.email,
                "password_hash": password_hash,
                "display_name": payload.display_name,
            },
        )
        db.commit()
    except Exception as exc:
        db.rollback()
        # na razie traktuje wszystkie błędy jako duplikat emaila
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not register user (possibly email already registered).",
        ) from exc

    # pobranie danych użytkownika do zwrotki
    row = db.execute(
        text("SELECT * FROM fn_get_user_profile(:user_id)"),
        {"user_id": user_id},
    ).mappings().first()

    if row is None:
        # teoretycznie nie powinno się zdarzyć
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="User created but profile not found.",
        )

    return UserOut.model_validate(row)


@router.post("/login", response_model=Token)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
) -> Token:
    """
    Logowanie użytkownika.
    """
    row = db.execute(
        text("SELECT * FROM fn_get_user_for_login(:email)"),
        {"email": form_data.username},
    ).mappings().first()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    password_hash: str = row["password_hash"]

    if not verify_password(form_data.password, password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    user_id = row["id"]
    access_token = create_access_token(subject=str(user_id))

    return Token(access_token=access_token)