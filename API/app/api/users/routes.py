from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_current_user, get_db, get_current_user_id
from .schemas import UserOut, UserSettingsOut, UserSettingsUpdate
from sqlalchemy.orm import Session
from sqlalchemy import text
from uuid import UUID
from sqlalchemy.exc import DBAPIError, DataError, IntegrityError

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
def read_current_user(current_user: UserOut = Depends(get_current_user)) -> UserOut:
    """
    Zwraca dane aktualnie zalogowanego użytkownika.
    """
    return current_user

@router.get("/me/settings", response_model=UserSettingsOut)
def get_my_settings(
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> UserSettingsOut:
    """
    Pobranie ustawień bieżącego użytkownika.
    Jeśli ustawienia nie istnieją, są tworzone domyślne (unit_pref=METRIC).
    """
    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_get_user_settings(:user_id)"
            ),
            {"user_id": current_user_id},
        ).mappings().first()
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while fetching user settings.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        # teoretycznie nie powinno się zdarzyć, funkcja zawsze tworzy rekord
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User settings not found.",
        )

    return UserSettingsOut.model_validate(row)

@router.put("/me/settings", response_model=UserSettingsOut)
def update_my_settings(
    payload: UserSettingsUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> UserSettingsOut:
    """
    Zapis/aktualizacja ustawień bieżącego użytkownika:
    - unit_pref (METRIC/IMPERIAL) – wymagane
    - currency (opcjonalne 3-literowe)
    - timezone (opcjonalna strefa czasowa jako string)
    Cała twarda walidacja siedzi w fn_update_user_settings().
    """

    data = payload.model_dump()

    params = {
        "user_id": current_user_id,
        "unit_pref": data["unit_pref"].value,
        "currency": data.get("currency"),
        "timezone": data.get("timezone"),
    }

    try:
        row = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_update_user_settings(
                    :user_id,
                    :unit_pref,
                    :currency,
                    :timezone
                )
                """
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)

        if pgcode in ("23502", "23514"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid settings data or constraint violation.",
            ) from exc

        if pgcode == "40001":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Transaction conflict, please retry.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid settings data or constraint violation.",
        ) from exc
    except DataError as exc:
        db.rollback()
        # np. zły enum / currency nie ma długości 3, itp.
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid settings input data.",
        ) from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while updating user settings.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        # Teoretycznie nie powinno się zdarzyć – funkcja zawsze upsertuje.
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="User settings not updated.",
        )

    return UserSettingsOut.model_validate(row)
