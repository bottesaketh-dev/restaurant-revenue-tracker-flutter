# Code Audit Report — Flavors Ledger

**Audit Date:** 2026-09-01  
**Auditor:** Full-Stack Security Auditor  
**Scope:** Backend (`backend/`), Frontend (`frontend/lib/`)  
**Stack:** FastAPI + SQLAlchemy + PostgreSQL + JWT | Flutter + Riverpod + Dio

---

## 🔴 Critical Issues

---

**[C-01] SQL Injection via LangChain AI Agent — Full Database Read/Write Access**
* **Location:** [engine.py](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/services/ai/engine.py#L31-L49)
* **Description:** `create_sql_agent` is initialized with `SQLDatabase(engine)` which gives the LLM agent full, unrestricted read and write access to every table in the database. Any user who types a chat message can instruct the LLM to `DROP TABLE`, `DELETE FROM users`, `UPDATE users SET role='ADMIN'`, or exfiltrate password hashes.
* **Impact:** Complete database compromise. An attacker can escalate privileges, destroy data, or steal all user credentials through natural language prompts.
* **Resolution:**
  1. Restrict the `SQLDatabase` to read-only views: pass `view_support=True` and whitelist safe tables.
  2. Create a read-only PostgreSQL role for the AI agent's connection.
  3. Explicitly exclude `users`, `password_hash`, and sensitive columns.
```python
# Create a separate read-only engine for the AI agent
readonly_engine = create_engine(DATABASE_URL + "?options=-c default_transaction_read_only=on", pool_pre_ping=True)

# Whitelist only safe tables
self.sql_db = SQLDatabase(
    readonly_engine,
    include_tables=["bills", "orders", "order_items", "menu_items", "expenses",
                    "grocery_purchases", "employees", "branches", "inventory_stock"],
)
```

---

**[C-02] Chat Endpoint Has No Authentication**
* **Location:** [chat.py](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/chat.py#L22-L29)
* **Description:** The `/api/v1/chat` POST endpoint does not use `Depends(security.get_current_user_token)`. Any unauthenticated user can send arbitrary queries to the AI agent, which has full database access (see C-01).
* **Impact:** Combined with C-01, this is a publicly accessible SQL injection vector. Anyone on the internet can query, modify, or destroy your entire database.
* **Resolution:**
```python
@router.post("")
def chat_endpoint(req: ChatRequest, current_user: dict = Depends(security.get_current_user_token)):
    agent = get_agent()
    return StreamingResponse(
        agent.stream_process_query(req.message, req.branch_id),
        media_type="application/x-ndjson"
    )
```

---

**[C-03] Hardcoded Fallback Secret Key for JWT Signing**
* **Location:** [security.py:13](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/security.py#L13)
* **Description:** `SECRET_KEY = os.getenv("SECRET_KEY", "default_secret")`. If the environment variable is ever unset (common in misconfigured deployments), all JWTs are signed with the publicly visible string `"default_secret"`. Any attacker can forge valid admin tokens.
* **Impact:** Complete authentication bypass. An attacker can create any JWT payload with `role: ADMIN` and access every endpoint.
* **Resolution:**
```python
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise ValueError("SECRET_KEY environment variable is required and must not be empty.")
```

---

**[C-04] CORS Allows All Origins with Wildcards**
* **Location:** [main.py:12-18](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/main.py#L12-L18)
* **Description:** `allow_origins=["*"]` permits any website to make authenticated API requests to your backend. Combined with `allow_credentials=False`, this means any malicious website can call your API on behalf of a user (if they have the JWT token from local storage or can trick the browser).
* **Impact:** Cross-Origin attacks. A malicious site can interact with your API if JWT tokens are leaked or interceptable.
* **Resolution:**
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",      # Local Flutter web dev
        "https://your-production-domain.com",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

**[C-05] No Role-Based Authorization — Any User Can Create/Delete Admins**
* **Location:** [users.py:26-57](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/users.py#L26-L57), [users.py:82-93](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/users.py#L82-L93)
* **Description:** The `create_user`, `update_user`, and `delete_user` endpoints check only that a valid JWT exists. They never verify that the calling user has the `ADMIN` role. A `CASHIER` user can create new `ADMIN` accounts, delete other users, or change anyone's password.
* **Impact:** Full privilege escalation. Any authenticated user becomes an admin.
* **Resolution:**
```python
@router.post("/", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    user: schemas.UserCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user_token)
):
    if current_user.get("role") != "ADMIN":
        raise HTTPException(status_code=403, detail="Only administrators can manage users")
    # ... rest of logic
```

---

**[C-06] Exposed GitHub PAT and Database Credentials in `.env`**
* **Location:** [.env](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/.env)
* **Description:** The `.env` file contains a GitHub Personal Access Token (`github_pat_11CHEC6OA...`) and the full PostgreSQL connection string with username and password. If this file is ever committed to a public repository, all credentials are compromised.
* **Impact:** Full access to the GitHub account and production database.
* **Resolution:**
  1. **Immediately rotate** the GitHub PAT and database password.
  2. Verify `.env` is in `.gitignore` (it appears to be, but verify the git history).
  3. Run `git log --all --full-history -- backend/.env` to check if it was ever committed.
  4. Use a secrets manager (e.g., Render's environment variable UI) instead of a file.

---

## 🟠 High Severity Issues

---

**[H-01] Inventory Race Condition — Concurrent Checkouts Cause Negative Stock**
* **Location:** [billing.py:273-283](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/billing.py#L273-L283)
* **Description:** Inventory deduction during checkout uses a read-then-write pattern with no row-level locking. If two cashiers check out orders simultaneously that use the same ingredient, both will read the current stock, independently subtract, and write back. One deduction will be lost. Stock can also go negative since there is no floor check.
* **Impact:** Inventory data corruption. Financial reports will be inaccurate. Stock can show impossible negative quantities.
* **Resolution:**
```python
# Use SELECT ... FOR UPDATE to lock the row during the transaction
stock = db.query(models.InventoryStock).filter(
    models.InventoryStock.grocery_item_id == recipe.grocery_item_id
).with_for_update().first()

if stock:
    total_required = Decimal(str(float(recipe.quantity_required))) * Decimal(str(int(item.quantity)))
    if stock.current_stock < total_required:
        db.rollback()
        raise HTTPException(status_code=409, detail=f"Insufficient stock for {recipe.grocery_item_id}")
    stock.current_stock -= total_required
```

---

**[H-02] Grocery Bulk Purchase Race Condition — Duplicate Inventory Rows**
* **Location:** [groceries.py:176-186](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/groceries.py#L176-L186)
* **Description:** In `add_purchase_bulk`, when a grocery item has no existing `InventoryStock` row, a new one is created. If two bulk purchases for the same new item arrive concurrently, both threads will see `stock is None`, both will try to `INSERT`, and one will hit a `UniqueViolation` (which is exactly the bug you experienced).
* **Impact:** 500 Internal Server Error. This is the root cause of the duplicate key errors you've been encountering repeatedly.
* **Resolution:**
```python
from sqlalchemy.dialects.postgresql import insert as pg_insert

# Upsert pattern: INSERT ... ON CONFLICT DO UPDATE
stmt = pg_insert(models.InventoryStock).values(
    grocery_item_id=p.grocery_item_id,
    current_stock=p.quantity
).on_conflict_do_update(
    index_elements=['grocery_item_id'],
    set_={'current_stock': models.InventoryStock.current_stock + p.quantity}
)
db.execute(stmt)
```

---

**[H-03] JWT Token Expires After 7 Days with No Refresh Mechanism**
* **Location:** [security.py:15](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/security.py#L15)
* **Description:** `ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7` (7 days). There is no refresh token mechanism. If a token is stolen, the attacker has 7 full days of access. The frontend's 401 handler ([api_client.dart:22-26](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/frontend/lib/core/api_client.dart#L22-L26)) is empty — it catches the error but does nothing.
* **Impact:** Stolen tokens are valid for a full week. No ability to revoke sessions.
* **Resolution:**
  1. Reduce `ACCESS_TOKEN_EXPIRE_MINUTES` to 30-60 minutes.
  2. Implement a refresh token flow (long-lived refresh token stored securely, short-lived access token).
  3. Actually handle the 401 in the frontend Dio interceptor to force logout.

---

**[H-04] `user_id` Extracted from JWT `sub` Claim Without Validation**
* **Location:** [billing.py:168](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/billing.py#L168), [expenses.py:60](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/expenses.py#L60)
* **Description:** Multiple endpoints use `current_user.get("user_id", 1)` as fallback — if the claim is missing, it silently defaults to user ID 1 (likely the admin). In `expenses.py`, `int(token_data.get("sub"))` will crash with a `TypeError` if `sub` is `None`. The JWT `sub` claim is set to `str(user.user_id)` but retrieved inconsistently as either `"sub"` or `"user_id"`.
* **Impact:** Actions can be attributed to the wrong user. A malformed token could allow impersonation of user 1 (admin).
* **Resolution:**
```python
# In security.py — return a validated, typed object instead of raw dict
def get_current_user_token(...):
    # ...
    user_id = payload.get("sub")
    role = payload.get("role")
    branch_id = payload.get("branch_id")
    if user_id is None or role is None:
        raise HTTPException(status_code=401, detail="Invalid token: missing claims")
    return {"user_id": int(user_id), "role": role, "branch_id": branch_id}
```

---

**[H-05] Groceries `GET /purchases` Has No Authentication**
* **Location:** [groceries.py:71-78](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/groceries.py#L71-L78)
* **Description:** The `get_purchases` endpoint does not use `Depends(security.get_current_user_token)`. Any unauthenticated user can read all grocery purchase data, including vendor names and pricing.
* **Impact:** Financial data leakage. Competitor intelligence exposure.
* **Resolution:**
```python
@router.get("/purchases")
def get_purchases(
    branch_id: Optional[int] = None,
    # ... other params ...
    db: Session = Depends(get_db),
    current_user: dict = Depends(security.get_current_user_token)  # Add this
):
```

---

**[H-06] Expense Categories Endpoints Have No Authentication**
* **Location:** [expenses.py:100-113](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/expenses.py#L100-L113)
* **Description:** Both `GET /expenses/categories` and `POST /expenses/categories` lack `Depends(security.get_current_user_token)`. Anyone can read or create expense categories without logging in.
* **Impact:** Unauthorized data access and creation.
* **Resolution:** Add `current_user: dict = Depends(security.get_current_user_token)` to both endpoints.

---

## 🟡 Medium Severity Issues

---

**[M-01] GoRouter Recreated on Every `build()` Call — Performance Regression**
* **Location:** [main.dart:30-93](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/frontend/lib/main.dart#L30-L93)
* **Description:** `GoRouter` is instantiated inside the `build()` method of `FlavorsLedgerApp`. Because `authStateProvider` triggers a rebuild when auth state changes, the entire router is recreated, destroying all navigation state. Every auth state check rebuilds the app from scratch.
* **Impact:** Navigation stack resets on every auth state change. Potential memory leaks from router recreation. Poor user experience.
* **Resolution:** Move router creation outside `build()` using a Riverpod `Provider`:
```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    refreshListenable: ..., // Use GoRouterRefreshStream
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isGoingToLogin = state.uri.toString() == '/login';
      if (!isLoggedIn && !isGoingToLogin) return '/login';
      if (isLoggedIn && isGoingToLogin) return '/home';
      return null;
    },
    routes: [/* ... */],
  );
});
```

---

**[M-02] Chat Stream Uses Hardcoded `localhost` URL — Breaks on Mobile/Production**
* **Location:** [chat_provider.dart:19](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/frontend/lib/core/chat_provider.dart#L19)
* **Description:** `Uri.parse('http://127.0.0.1:8000/api/v1/chat')` is hardcoded. While `api_client.dart` was updated to use the Render URL, the chat provider still uses `127.0.0.1`. This means the AI chat feature is completely broken on mobile and production.
* **Impact:** AI Command Center doesn't work on any device other than the development machine.
* **Resolution:**
```dart
class ChatStreamService {
  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  // Read the base URL from the Dio provider's baseUrl
  String get _baseUrl {
    final dio = _ref.read(dioProvider);
    return dio.options.baseUrl.replaceAll('/api/v1', '');
  }

  Stream<Map<String, dynamic>> sendQuery(String message) async* {
    final request = http.Request('POST', Uri.parse('${_baseUrl}/api/v1/chat'));
    // ...
  }
}
```

---

**[M-03] `branch_id` Resolution Uses Fragile `locals().get()` Pattern**
* **Location:** [billing.py:162](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/billing.py#L162), [billing.py:238](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/billing.py#L238)
* **Description:** `b_id = branch_id if locals().get('branch_id') else (user_branch_id or 1)` relies on Python's `locals()` dictionary, which is an implementation detail that can behave unexpectedly (e.g., locals are not always updated after assignment in CPython optimized frames). This pattern appears in multiple billing functions.
* **Impact:** Orders or bills could be attributed to wrong branches, or always default to branch 1.
* **Resolution:**
```python
# Derive branch_id cleanly at the top of the function
if user_role != "ADMIN" and user_branch_id is not None:
    b_id = user_branch_id
else:
    b_id = branch_id or user_branch_id or 1
```

---

**[M-04] Dead Code: `branch_id` Assigned But Never Used in Multiple Routers**
* **Location:** [billing.py:57](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/billing.py#L54-L57), [billing.py:80](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/billing.py#L78-L80), [kitchen.py:14-15](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/kitchen.py#L14-L15), [groceries.py:17-18](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/groceries.py#L17-L18)
* **Description:** Many endpoints calculate `branch_id` from the JWT but never use it to filter queries. For example, `get_categories` in groceries sets `branch_id = user_branch_id` but then returns ALL categories unfiltered. The `kitchen.py` inventory endpoint does the same — it returns all inventory stock regardless of branch.
* **Impact:** Data leakage across branches. A branch-level user can see data from all branches.
* **Resolution:** Apply the computed `branch_id` filter to the actual database query in every endpoint.

---

**[M-05] No Database Connection Pooling Limits**
* **Location:** [database.py:13](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/database.py#L13)
* **Description:** `create_engine(DATABASE_URL, pool_pre_ping=True)` uses SQLAlchemy's default pool settings (5 connections, 10 overflow). For a POS system with multiple concurrent users and the AI agent also holding a connection, this pool may exhaust quickly, especially on Supabase's free tier which limits connections.
* **Impact:** Under load, new requests will block waiting for a connection, causing timeouts.
* **Resolution:**
```python
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    pool_timeout=30,
    pool_recycle=1800,  # Recycle connections every 30 minutes
)
```

---

**[M-06] N+1 Query in Dashboard Summary**
* **Location:** [home.py:141-168](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/home.py#L141-L168)
* **Description:** For each bill in `recent_bills`, a separate query fetches the order items joined with menu items. If there are 50 bills, this generates 51 queries (1 for bills + 50 for items).
* **Impact:** Significant performance degradation on the dashboard page as data grows. Each page load could trigger dozens of queries.
* **Resolution:** Use SQLAlchemy's `joinedload` or `selectinload` to eagerly load items in a single query, or restructure the query to batch-fetch all order items at once.

---

**[M-07] Hardcoded 5% Tax Rate in Checkout**
* **Location:** [billing.py:234](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/billing.py#L234)
* **Description:** `tax_amount = subtotal * Decimal('0.05')` is hardcoded. Tax rates vary by jurisdiction and may change. This is a business logic constant embedded in application code.
* **Impact:** Cannot adapt to different tax regions or regulatory changes without a code deployment.
* **Resolution:** Store the tax rate in a branch configuration table or environment variable.

---

**[M-08] Bare `except:` Clauses in Reports Date Parsing**
* **Location:** [reports.py:22-23](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/reports.py#L22-L23), [reports.py:30-31](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/reports.py#L30-L31)
* **Description:** `except:` catches ALL exceptions including `KeyboardInterrupt`, `SystemExit`, and `MemoryError`. Silently falling back to a default date on invalid input hides bugs.
* **Impact:** Malformed date inputs are silently swallowed. Makes debugging impossible.
* **Resolution:**
```python
except (ValueError, TypeError):
    end_d = today
```

---

## 🟢 Low Severity Issues

---

**[L-01] `print()` Statements in Production Auth Code**
* **Location:** [auth.py:16-19](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/auth.py#L16-L19)
* **Description:** `print("User not found!")` and `print("Password verification failed!")` leak authentication debugging info to stdout. Combined with redundant `verify_password` calls (lines 18 and 21), the password is hashed twice per login attempt.
* **Impact:** Minor performance hit. Debug output in production logs. Double bcrypt computation on every failed login.
* **Resolution:** Remove the debug prints and the redundant verification call. Use `logging.warning()` if logging is needed.

---

**[L-02] `Decimal` to `float` Conversion Precision Loss**
* **Location:** [billing.py:282](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/billing.py#L282)
* **Description:** `Decimal(str(float(recipe.quantity_required)))` converts Decimal → float → string → Decimal, introducing floating point precision errors. This is unnecessary since `quantity_required` is already a Decimal from the database.
* **Impact:** Tiny rounding errors in inventory deduction accumulate over thousands of orders.
* **Resolution:**
```python
total_required = recipe.quantity_required * item.quantity
stock.current_stock -= total_required
```

---

**[L-03] Purchases Hardcode `recorded_by=1` and `branch_id=1`**
* **Location:** [groceries.py:132-133](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/groceries.py#L132-L133), [groceries.py:172-173](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/groceries.py#L172-L173)
* **Description:** Both `add_purchase` and `add_purchase_bulk` hardcode `recorded_by=1` and `branch_id=1` instead of using the authenticated user's ID and branch from the JWT.
* **Impact:** All purchases are attributed to user 1 and branch 1 regardless of who actually recorded them. Audit trails are broken.
* **Resolution:**
```python
recorded_by=int(current_user.get("sub")),
branch_id=current_user.get("branch_id") or 1,
```

---

**[L-04] `SalaryPayment` Status Case Mismatch**
* **Location:** [staff.py:172](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/staff.py#L172) vs [home.py:56](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/home.py#L56)
* **Description:** Salary payments are created with `payment_status="Paid"` (capitalized) but filtered with `payment_status == 'paid'` (lowercase) in the dashboard and reports queries. PostgreSQL string comparison is case-sensitive by default.
* **Impact:** Salary outflows are never included in the dashboard cash flow or P&L reports, making financial reports inaccurate.
* **Resolution:** Standardize to one casing (recommend lowercase `"paid"`) everywhere, or use `.ilike('paid')` in queries.

---

**[L-05] Grocery Purchase Update Doesn't Adjust Inventory**
* **Location:** [groceries.py:192-212](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/groceries.py#L192-L212)
* **Description:** When a purchase is updated (quantity changed), the inventory stock is not re-adjusted. The old quantity was already added to stock, but the difference is never reconciled.
* **Impact:** Inventory stock will drift from reality after any purchase edit.
* **Resolution:** Calculate the delta between old and new quantity and adjust `InventoryStock` accordingly.

---

**[L-06] Order ID Collision Risk**
* **Location:** [billing.py:165](file:///e:/Ometrion%20Genesis/Projects/restaurant-revenue-tracker-flutter/backend/routers/billing.py#L165)
* **Description:** `order_id=f"ORD-{uuid4().hex[:6].upper()}"` uses only 6 hex characters (16^6 = 16.7 million possibilities). Similarly, `bill_id=f"BILL-{uuid4().hex[:6].upper()}"`. With high transaction volumes, collisions become probable (birthday problem: ~50% collision chance at ~4,000 records).
* **Impact:** Primary key collision will crash checkout operations.
* **Resolution:** Use the full UUID or at least 12 hex characters, or use a date-prefixed sequential format like the existing bill IDs in the seed data (`BIL-20260601-01-0001`).

---

## 📊 Summary Matrix

| Dimension | Critical | High | Medium | Low |
|---|---|---|---|---|
| Security & Auth | C-01, C-02, C-03, C-04, C-05, C-06 | H-03, H-04, H-05, H-06 | | L-01 |
| Data Integrity | | H-01, H-02 | M-03, M-07 | L-02, L-03, L-04, L-05, L-06 |
| Architecture | | | M-01, M-04 | |
| Performance | | | M-05, M-06 | |
| Error Handling | | | M-08 | |
| Frontend | | | M-01, M-02 | |

---

## Priority Fix Order

1. **Immediate** (before any public deployment):
   - C-02 → Add auth to chat endpoint
   - C-03 → Remove fallback secret key
   - C-05 → Add role checks to user management
   - C-06 → Rotate all leaked credentials
   - C-04 → Restrict CORS origins

2. **This sprint**:
   - C-01 → Restrict AI agent's database access
   - H-01, H-02 → Fix race conditions with row locking / upserts
   - H-05, H-06 → Add missing auth to grocery/expense endpoints
   - L-04 → Fix salary payment status casing (silently breaking P&L reports)

3. **Next sprint**:
   - M-01 → Fix GoRouter recreation
   - M-02 → Fix hardcoded chat URL
   - H-03, H-04 → Implement refresh tokens and fix user_id extraction
   - M-05, M-06 → Database pool tuning and N+1 query fix
