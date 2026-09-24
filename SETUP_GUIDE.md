# Flavors Ledger — Complete Beginner's Setup Guide

Welcome to the **Flavors Ledger (Restaurant Revenue Tracker)** project! 

This guide is written step-by-step so that **anyone**, even with no prior knowledge of this codebase or Flutter/FastAPI, can set up and run the entire application locally on Windows.

---

## Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Step 1: Install & Set Up Flutter SDK](#step-1-install--set-up-flutter-sdk)
4. [Step 2: Set Up the Frontend (Flutter Web)](#step-2-set-up-the-frontend-flutter-web)
5. [Step 3: Set Up the Backend (FastAPI Python)](#step-3-set-up-the-backend-fastapi-python)
6. [Step 4: Configure the Database & Environment (.env)](#step-4-configure-the-database--environment-env)
7. [Step 5: Initialize & Seed the Database](#step-5-initialize--seed-the-database)
8. [Step 6: Run the Application (Dual Terminal)](#step-6-run-the-application-dual-terminal)
9. [Default Login Credentials](#9-default-login-credentials)
10. [Troubleshooting & FAQs](#10-troubleshooting--faqs)

---

## 1. Architecture Overview

The system consists of two main parts:
* **Backend (`backend/`):** A Python FastAPI REST API server running on `http://localhost:8000`. Handles database operations, authentication, POS billing, inventory, and AI analytics.
* **Frontend (`frontend/`):** A Flutter cross-platform client running in **Google Chrome** on `http://localhost:3000`. Communicates with the FastAPI backend.

---

## 2. Prerequisites

Before starting, make sure you have the following installed on Windows:

| Requirement | Minimum Version | Download Link | Check Command |
| :--- | :--- | :--- | :--- |
| **Git** | 2.x+ | [git-scm.com](https://git-scm.com/) | `git --version` |
| **Python** | 3.11+ | [python.org](https://www.python.org/downloads/) | `python --version` |
| **Google Chrome** | Latest | [google.com/chrome](https://www.google.com/chrome/) | Browser installed |

---

## Step 1: Install & Set Up Flutter SDK

If you already have Flutter installed and `flutter doctor` runs cleanly, you can skip to [Step 2](#step-2-set-up-the-frontend-flutter-web).

### 1.1 Download Flutter
Open **PowerShell** and clone Flutter stable into a directory with plenty of space (e.g. `D:\flutter` or `C:\src\flutter`):
```powershell
git clone --depth 1 -b stable https://github.com/flutter/flutter.git D:\flutter
```

### 1.2 Add Flutter to your User PATH
Run this command in PowerShell to add Flutter permanently to your user environment:
```powershell
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";D:\flutter\bin", "User")
```

### 1.3 Verify Flutter
**Close your PowerShell window and open a new one**, then run:
```powershell
flutter doctor
```
> [!NOTE]
> On the first run, Flutter will automatically download the Dart SDK and engine components. Once complete, make sure **Flutter** and **Chrome** show a green checkmark `[√]`. (Android SDK and Visual Studio are optional if you are running on Web).

---

## Step 2: Set Up the Frontend (Flutter Web)

Platform runner files (like the `web/` folder) are excluded from version control. We regenerate them in one command.

1. Open PowerShell and navigate to the `frontend` folder:
   ```powershell
   cd c:\path\to\restaurant-revenue-tracker-flutter\frontend
   ```

2. Generate the Web platform runner:
   ```powershell
   flutter create . --platforms=web
   ```

3. Download and link all Flutter packages:
   ```powershell
   flutter pub get
   ```

---

## Step 3: Set Up the Backend (FastAPI Python)

1. Open PowerShell and navigate to the `backend` folder:
   ```powershell
   cd c:\path\to\restaurant-revenue-tracker-flutter\backend
   ```

2. Create an isolated Python virtual environment named `.venv`:
   ```powershell
   python -m venv .venv
   ```

3. Activate the virtual environment:
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```
   *(Your terminal prompt should now show `(.venv)` at the beginning)*.

   > [!TIP]
   > If PowerShell displays a script execution error (`Execution_Policies`), run:
   > `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` and retry.

4. Install the required dependencies:
   ```powershell
   pip install fastapi uvicorn "sqlalchemy>=2.0" "psycopg2-binary" "pydantic>=2" "pydantic-settings" passlib bcrypt PyJWT python-dotenv requests pandas matplotlib altair langchain langchain-community langchain-openai langgraph fpdf2
   ```

---

## Step 4: Configure the Database & Environment (.env)

In the `backend\` folder, create a file named `.env`.

Choose one of the two database options below depending on your setup:

### Option A: Local SQLite Database (Recommended for Quick Local Testing)
No external database installation needed! SQLite is built right into Python and works completely offline.

Create `backend\.env` with:
```dotenv
SECRET_KEY=dev_secret_key_restaurant_tracker_2026
DATABASE_URL=sqlite:///./restaurant.db
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://localhost
TAX_RATE=0.05
TIMEZONE=Asia/Kolkata
CURRENCY=INR
```

### Option B: Cloud PostgreSQL (Supabase / Neon / Render)
If connecting to Supabase or another PostgreSQL host:
```dotenv
SECRET_KEY=dev_secret_key_restaurant_tracker_2026
DATABASE_URL=postgresql://<user>:<password>@<host>:<port>/<dbname>
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://localhost
TAX_RATE=0.05
TIMEZONE=Asia/Kolkata
CURRENCY=INR
```

> [!WARNING]
> If using Supabase Free Tier: If your database is inactive, Supabase automatically pauses it. Log into [supabase.com/dashboard](https://supabase.com/dashboard) and click **"Restore project"** before connecting.

---

## Step 5: Initialize & Seed the Database

Before starting the server for the first time, initialize the database tables and create the default administrator account.

Inside the `backend\` folder (with `.venv` active), run:

```powershell
python -c "
import database, models, security

models.Base.metadata.create_all(bind=database.engine)
db = database.SessionLocal()
try:
    if not db.query(models.Branch).first():
        b1 = models.Branch(name='Main Branch', address='Hitech City, Hyderabad', phone='+919876543210', is_active=True)
        db.add(b1)
        db.commit()
        db.refresh(b1)

        admin = models.User(
            username='super_admin',
            email='admin@hydrest.com',
            password_hash=security.get_password_hash('admin123'),
            role='ADMIN',
            branch_id=b1.branch_id,
            is_active=True,
            access_level='FULL'
        )
        db.add(admin)

        for i in range(1, 6):
            db.add(models.RestaurantTable(table_id=f'T{i}', capacity=4, status='AVAILABLE', branch_id=b1.branch_id, is_active=True))

        items = [
            models.MenuItem(name='Hyderabadi Chicken Biryani', description='Signature Biryani', category='Biryani', price=320.0, is_vegetarian=False, is_available=True, branch_id=b1.branch_id),
            models.MenuItem(name='Paneer Butter Masala', description='Rich cottage cheese curry', category='Curries', price=260.0, is_vegetarian=True, is_available=True, branch_id=b1.branch_id),
            models.MenuItem(name='Butter Naan', description='Tandoor baked bread', category='Breads', price=45.0, is_vegetarian=True, is_available=True, branch_id=b1.branch_id),
            models.MenuItem(name='Gulab Jamun', description='Sweet dessert', category='Desserts', price=90.0, is_vegetarian=True, is_available=True, branch_id=b1.branch_id),
        ]
        db.add_all(items)
        db.commit()
        print('Database tables created and sample data seeded successfully!')
    else:
        print('Database already contains records.')
finally:
    db.close()
"
```

---

## Step 6: Run the Application (Dual Terminal)

To run the full stack, you need **two terminal windows**:

### Terminal 1: Backend Server (FastAPI)
```powershell
cd backend
.\.venv\Scripts\Activate.ps1
uvicorn main:app --port 8000 --reload
```
* **API Home:** [http://localhost:8000](http://localhost:8000)
* **Interactive API Docs (Swagger):** [http://localhost:8000/docs](http://localhost:8000/docs)

---

### Terminal 2: Frontend App (Flutter Web)
Open a new PowerShell window:
```powershell
cd frontend
flutter run -d chrome --web-port 3000
```
* Google Chrome will open automatically at **[http://localhost:3000](http://localhost:3000)**.
* Interactive keys in this terminal:
  * Press **`r`** for Hot Reload (instant UI updates).
  * Press **`R`** for Hot Restart (resets app state).
  * Press **`q`** to quit.

---

## 9. Default Login Credentials

Use these credentials on the login screen (`/login`):

| Field | Value |
| :--- | :--- |
| **Email or Username** | `admin@hydrest.com` *(or `super_admin`)* |
| **Password** | `admin123` |
| **Role** | `ADMIN` (Super Administrator with full access to all features) |

Once logged in, you can access:
* **POS & Billing:** Create Dine-in or Takeaway orders and generate receipts.
* **Menu Catalog:** View and manage dishes, prices, and categories.
* **Kitchen Order Ticket (KOT):** View live kitchen queue.
* **Groceries & Inventory:** Track raw supplies and stock levels.
* **Staff & Payroll:** Employee directory and compensation records.
* **Reports & Analytics:** Revenue KPIs, category distributions, and daily summaries.

---

## 10. Troubleshooting & FAQs

### Q: `flutter` is not recognized as an internal or external command
**Solution:** Ensure `D:\flutter\bin` (or wherever you cloned Flutter) is added to your User `PATH` environment variable. Close and reopen your terminal after updating PATH.

### Q: Supabase gives `FATAL: (ENOTFOUND) tenant/user ... not found`
**Solution:** Your Supabase project has gone into a paused state due to inactivity. Go to your [Supabase Dashboard](https://supabase.com/dashboard), open your project, and click **"Restore project"** (takes ~1-2 minutes). Alternatively, switch to SQLite in `.env` as shown in [Step 4](#step-4-configure-the-database--environment-env).

### Q: Port 8000 or Port 3000 is already in use
**Solution:**
* To change the backend port: Run `uvicorn main:app --port 8001 --reload` (remember to also update `frontend/lib/core/api_client.dart` with the new port).
* To change the frontend port: Run `flutter run -d chrome --web-port 3001`.
