from fastapi import FastAPI

from app.api.meta.routes import router as meta_router
from app.api.auth.routes import router as auth_router
from app.api.users.routes import router as users_router
from app.api.vehicles.routes import router as vehicles_router
from app.api.fuelings.routes import router as fuelings_router
from app.api.issues.routes import router as issues_router
from app.api.documents.routes import router as documents_router
from app.api.odometer_entries.routes import router as odometer_entries_router
from app.api.expenses.routes import router as expenses_router
from app.api.reminders.routes import router as reminders_router

app = FastAPI(
    title="Car Maintenance API",
    version="0.1.0",
)

app.include_router(meta_router)
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(vehicles_router)
app.include_router(fuelings_router)
app.include_router(issues_router)
app.include_router(documents_router)
app.include_router(odometer_entries_router)
app.include_router(expenses_router)
app.include_router(reminders_router)