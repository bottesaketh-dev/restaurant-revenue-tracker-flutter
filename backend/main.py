from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import models
from database import engine

# Create DB tables if they don't exist
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Flavors Ledger API", version="1.0.0")

# CORS setup
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

from routers import (
    auth,
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
    users
)

app.include_router(auth.router)
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

@app.get("/")
def read_root():
    return {"message": "Welcome to Flavors Ledger API"}
