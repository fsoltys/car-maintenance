from fastapi import FastAPI

from app.api.meta.routes import router as meta_router
from app.api.auth.routes import router as auth_router
from app.api.users.routes import router as users_router
from app.api.vehicles.routes import router as vehicles_router

app = FastAPI(
    title="Car Maintenance API",
    version="0.1.0",
)

app.include_router(meta_router)
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(vehicles_router)