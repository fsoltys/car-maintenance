from __future__ import annotations

from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, DataError, DBAPIError

from app.api.deps import get_db, get_current_user_id
from .schemas import DocumentCreate, DocumentOut, DocumentUpdate


router = APIRouter(tags=["documents"])


@router.get(
    "/vehicles/{vehicle_id}/documents",
    response_model=List[DocumentOut],
)
def list_vehicle_documents(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[DocumentOut]:
    """
    Lista dokumentów pojazdu.
    """
    existing = db.execute(
        text("SELECT * FROM car_app.fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found or no permission")

    try:
        rows = db.execute(
            text("SELECT * FROM car_app.fn_get_vehicle_documents(:actor_id, :vehicle_id)"),
            {"actor_id": current_user_id, "vehicle_id": vehicle_id},
        ).mappings().all()
    except DBAPIError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while listing documents.") from exc
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    return [DocumentOut.model_validate(row) for row in rows]


@router.post(
    "/vehicles/{vehicle_id}/documents",
    response_model=DocumentOut,
    status_code=status.HTTP_201_CREATED,
)
def create_document(
    vehicle_id: UUID,
    payload: DocumentCreate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> DocumentOut:
    """
    Dodaje opis dokumentu do pojazdu (bez przechowywania plików).
    """
    params = {
        "actor_id": current_user_id,
        "vehicle_id": vehicle_id,
        "doc_type": payload.doc_type.value,
        "number": payload.number,
        "provider": payload.provider,
        "issue_date": payload.issue_date,
        "valid_from": payload.valid_from,
        "valid_to": payload.valid_to,
        "note": payload.note,
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_create_document(:actor_id, :vehicle_id, :doc_type, :number, :provider, :issue_date, :valid_from, :valid_to, :note)"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        if pgcode == "23505":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Duplicate document or unique constraint violation.") from exc
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while creating document.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while creating document.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found or no permission")

    return DocumentOut.model_validate(row)


@router.patch("/documents/{document_id}", response_model=DocumentOut)
def update_document(
    document_id: UUID,
    payload: DocumentUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> DocumentOut:
    """
    Aktualizuje metadane dokumentu (tylko tekstowe pola).
    """
    # pobierz istniejący wiersz i sprawdź uprawnienia w funkcji DB
    patch = payload.model_dump(exclude_unset=True)

    params = {
        "actor_id": current_user_id,
        "document_id": document_id,
        "doc_type": patch.get("doc_type", None).value if patch.get("doc_type", None) is not None else None,
        "number": patch.get("number", None),
        "provider": patch.get("provider", None),
        "issue_date": patch.get("issue_date", None),
        "valid_from": patch.get("valid_from", None),
        "valid_to": patch.get("valid_to", None),
        "note": patch.get("note", None),
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_update_document(:actor_id, :document_id, :doc_type, :number, :provider, :issue_date, :valid_from, :valid_to, :note)"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while updating document.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while updating document.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found or no permission")

    return DocumentOut.model_validate(row)


@router.delete(
    "/documents/{document_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_document(
    document_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    """
    Usuwa wpis dokumentu.
    """
    try:
        result = db.execute(
            text("SELECT car_app.fn_delete_document(:actor_id, :document_id) AS deleted"),
            {"actor_id": current_user_id, "document_id": document_id},
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while deleting document.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while deleting document.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if not result or not result["deleted"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found or no permission")

    return None
