from __future__ import annotations

from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from jose import ExpiredSignatureError, JWTError
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, DBAPIError, DataError

from app.api.deps import get_db
from app.api.users.schemas import UserCreate, UserOut, Token, RefreshTokenRequest, TokenPayload
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
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
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        if pgcode == "23505":
            # duplicate key / unique violation 
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is already registered.",
            ) from exc
        # inne naruszenia integralności danych
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid data or constraint violation.",
        ) from exc
    except DBAPIError as exc:
        db.rollback()
        # DBAPIError 
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error during user registration.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
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
    try:
        row = db.execute(
            text("SELECT * FROM fn_get_user_for_login(:email)"),
            {"email": form_data.username},
        ).mappings().first()
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error during login.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="The user with the given email does not exist",
        )

    password_hash: str = row["password_hash"]

    if not verify_password(form_data.password, password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password",
        )

    user_id = row["id"]
    access_token = create_access_token(subject=str(user_id))
    refresh_token = create_refresh_token(user_id)

    return Token(
        access_token=access_token,
        token_type="bearer",
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=Token)
def refresh_access_token(
    payload: RefreshTokenRequest,
    db: Session = Depends(get_db),
) -> Token:
    """
    Odświeżenie access tokenu na podstawie refresh tokenu.

    - przyjmuje refresh_token w body (JSON),
    - weryfikuje podpis, datę ważności i typ tokenu,
    - sprawdza, czy użytkownik istnieje,
    - zwraca nowy access_token
    """
    raw_token = payload.refresh_token

    try:
        decoded = decode_token(raw_token)
    except ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired.",
        ) from exc
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token.",
        ) from exc

    token_type = decoded.get("type")
    if token_type != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type.",
        )

    sub = decoded.get("sub")
    if not sub:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload.",
        )

    try:
        user_id = UUID(sub)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token subject.",
        ) from exc

    try:
        row = db.execute(
            text("SELECT id FROM users WHERE id = :id"),
            {"id": user_id},
        ).mappings().first()
    except DataError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user identifier.",
        ) from exc
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while validating refresh token.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User no longer exists.",
        )

    new_access_token = create_access_token(str(user_id))

    return Token(
        access_token=new_access_token,
        token_type="bearer",
        refresh_token=raw_token,
    )
