from __future__ import annotations

from typing import List
from uuid import UUID
import json

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError, IntegrityError, DataError
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user_id
from .schemas import IssueCreate, IssueUpdate, IssueOut

router = APIRouter(prefix="", tags=["issues"])


@router.get("/vehicles/{vehicle_id}/issues", response_model=List[IssueOut])
def list_vehicle_issues(
    vehicle_id: UUID,
    status: str | None = None,
    priority: str | None = None,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[IssueOut]:
    """
    Lista usterek/todo dla pojazdu. Filtry opcjonalne: status, priority.
    """
    try:
        rows = db.execute(
            text(
                "SELECT * FROM car_app.fn_get_vehicle_issues(:user_id, :vehicle_id, :status, :priority)"
            ),
            {"user_id": current_user_id, "vehicle_id": vehicle_id, "status": status, "priority": priority},
        ).mappings().all()
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while listing vehicle issues.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if not rows:
        # brak dostępu albo brak pojazdu – celowo 404
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )

    return [IssueOut.model_validate(row) for row in rows]


@router.post("/vehicles/{vehicle_id}/issues", response_model=IssueOut, status_code=status.HTTP_201_CREATED)
def create_issue(
    vehicle_id: UUID,
    payload: IssueCreate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> IssueOut:
    """
    Dodanie usterki/todo do pojazdu.
    """
    params = {
        "user_id": current_user_id,
        "vehicle_id": vehicle_id,
        "title": payload.title,
        "description": payload.description,
        "priority": payload.priority.value,
        "status": payload.status.value,
        "error_codes": json.dumps(payload.error_codes or []),
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_create_issue(:user_id, :vehicle_id, :title, :description, :priority, :status, :error_codes::jsonb)"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        if pgcode == "23505":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Duplicate resource.") from exc
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while creating issue.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while creating issue.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found or no permission")

    return IssueOut.model_validate(row)


@router.patch("/issues/{issue_id}", response_model=IssueOut)
def update_issue(
    issue_id: UUID,
    payload: IssueUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> IssueOut:
    """
    Aktualizacja wybranych pól usterki.
    """
    patch = payload.model_dump(exclude_unset=True)
    params = {
        "user_id": current_user_id,
        "issue_id": issue_id,
        "title": patch.get("title"),
        "description": patch.get("description"),
        "priority": patch.get("priority").value if patch.get("priority") is not None else None,
        "status": patch.get("status").value if patch.get("status") is not None else None,
        "error_codes": json.dumps(patch.get("error_codes")) if patch.get("error_codes") is not None else None,
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_update_issue(:user_id, :issue_id, :title, :description, :priority, :status, :error_codes::jsonb)"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        if pgcode == "23505":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Duplicate or unique constraint violation.") from exc
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while updating issue.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Issue not found or no permission")

    return IssueOut.model_validate(row)


@router.delete("/issues/{issue_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_issue(
    issue_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    """
    Usunięcie usterki.
    """
    try:
        result = db.execute(
            text("SELECT car_app.fn_delete_issue(:user_id, :issue_id) AS deleted"),
            {"user_id": current_user_id, "issue_id": issue_id},
        ).mappings().first()
        db.commit()
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while deleting issue.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if not result or not result["deleted"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Issue not found or no permission")
