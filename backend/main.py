from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
import models
from database import engine

# Create DB tables if they don't exist
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="IOR 360 API", version="1.0.0")

# CORS setup — configurable via ALLOWED_ORIGINS env var (comma-separated)
allowed_origins = os.getenv("ALLOWED_ORIGINS", "").split(",")
allowed_origins = [o for o in allowed_origins if o]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins if allowed_origins else ["http://localhost"],
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:[0-9]+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from routers import (
    auth,
    restaurants,
    menu,
    staff,
    expenses,
    billing,
    branches,
    chat,
    groceries,
    kitchen,
    home,
    reports,
    users,
    support
)

app.include_router(auth.router)
app.include_router(restaurants.router)
app.include_router(users.router)
app.include_router(branches.router)
app.include_router(home.router)
app.include_router(menu.router)
app.include_router(staff.router)
app.include_router(expenses.router)
app.include_router(billing.router)
app.include_router(chat.router)
app.include_router(groceries.router)
app.include_router(kitchen.router)
app.include_router(reports.router)
app.include_router(support.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to IOR 360 API"}

@app.get("/health")
@app.get("/api/v1/health")
def health_check():
    return {
        "status": "healthy",
        "app": "IOR 360 API",
        "version": "2.4.0",
        "database": "SQLite local.db",
        "mode": "multi-tenant"
    }
