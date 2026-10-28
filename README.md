# IOR 360 — Indian Operations & Restaurant Management Platform

IOR 360 is an enterprise-grade, multi-tenant, and multi-branch Restaurant Operations, Revenue Tracking, and Point of Sale (POS) platform tailored specifically for Indian dining establishments, fine-dining restaurants, and multi-location food chains.

The platform unifies the full restaurant lifecycle: table management, Kitchen Order Tickets (KOT), split-tender checkout, hardware ESC/POS thermal receipt printing, recipe-driven Bill of Materials (BOM) inventory depletion, raw grocery procurement, staff payroll, expense tracking, multi-dimensional executive financial reports, and an AI-powered conversational SQL Command Center.

---

## 🏛️ System Architecture & Tech Stack

### Frontend (Flutter Client)
- **Framework:** Flutter 3.x (Dart 3.x) targeting Desktop (Windows), Web, and Mobile.
- **State Management:** Riverpod (`flutter_riverpod: ^2.6.1`) with reactive family notifiers and tenant-scoped caching.
- **Navigation & Routing:** GoRouter (`go_router: ^12.1.3`) supporting deep linking and query-parameter tab navigation (e.g. `/settings?tab=profile`).
- **HTTP Client:** Dio (`dio: ^5.7.0`) with global interceptors for JWT injection, session lifecycle, and `X-Restaurant-ID` context propagation.
- **Responsive Layout:** Adaptive desktop sidebar with collapsible navigation rail and mobile-friendly app bar.

### Backend (FastAPI Service)
- **Framework:** Python FastAPI (`fastapi: ^0.109.0`, `uvicorn: ^0.27.0`) exposing 90 OpenAPI operations across 69 endpoints.
- **ORM & Database:** SQLAlchemy 2.0 with declarative data models. Default development engine is SQLite (`backend/local.db`) with pluggable PostgreSQL support.
- **Validation:** Pydantic v2 schemas for request validation and response serialization.
- **Security & Cryptography:** Passlib (Bcrypt hashing), PyJWT (HS256 tokens), and multi-tenant row-level authorization middleware.
- **Hardware Integration:** Raw Windows Print Spooler driver (`winspool.drv` / `pywin32`) delivering native ESC/POS thermal printing to USB/network receipt printers.

---

## ✨ Core Features & Functional Modules

### 1. Executive Analytics & Dynamic KPI Dashboard (`/home`)
- **Real-Time Financial Telemetry:** Today's gross sales, net profit margins, daily operating cashflow, active dining tables, and pending KOTs.
- **Category Sales Breakdown:** Donut visualizations of revenue shares across food categories (Biryani, Starters, Curries, Beverages, Desserts).
- **Hourly Sales Curve:** Intra-day sales velocity comparing lunch and dinner rushes against 7-day trailing benchmarks.
- **Multi-Tenant Context Switching:** Super Admins can switch between organizations or view aggregated cross-organization analytics in real time.

### 2. Point of Sale (POS) Billing & Floor Management (`/pos`)
- **Interactive Floor Grid:** Real-time visual table status (`available`, `occupied`, `billed`) with dynamic capacity badges.
- **Order Staging & KOT Printing:** Fast cart item additions, quantity modifications, custom kitchen instructions, and instant Kitchen Order Ticket dispatch.
- **Flexible Bill Settlement:** Support for Cash, UPI / QR, Card, and Split-Tender settlements with automatic GST calculations (5%, 12%, 18%) and discretionary discounts.
- **Table Management Dialog:** Add, edit, or archive tables with bulk table generator capabilities.

### 3. Hardware Thermal Receipt Printing (ESC/POS Bridge)
- **Direct Windows Spooler Integration:** Communicates with 80mm and 58mm thermal printers via `winspool.drv` without requiring external spooler utilities.
- **ESC/POS Command Generation:** Hardware reset (`ESC @`), text alignment (`ESC a`), bold formatting (`ESC E`), and automatic paper cut (`GS V 66 0`).
- **Configurable Receipts:** Live thermal receipt preview in Settings with customizable restaurant header, branch address, GSTIN, phone, and footer greeting.

### 4. Restaurants & Branches Management (`/restaurants`, `/branches`)
- **Restaurants Tab:** Full CRUD operations for platform Super Admins. Create new restaurant brands, update brand slug, phone, and cuisine, or delete/deactivate organizations.
- **Branches Tab:** Full CRUD operations for branch locations. Configure branch address, contact numbers, active statuses, and link branches to parent restaurants.
- **Tenant Scope Enforcement:** Branch Managers and Restaurant Admins are restricted to their authorized organizational boundaries.

### 5. Centralized Role-Based Access Control (RBAC) (`/users`)
- **Granular Tab Permissions:** User tab access (including access to Restaurants and Branches tabs) is managed centrally from the Users tab without fragmented secondary access menus.
- **5 Tier Security Hierarchy:**
  - `SUPER_ADMIN`: Global platform access, tenant provisioning, cross-organization audits.
  - `RESTAURANT_ADMIN`: Complete control over a specific restaurant and its branches.
  - `BRANCH_MANAGER`: Scoped to an assigned branch outlet, operational ledgers, and staff attendance.
  - `CASHIER`: Fast-paced floor billing, order taking, bill reprint, and shift settlement.
  - `STAFF`: Waitstaff floor order taking and table status viewing.

### 6. Settings & Terminal Configuration (`/settings`)
- **5 Comprehensive Sub-Tabs:**
  - **Printer & Hardware:** Printer device selection, paper width (80mm / 58mm), auto-print on checkout toggle, and 1-click printer test.
  - **Receipt & Branding:** Header, address, GSTIN, footer tagline, and interactive monospace thermal preview.
  - **POS & Billing Rules:** Default GST rate, service charge %, currency format, and default tender type.
  - **My Profile:** User profile identity, role badge, assigned branch, and secure in-app password change form.
  - **System & Terminal:** Device telemetry, API health status, local database metrics, and client versioning.
- **Deep Linking Navigation:** Clicking the top-right profile avatar on any page navigates directly to `/settings?tab=profile`.

### 7. Operations Support Desk & System Diagnostics (`/support`)
- **Emergency Action Cards:** 24/7 Priority Phone Helpline, Instant WhatsApp Tech Dispatch, and Remote Desktop Assistance.
- **Interactive Ticket Desk:** Submit support tickets across categories (POS Billing, Thermal Printer, Kitchen Inventory, Staff & Payroll, Account Access) with real-time status badges (`open`, `in_progress`, `resolved`, `closed`).
- **Multi-Tenant Ticket Isolation:** Tickets are strictly isolated by tenant; switching users or restaurant context automatically clears and reloads tenant-specific tickets.
- **1-Click System Diagnostics Snapshot:** Formats client runtime, token session, active tenant, and hardware telemetry into an easily shareable support bundle.
- **Operations FAQs:** Searchable, categorized troubleshooting accordions for daily restaurant workflows.
- **POS Cashier Keyboard Shortcuts:** In-app cheat sheet for rapid keyboard navigation (`F1`, `F2`, `F4`, `F8`, `Ctrl+P`, `Ctrl+Enter`, `Esc`, `Alt+N`).

### 8. Kitchen Recipes & Closed-Loop Inventory (`/kitchen`)
- **Recipe Bill of Materials (BOM):** Define exact ingredient consumption formulas per dish (e.g. 250g Basmati Rice and 200g Chicken per Biryani).
- **Automated Inventory Depletion:** Settle a guest bill at POS, and backend database triggers instantly deduct ingredients from the branch raw stock balance.
- **Real-Time Stock Ledger:** Live inventory balance monitor with low-stock warnings and minimum threshold triggers.

### 9. Raw Materials Procurement & Groceries (`/groceries`)
- **Ingredient Catalog:** Manage raw materials categorized by Dairy, Meat & Poultry, Grains, Vegetables, Spices, and Packaging.
- **Procurement Vouchers:** Record supplier purchase orders with vendor names, invoice references, quantities, and purchase amounts.
- **Automatic Stock Replenishment:** Entering a grocery purchase automatically upserts the corresponding inventory stock balance.

### 10. Staff Directory & Payroll Processing (`/staff`)
- **Employee Roster:** Track full staff directory, roles (Chefs, Waiters, Captains, Cleaners), contact details, and base salary.
- **Monthly Wage Disbursement:** Calculate overtime bonuses, disciplinary deductions, and record salary disbursement receipts into the accounting ledger.

### 11. Operating Expense Management (`/expenses`)
- **OPEX Categorization:** Itemize daily expenses across Utilities (Electricity, Water, Gas), Maintenance, Marketing, Licences, and Miscellaneous.
- **Cash Outflow Ledger:** Keep an immutable audit trail of daily operational expenses for monthly P&L calculations.

### 12. Multi-Dimensional Financial Reports (`/reports`)
- **6 Analytical Pillars:**
  1. **Executive Summary:** Profit and Loss statement calculating Gross Revenue, Net Revenue, COGS, Gross Profit, OPEX, Labor Costs, and EBITDA.
  2. **Sales Engineering (BCG Matrix):** Classifies menu dishes into Stars, Plowhorses, Puzzles, and Dogs based on popularity and contribution margin.
  3. **Inventory & Supply Chain:** Consumption rates, stock turnover ratios, and waste shrinkage metrics.
  4. **Operations & Table Turn:** Average table dwell time, peak ordering hours, and cashier settlement latency.
  5. **Expenses & HR Ratios:** Labor cost as a percentage of gross sales and departmental cost breakdowns.
  6. **Branch Comparison:** Benchmarking revenue, order count, and average order value (AOV) across branch locations.
- **One-Click Data Export:** Export analytical reports to formatted PDF or raw CSV.

### 13. Conversational AI Command Center (`/ai`)
- **Natural Language to SQL:** Ask complex questions in plain English (e.g. *"Show top selling biryani items for Madhapur branch this month"*).
- **Tenant Isolation Guardrails:** The query engine dynamically injects `restaurant_id` constraints into generated SQL to strictly prevent cross-tenant queries.
- **Dynamic Charting:** Executes visual scripts to render responsive Altair data visualizations.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK:** Version 3.19.0 or higher ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Python:** Version 3.10+ (Recommended: Python 3.11)
- **Operating System:** Windows 10/11 (for native Win32 thermal printing), macOS, or Linux

---

### Backend Setup

1. **Navigate to the backend directory:**
   ```powershell
   cd backend
   ```

2. **Create and activate a Python virtual environment:**
   ```powershell
   python -m venv venv
   .\venv\Scripts\Activate.ps1   # On Linux/macOS: source venv/bin/activate
   ```

3. **Install required dependencies:**
   ```powershell
   pip install -r requirements.txt
   ```

4. **Environment Configuration:**
   Copy `.env.example` to `.env` (the defaults work out-of-the-box with SQLite):
   ```powershell
   cp .env.example .env
   ```

5. **(Optional) Seed Telangana Multi-Tenant Demo Data:**
   The repository includes a ready-to-use SQLite database (`backend/local.db`) populated with 3 months of realistic Hyderabad restaurant data (Paradise Biryani, Bawarchi, Deccan Spice, Nizam Heritage). To regenerate:
   ```powershell
   python scripts\seed_ior360_demo_data.py
   ```

6. **Start the FastAPI server:**
   ```powershell
   uvicorn main:app --reload --host 127.0.0.1 --port 8000
   ```
   The API will be available at `http://127.0.0.1:8000`.
   Interactive Swagger documentation is accessible at `http://127.0.0.1:8000/docs`.

---

### Frontend Setup

1. **Navigate to the frontend directory:**
   ```powershell
   cd frontend
   ```

2. **Fetch Flutter dependencies:**
   ```powershell
   flutter pub get
   ```

3. **Verify analyzer health:**
   ```powershell
   flutter analyze
   ```

4. **Run the Flutter application:**
   - **Chrome (Web):**
     ```powershell
     flutter run -d chrome
     ```
   - **Windows Desktop (Recommended for native thermal printing):**
     ```powershell
     flutter run -d windows
     ```
   - **Connected Mobile Device / Emulator:**
     ```powershell
     flutter run
     ```

---

## 🔑 Demo Login Accounts

All pre-seeded demo accounts share the standard password: **`password123`**

| Username | Role | Tenant Organization | Scoped Branch | Description |
| :--- | :--- | :--- | :--- | :--- |
| `superadmin` | `SUPER_ADMIN` | Platform Master (Global) | All Branches | Full global platform administration, tenant provisioning, cross-organization audits |
| `admin_paradise` | `RESTAURANT_ADMIN` | Paradise Biryani | All Paradise Outlets | Restaurant administrator with full access to Secunderabad, Madhapur, and Hitec City |
| `admin_bawarchi` | `RESTAURANT_ADMIN` | Bawarchi Restaurant | RTC X Roads | Single-flagship restaurant administrator |
| `admin_deccan` | `RESTAURANT_ADMIN` | Deccan Spice | All Deccan Outlets | Multi-branch administrator (Banjara Hills, Jubilee Hills, Gachibowli) |
| `admin_nizam` | `RESTAURANT_ADMIN` | Nizam Heritage Club | Abids & Charminar | Heritage dining administrator |
| `mgr_madhapur_1` | `BRANCH_MANAGER` | Paradise Biryani | Madhapur Outlet | Branch manager managing floor tables, local groceries, and branch staff |
| `cashier_madhapur_1` | `CASHIER` | Paradise Biryani | Madhapur Outlet | Cashier executing orders, bill settlements, discounts, and receipt printing |

---

## 🧪 Verification & Test Suites

### Backend Tests
Execute the automated test suites using the virtual environment:
```powershell
cd backend
.\venv\Scripts\python.exe test\test_settings_endpoints.py
.\venv\Scripts\python.exe test\test_support_endpoints.py
.\venv\Scripts\python.exe test\test_restaurants_branches_crud.py
.\venv\Scripts\python.exe test\test_seeded_db.py
.\venv\Scripts\python.exe test\test_e2e_multi_tenant_workflows.py
```
- **Coverage:** Health check probes, ESC/POS printer spooler tests, in-app password changes, support ticket lifecycle, multi-tenant isolation, Restaurants and Branches CRUD, and end-to-end POS billing workflows.

### Frontend Tests
Execute the Flutter automated test suite:
```powershell
cd frontend
flutter test
```
- **Coverage (29 tests passing 100%):**
  - Branch and Tenant dropdown safety assertion tests (`branch_dropdown_safety_test.dart`)
  - Home dashboard multi-tenant switching (`home_switching_test.dart`)
  - POS ordering and checkout workflows (`pos_workflow_test.dart`)
  - Restaurants and Branches navigation & RBAC tab tests (`restaurants_branches_tab_test.dart`)
  - Settings screen sub-tabs, thermal preview & password updates (`settings_screen_test.dart`)
  - Profile top-right navigation and Support desk isolation (`support_and_profile_navigation_test.dart`)
  - Widget component tests (`widget_test.dart`)

---

## 📂 Repository Structure

```
restaurant-revenue-tracker-flutter/
├── backend/                               # Python FastAPI backend service
│   ├── database.py                        # SQLAlchemy engine and session factory
│   ├── main.py                            # FastAPI entry point & CORS configuration
│   ├── models.py                          # 19 SQLAlchemy declarative models
│   ├── schemas.py                         # Pydantic request & response schemas
│   ├── security.py                        # Passlib bcrypt & JWT routines
│   ├── local.db                           # SQLite database (active runtime)
│   ├── requirements.txt                   # Backend dependencies
│   ├── routers/                           # 14 FastAPI modular routers
│   │   ├── auth.py                        # Login, session, password update
│   │   ├── billing.py                     # POS tables, KOT printing, checkout
│   │   ├── branches.py                    # Branch CRUD and scope verification
│   │   ├── chat.py                        # AI Natural Language SQL chat
│   │   ├── expenses.py                    # OPEX categories & expense vouchers
│   │   ├── groceries.py                   # Raw materials procurement & inventory upsert
│   │   ├── home.py                        # Real-time KPIs & multi-tenant summary
│   │   ├── kitchen.py                     # Recipe BOM & live inventory balances
│   │   ├── menu.py                        # Menu items & category management
│   │   ├── reports.py                     # 6 analytical report modules & PDF/CSV export
│   │   ├── restaurants.py                 # Restaurant tenant CRUD operations
│   │   ├── staff.py                       # Staff directory & monthly payroll
│   │   ├── support.py                     # Helpdesk tickets, FAQs, diagnostics
│   │   └── users.py                       # User administration & tab-level permissions
│   ├── scripts/                           # Administrative seeding & migration scripts
│   │   └── seed_ior360_demo_data.py       # Telangana 3-month demo data generator
│   ├── test/                              # Automated backend Python test suites
│   │   ├── __init__.py                    # Test package marker
│   │   ├── test_e2e_multi_tenant_workflows.py # Multi-tenant E2E tests
│   │   ├── test_restaurants_branches_crud.py  # Restaurants & Branches CRUD & RBAC
│   │   ├── test_seeded_db.py              # Seeded database integrity tests
│   │   ├── test_settings_endpoints.py     # Health, printer & password tests
│   │   └── test_support_endpoints.py      # Support ticket & isolation tests
│   └── services/                          # Core business services
│       ├── thermal_printer.py             # Win32 ESC/POS raw printer driver
│       └── ai/                            # LangChain SQL engine & chart generator
├── frontend/                              # Flutter client application
│   ├── lib/
│   │   ├── core/                          # Riverpod providers & foundation utilities
│   │   │   ├── api_client.dart            # Dio HTTP singleton & interceptors
│   │   │   ├── auth_provider.dart         # Authentication state & JWT handling
│   │   │   ├── branch_provider.dart       # Branch state & CRUD actions
│   │   │   ├── restaurant_provider.dart   # Restaurant state & CRUD actions
│   │   │   ├── settings_provider.dart     # Terminal, printer & branding preferences
│   │   │   ├── support_provider.dart      # Support tickets & FAQs with tenant isolation
│   │   │   ├── pos_provider.dart          # Table grid, cart staging & bill checkout
│   │   │   ├── home_provider.dart         # Dashboard telemetry & KPI cards
│   │   │   ├── menu_provider.dart         # Menu catalog & category filters
│   │   │   ├── kitchen_provider.dart      # Recipe BOMs & live stock levels
│   │   │   ├── groceries_provider.dart    # Raw groceries & procurement vouchers
│   │   │   ├── staff_provider.dart        # Employee directory & salary processing
│   │   │   ├── expenses_provider.dart     # Operating expenses & category ledgers
│   │   │   ├── reports_provider.dart      # Analytical report pillar providers
│   │   │   ├── users_provider.dart        # User roster & granular tab permissions
│   │   │   ├── chat_provider.dart         # Conversational AI assistant state
│   │   │   ├── currency_formatter.dart    # Dynamic INR (₹) formatting
│   │   │   └── nav_tabs.dart              # Role-aware navigation definitions
│   │   ├── models/                        # Immutable Dart data transfer models
│   │   ├── theme/                         # Material 3 styling and color palettes
│   │   └── ui/                            # User interface components and screens
│   │       ├── layouts/sidebar_layout.dart# Persistent application shell & top bar
│   │       ├── screens/                   # 15 Application feature views
│   │       │   ├── auth/                  # Login view
│   │       │   ├── home/                  # Executive dashboard
│   │       │   ├── pos/                   # Floor tables & checkout
│   │       │   ├── menu/                  # Dish catalog & pricing
│   │       │   ├── kitchen/               # Recipes & inventory stock
│   │       │   ├── groceries/             # Raw materials & purchases
│   │       │   ├── expenses/              # OPEX ledger & categories
│   │       │   ├── staff/                 # Roster & payroll disbursement
│   │       │   ├── reports/               # 6-pillar financial analytics
│   │       │   ├── restaurants/           # Restaurant organization management
│   │       │   ├── branches/              # Branch outlet management
│   │       │   ├── users/                 # User accounts & tab ACL
│   │       │   ├── settings/              # Hardware printer & profile settings
│   │       │   ├── support/               # Operations desk, FAQs, shortcuts
│   │       │   └── ai/                    # Natural language command center
│   │       └── widgets/                   # Reusable UI component library
│   └── test/                              # Automated Flutter unit & widget tests
├── audit_files/                           # Historical QA audits, schema logs (in .gitignore)
├── IOR_360_COMPLETE_DOCUMENTATION.md      # Definitive 2,900+ line technical manual
└── README.md                              # This document
```

---

## 🔒 Security & Data Isolation Guarantees

1. **Multi-Tenant Context Clamping:** Non-superadmin requests are strictly confined to their authorized `restaurant_id` on the backend, preventing any tenant spoofing.
2. **Centralized Tab Permissions:** A user's accessible tabs are governed centrally in the Users module (`user.allowed_tabs`), persisting seamlessly across logins and token refreshes.
3. **Reactive State Invalidation:** Changing active tenant or logging out triggers automatic invalidation across all Riverpod providers (e.g. `supportTicketsProvider`, `homeProvider`, `posProvider`), ensuring no cross-tenant data caching occurs in client memory.
4. **Cascade Safety Safeguards:** Deleting a restaurant or branch is protected by strict relational integrity checks preventing dangling orders, active bills, or orphaned records.

---

## 📄 License & Attribution

IOR 360 is proprietary software developed for high-volume restaurant operations. All rights reserved.
