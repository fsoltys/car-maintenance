from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_current_user, get_db, get_current_user_id
from .schemas import (
    UserOut, 
    UserSettingsOut, 
    UserSettingsUpdate,
    UserProfileUpdate,
    PasswordChangeRequest,
)
from sqlalchemy.orm import Session
from sqlalchemy import text
from uuid import UUID
from sqlalchemy.exc import DBAPIError, DataError, IntegrityError
from app.core.security import verify_password, get_password_hash

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
def read_current_user(current_user: UserOut = Depends(get_current_user)) -> UserOut:
    """
    Zwraca dane aktualnie zalogowanego użytkownika.
    """
    return current_user


@router.patch("/me", response_model=UserOut)
def update_current_user_profile(
    payload: UserProfileUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> UserOut:
    """
    Zmiana danych profilu bieżącego użytkownika (bez hasła).
    Na ten moment: display_name.
    """
    data = payload.model_dump(exclude_unset=True)

    if not data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields provided to update.",
        )

    display_name = data.get("display_name")

    try:
        row = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_update_user_profile(
                    :user_id,
                    :display_name
                )
                """
            ),
            {
                "user_id": current_user_id,
                "display_name": display_name,
            },
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)

        if pgcode in ("23502", "23514"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid profile data or constraint violation.",
            ) from exc

        if pgcode == "40001":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Transaction conflict, please retry.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid profile data or constraint violation.",
        ) from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid profile input data.",
        ) from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while updating user profile.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    return UserOut.model_validate(row)

@router.patch("/me/password", status_code=status.HTTP_204_NO_CONTENT)
def change_my_password(
    payload: PasswordChangeRequest,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    """
    Zmiana hasła bieżącego użytkownika:
    - wymaga podania starego hasła (old_password),
    - ustawione zostaje nowe hasło (new_password) po stronie bazy.
    """
    try:
        row = db.execute(
            text(
                "SELECT password_hash FROM users WHERE id = :id"
            ),
            {"id": current_user_id},
        ).mappings().first()
    except DataError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user identifier.",
        ) from exc
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while fetching current password.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    current_hash = row["password_hash"]

    if not verify_password(payload.old_password, current_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid current password.",
        )

    new_hash = get_password_hash(payload.new_password)

    try:
        result = db.execute(
            text(
                """
                SELECT car_app.fn_update_user_password(
                    :user_id,
                    :password_hash
                ) AS updated
                """
            ),
            {
                "user_id": current_user_id,
                "password_hash": new_hash,
            },
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)

        if pgcode in ("23502", "23514"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid password data or constraint violation.",
            ) from exc

        if pgcode == "40001":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Transaction conflict, please retry.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid password data or constraint violation.",
        ) from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid password input data.",
        ) from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while updating password.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if not result or not result["updated"]:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Password not updated.",
        )

    return None
