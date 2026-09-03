# Restaurant Revenue Tracker (Flavors Ledger)

A comprehensive restaurant management system built with a Flutter frontend and FastAPI Python backend. This application handles everything from Point-of-Sale (POS) operations, menu management, grocery/inventory tracking, expense logging, to staff and payroll management, with seamless multi-branch support.

## Architecture & Tech Stack

### Frontend
- **Framework:** Flutter 3.x
- **State Management:** Riverpod (via `flutter_riverpod`)
- **Navigation:** GoRouter
- **Networking:** Dio
- **Features:** Responsive design (Mobile & Desktop layouts), JWT authentication, multi-branch contextual filtering.

### Backend
- **Framework:** FastAPI (Python)
- **Database:** PostgreSQL
- **ORM:** SQLAlchemy (with async support)
- **Data Validation:** Pydantic
- **Authentication:** JWT (JSON Web Tokens) with Passlib for password hashing
- **Security:** Scoped API endpoints, role-based access control, branch-based data isolation.

## Key Features

1. **Multi-Branch Operations:** Centralized system capable of managing multiple restaurant branches. Data is isolated by branch, preventing cross-branch data leakage.
2. **Point of Sale (POS):** Manage Dine-in and Takeaway orders, table assignments, and cart checkouts. Features direct Kitchen Order Ticket (KOT) generation and automated billing.
3. **Menu Catalog:** Dynamic menu item management categorized by type, with instant availability toggles and veg/non-veg indicators.
4. **Inventory & Groceries:** Track raw material purchases, monitor stock levels in real-time, and automate bulk stock additions.
5. **Staff Directory & Payroll:** Employee onboarding, role assignment, and comprehensive monthly payroll processing with automated deductions and bonuses.
6. **Expense Tracking:** Monitor day-to-day operational expenses (utilities, maintenance, marketing) and track outgoing cash flows.
7. **Business Analytics (KPIs):** Generate detailed daily and monthly revenue reports, track top-selling items, and view profitability metrics.

## Getting Started

### Prerequisites
- **Flutter SDK:** 3.19.0 or higher
- **Python:** 3.10+ 
- **PostgreSQL:** 14+ 

### Backend Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```
2. **Create and activate a virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```
4. **Configure Database:**
   Ensure PostgreSQL is running. Create a database named `flavors_ledger`. Update the `DATABASE_URL` in your `.env` file.

5. **Initialize Database:**
   ```bash
   alembic upgrade head
   ```

6. **Run the server:**
   ```bash
   uvicorn main:app --reload --port 8000
   ```

### Frontend Setup

1. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```
2. **Get packages:**
   ```bash
   flutter pub get
   ```
3. **Configure API Endpoint:**
   By default, the app points to `http://127.0.0.1:8000`. Adjust the base URL in `lib/core/auth_provider.dart` or your Dio configuration if necessary.
4. **Run the app:**
   ```bash
   flutter run -d chrome  # For web
   # or
   flutter run            # For mobile/desktop
   ```

## Security & Best Practices
- **Explicit Branch Routing:** All data mutations (POST, PUT, DELETE) explicitly require a `branch_id` unless executed by an overarching Super Admin.
- **Frontend Safeguards:** UI controls (buttons, forms) dynamically disable themselves when viewing "All Branches" to prevent accidental cross-branch insertions.
- **Dependency Injection:** Database sessions are securely injected into routers using `Yield` to ensure immediate teardown after request completion.
- **Role Validations:** The API aggressively validates user roles and token signatures to prevent unauthorized vertical privilege escalation.
