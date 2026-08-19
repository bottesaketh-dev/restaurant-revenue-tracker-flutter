import os
import psycopg2
from psycopg2.extras import execute_values
import hashlib
import random
import datetime
from dotenv import load_dotenv

load_dotenv(override=True)
DB_URL = os.getenv("DATABASE_URL")

random.seed(42)

start_date = datetime.date(2026, 6, 1)
end_date = datetime.date(2026, 7, 30)

def get_timestamp(date_obj, hour, minute, second):
    minute = max(0, min(minute, 59))
    hour = max(0, min(hour, 23))
    dt = datetime.datetime.combine(date_obj, datetime.time(hour, minute, second))
    return dt.strftime('%Y-%m-%d %H:%M:%S')

def hash_pw(pwd):
    import bcrypt
    return bcrypt.hashpw(pwd.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def generate_timestamp(offset_days=0, hour=10):
    dt = datetime.datetime(2026, 1, 1, hour, 0, 0) + datetime.timedelta(days=offset_days)
    return dt.strftime('%Y-%m-%d %H:%M:%S')

# 1. BRANCHES (15)
locations = [
    "Hitech City Flagship", "Jubilee Hills Premium", "Banjara Hills Outlet", "Gachibowli IT Park", 
    "Kondapur Express", "Madhapur Central", "Kukatpally Housing Board", "Secunderabad Station", 
    "Begumpet Main", "Ameerpet Hub", "Dilsukhnagar Express", "LB Nagar Square", 
    "Miyapur Junction", "Manikonda Heights", "Tolichowki Central"
]
branches_data = [
    (i+1, loc, f"Plot {random.randint(1,100)}, {loc.split(' ')[0]}, Hyderabad, TS", 
     f"+91406612{random.randint(1000,9999)}", True, generate_timestamp(i*5))
    for i, loc in enumerate(locations)
]

# 2. GROCERY CATEGORIES (15)
g_cat_names = [
    "Grains & Staples", "Meats & Poultry", "Seafood", "Fresh Vegetables", "Fresh Fruits",
    "Dairy & Cheese", "Oils & Fats", "Spices & Whole Condiments", "Powdered Spices", 
    "Sauces & Pastes", "Beverages & Syrups", "Baking Supplies", "Packaging - Boxes", 
    "Packaging - Bags", "Cleaning Supplies"
]
grocery_categories_data = [
    (i+1, name, f"Category for {name}", True) for i, name in enumerate(g_cat_names)
]

# 3. EXPENSE CATEGORIES (15)
e_cat_names = [
    "Rent & Property", "Utilities - Electricity", "Utilities - Water", "Fuel - Commercial LPG",
    "Licenses - GHMC/FSSAI", "Repairs - Kitchen Eqp", "Repairs - HVAC", "Marketing & Ads",
    "Software & POS", "Internet & Telecom", "Insurance", "Legal & Accounting",
    "Staff Welfare", "Logistics & Transport", "Miscellaneous"
]
expense_categories_data = [
    (i+1, name, f"Expenses related to {name}", True) for i, name in enumerate(e_cat_names)
]

# 4. EMPLOYEES & USERS (30 employees, 2 per branch)
first_names = ["Ramesh", "Syed", "Swetha", "Abdul", "Madhavi", "Krishna", "Venkat", "Lakshmi", "Priya", "Rahul", "Imran", "Suresh", "Divya", "Anil", "Gopal"]
last_names = ["Babu", "Ibrahim", "Reddy", "Kalam", "Latha", "Rao", "Naidu", "Sharma", "Yadav", "Goud"]
positions = ["Restaurant Manager", "Executive Chef", "Cashier", "Line Cook", "Waiter"]

employees_data = []
users_data = []
user_branch_map = {}

emp_counter = 1
for b_id in range(1, 16):
    # Manager for branch
    fname = random.choice(first_names)
    lname = random.choice(last_names)
    email = f"{fname.lower()}.{lname.lower()}{emp_counter}@hydrest.com"
    employees_data.append((
        f"EMP-{emp_counter:03d}", fname, lname, email, f"987654{random.randint(1000,9999)}", 
        "Restaurant Manager", 35000.00, "2026-01-10", True, b_id, generate_timestamp(emp_counter), generate_timestamp(emp_counter)
    ))
    users_data.append((
        emp_counter, f"{fname.lower()}_mgr{b_id}", email, hash_pw("pass123"), "MANAGER", b_id, True, generate_timestamp(emp_counter), generate_timestamp(emp_counter)
    ))
    emp_counter += 1
    
    # Cashier for branch
    fname = random.choice(first_names)
    lname = random.choice(last_names)
    email = f"{fname.lower()}.{lname.lower()}{emp_counter}@hydrest.com"
    employees_data.append((
        f"EMP-{emp_counter:03d}", fname, lname, email, f"987654{random.randint(1000,9999)}", 
        "Cashier", 18000.00, "2026-01-15", True, b_id, generate_timestamp(emp_counter), generate_timestamp(emp_counter)
    ))
    users_data.append((
        emp_counter, f"{fname.lower()}_csh{b_id}", email, hash_pw("pass123"), "CASHIER", b_id, True, generate_timestamp(emp_counter), generate_timestamp(emp_counter)
    ))
    user_branch_map[b_id] = emp_counter
    emp_counter += 1
    
# Add 1 Admin
users_data.append((emp_counter, "super_admin", "admin@hydrest.com", hash_pw("admin123"), "ADMIN", None, True, generate_timestamp(), generate_timestamp()))

# 5. TABLES (10 per branch = 150 tables)
tables_data = []
for b_id in range(1, 16):
    for t_num in range(1, 11):
        cap = random.choice([2, 4, 4, 6])
        tables_data.append((f"BR{b_id}-T{t_num:02d}", cap, "AVAILABLE", b_id, True))

# 6. GROCERY ITEMS (25 Items)
g_items_list = [
    ("Aged Basmati Rice", 1, "kg", 95.00), ("Wheat Flour (Maida)", 1, "kg", 45.00), 
    ("Chicken (Bone-in)", 2, "kg", 240.00), ("Mutton (Goat Meat)", 2, "kg", 720.00), 
    ("Apollo Reef Fish", 3, "kg", 450.00), ("Prawns", 3, "kg", 550.00),
    ("Onions", 4, "kg", 35.00), ("Tomatoes", 4, "kg", 45.00), 
    ("Mint & Coriander", 4, "bunch", 15.00), ("Green Chillies", 4, "kg", 60.00),
    ("Apples", 5, "kg", 120.00), ("Lemons", 5, "kg", 80.00),
    ("Pure Desi Ghee", 6, "kg", 650.00), ("Yogurt / Curd", 6, "kg", 80.00), 
    ("Fresh Paneer", 6, "kg", 380.00), ("Sunflower Oil", 7, "liter", 115.00),
    ("Saffron", 8, "gram", 250.00), ("Cardamom", 8, "kg", 1200.00),
    ("Proprietary Garam Masala", 9, "kg", 900.00), ("Turmeric Powder", 9, "kg", 200.00),
    ("Ginger Garlic Paste", 10, "kg", 150.00), ("Tomato Ketchup", 10, "kg", 120.00),
    ("Tea Powder", 11, "kg", 400.00), ("Coffee Beans", 11, "kg", 600.00),
    ("Premium Takeaway Box", 13, "piece", 6.50)
]
grocery_items_dict = {f"GR-{i+100}": (item[0], item[1], item[2], item[3]) for i, item in enumerate(g_items_list)}

grocery_items_data = [
    (g_id, name, c_id, unit, True, "2026-01-01 10:00:00") 
    for g_id, (name, c_id, unit, price) in grocery_items_dict.items()
]

# 7. MENU ITEMS (20 Items)
menu_definitions = [
    ("Hyderabadi Chicken Dum Biryani", "Authentic dum cooked biryani", "Biryani", 340.00, False),
    ("Hyderabadi Mutton Dum Biryani", "Tender goat meat slow cooked", "Biryani", 390.00, False),
    ("Special Veg Dum Biryani", "Mixed vegetables in fragrant rice", "Biryani", 260.00, True),
    ("Paneer Biryani", "Cottage cheese biryani", "Biryani", 280.00, True),
    ("Egg Biryani", "Boiled eggs in aromatic rice", "Biryani", 220.00, False),
    ("Chicken 65", "Spicy deep-fried chicken starter", "Starters", 270.00, False),
    ("Apollo Fish", "Tangy boneless fish fry", "Starters", 320.00, False),
    ("Paneer 65", "Spicy cottage cheese starter", "Starters", 240.00, True),
    ("Mutton Marag", "Rich spicy mutton bone soup", "Starters", 280.00, False),
    ("Chilli Chicken", "Indo-chinese spicy chicken", "Starters", 260.00, False),
    ("Dum Ka Chicken", "Slow cooked rich chicken curry", "Main Course", 310.00, False),
    ("Paneer Butter Masala", "Cottage cheese in rich tomato gravy", "Main Course", 260.00, True),
    ("Mutton Rogan Josh", "Kashmiri style mutton curry", "Main Course", 380.00, False),
    ("Dal Makhani", "Slow cooked black lentils", "Main Course", 220.00, True),
    ("Rumali Roti", "Thin hand-tossed bread", "Breads", 25.00, True),
    ("Butter Naan", "Tandoor baked bread dripping with butter", "Breads", 40.00, True),
    ("Garlic Naan", "Naan topped with minced garlic", "Breads", 50.00, True),
    ("Double Ka Meetha", "Traditional bread pudding dessert", "Desserts", 130.00, True),
    ("Qubani Ka Meetha", "Stewed apricot dessert", "Desserts", 160.00, True),
    ("Special Irani Chai", "Rich milky tea decoction", "Beverages", 30.00, True)
]

menu_items_data = []
branch_menu_map = {b_id: {} for b_id in range(1, 16)} 
menu_counter = 1
for b_id in range(1, 16):
    for raw_id, (m_name, m_desc, m_cat, m_price, m_veg) in enumerate(menu_definitions):
        img_url = f"https://cdn.tasteofhyd.com/img/{raw_id+1}.jpg"
        menu_items_data.append((
            menu_counter, m_name, m_desc, m_cat, m_price, m_veg, True, img_url, b_id, 
            "2026-01-01 10:00:00", "2026-01-01 10:00:00"
        ))
        branch_menu_map[b_id][raw_id+1] = menu_counter
        menu_counter += 1

# RECIPES (Simple randomized mapping for simulation)
recipes_raw = {}
g_keys = list(grocery_items_dict.keys())
for m_id in range(1, 21):
    ings = random.sample(g_keys, random.randint(2, 5))
    recipes_raw[m_id] = [(g_id, round(random.uniform(0.05, 0.3), 2)) for g_id in ings]

recipe_ingredients_data = []
recipe_ctr = 1
for b_id in range(1, 16):
    for raw_m_id, ings in recipes_raw.items():
        actual_m_id = branch_menu_map[b_id][raw_m_id]
        for (g_id, qty) in ings:
            recipe_ingredients_data.append((
                recipe_ctr, actual_m_id, g_id, qty, "2026-01-01 10:00:00"
            ))
            recipe_ctr += 1

# 8. TRANSACTIONAL TIME-SERIES SIMULATION
orders_data = []
order_items_data = []
bills_data = []
grocery_purchases_data = []
expenses_data = []
salary_payments_data = []
inventory_stock_data = []

stock_ledger = {g_id: 2000.0 for g_id in grocery_items_dict.keys()}
order_counter = 1
order_item_counter = 1
purchase_counter = 1
expense_counter = 1
salary_counter = 1

curr_date = start_date
# Generating just 30 days of high volume data for 15 branches to stay within reasonable execution time
end_date = start_date + datetime.timedelta(days=30) 

while curr_date <= end_date:
    day_offset = (curr_date - start_date).days
    
    if curr_date.day == 1:
        for b_id in range(1, 16):
            recorded_by = user_branch_map[b_id]
            expenses_data.append((
                expense_counter, curr_date.strftime('%Y-%m-%d'), "10:00:00", 1,
                "Monthly Commercial Lease", random.randint(120000, 180000), "UPI", "Property Mgmt", f"REC-{curr_date.strftime('%Y%m')}-R", None, recorded_by, b_id, get_timestamp(curr_date, 10, 0, 0)
            ))
            expense_counter += 1
            expenses_data.append((
                expense_counter, curr_date.strftime('%Y-%m-%d'), "10:05:00", 2,
                "TSSPDCL Commercial Electricity Bill", random.randint(55000, 75000), "UPI", "TSSPDCL", f"ELC-{curr_date.strftime('%Y%m')}", "Heavy AC usage", recorded_by, b_id, get_timestamp(curr_date, 10, 5, 0)
            ))
            expense_counter += 1
            
            for emp in employees_data:
                if emp[9] == b_id:
                    emp_id = emp[0]
                    base_sal = emp[6]
                    deduction = float(base_sal) * 0.05
                    net = float(base_sal) - deduction
                    salary_payments_data.append((
                        salary_counter, emp_id, curr_date.month, curr_date.year,
                        base_sal, 0.0, deduction, net, curr_date.strftime('%Y-%m-%d'),
                        "PAID", "BANK_TRANSFER", 1, b_id, get_timestamp(curr_date, 11, 0, 0)
                    ))
                    salary_counter += 1

    if day_offset % 3 == 0:
        for b_id in range(1, 16):
            recorded_by = user_branch_map[b_id]
            expenses_data.append((
                expense_counter, curr_date.strftime('%Y-%m-%d'), "08:00:00", 4,
                "19kg Commercial LPG Refill (4 Cylinders)", 3191.00 * 4, "UPI", "Local Gas Agency", f"LPG-{curr_date.strftime('%Y%m%d')}", None, recorded_by, b_id, get_timestamp(curr_date, 8, 0, 0)
            ))
            expense_counter += 1

    for b_id in range(1, 16):
        recorded_by = user_branch_map[b_id]
        if day_offset % 5 == 0:
            for g_id in random.sample(g_keys, 10):
                unit_price = grocery_items_dict[g_id][3]
                qty = random.randint(20, 50)
                total_p = round(qty * unit_price, 2)
                grocery_purchases_data.append((
                    purchase_counter, curr_date.strftime('%Y-%m-%d'), "07:30:00", g_id,
                    qty, unit_price, total_p, "Wholesale Mandi", None, recorded_by, b_id, get_timestamp(curr_date, 7, 30, 0)
                ))
                stock_ledger[g_id] += qty
                purchase_counter += 1

    is_weekend = curr_date.weekday() in [5, 6]
    for b_id in range(1, 16):
        recorded_by = user_branch_map[b_id]
        num_orders = random.randint(20, 35) if is_weekend else random.randint(10, 20)
        
        for o_idx in range(num_orders):
            t_id = f"BR{b_id}-T{random.randint(1, 10):02d}"
            hr = random.randint(12, 15) if random.choice([True, False]) else random.randint(19, 23)
            mn = random.randint(0, 59)
            
            order_id = f"ORD-{curr_date.strftime('%Y%m%d')}-{b_id:02d}-{o_idx:04d}"
            orders_data.append((
                order_id, t_id, "COMPLETED", recorded_by, b_id, 
                get_timestamp(curr_date, hr, mn, 0), get_timestamp(curr_date, hr, mn+random.randint(20,40), 0)
            ))
            
            num_items = random.randint(2, 5)
            order_subtotal = 0.0
            chosen_raw_ids = random.sample(range(1, 21), num_items)
            
            for raw_id in chosen_raw_ids:
                actual_m_id = branch_menu_map[b_id][raw_id]
                m_price = menu_definitions[raw_id - 1][3]
                qty = random.choice([1, 2, 3])
                total_p = qty * m_price
                order_subtotal += total_p
                
                order_items_data.append((
                    order_item_counter, order_id, actual_m_id, qty, m_price, total_p, None, get_timestamp(curr_date, hr, mn, 0)
                ))
                order_item_counter += 1
                
                if raw_id in recipes_raw:
                    for (g_id, required_qty) in recipes_raw[raw_id]:
                        stock_ledger[g_id] -= (required_qty * qty)
                
            tax_amt = round(order_subtotal * 0.05, 2)
            discount = round(order_subtotal * 0.10, 2) if random.random() < 0.10 else 0.0
            total_amt = round(order_subtotal + tax_amt - discount, 2)
            
            pay_mode = random.choices(["UPI", "CARD", "CASH"], weights=[0.70, 0.20, 0.10])[0]
            c_amt, u_amt, cd_amt, tip = 0.0, 0.0, 0.0, 0.0
            if random.random() < 0.20: tip = float(random.choice([20, 50, 100]))
                
            if pay_mode == "UPI": u_amt = total_amt
            elif pay_mode == "CARD": cd_amt = total_amt
            else: c_amt = total_amt + tip
                
            bill_id = f"BIL-{curr_date.strftime('%Y%m%d')}-{b_id:02d}-{o_idx:04d}"
            bills_data.append((
                bill_id, order_id, t_id, order_subtotal, tax_amt, discount, total_amt, pay_mode, "PAID",
                recorded_by, b_id, curr_date.strftime('%Y-%m-%d'), f"{hr:02d}:{mn:02d}:00",
                get_timestamp(curr_date, hr, mn+random.randint(20,40), 0), None, tip, c_amt, u_amt, cd_amt
            ))
            
    curr_date += datetime.timedelta(days=1)

inv_ctr = 1
for g_id, final_stock in stock_ledger.items():
    inventory_stock_data.append((
        inv_ctr, g_id, round(final_stock, 2), "2026-07-30 23:59:59"
    ))
    inv_ctr += 1

def seed_database():
    try:
        conn = psycopg2.connect(DB_URL)
        cursor = conn.cursor()
        
        print("Executing Dimensional Data Insertion...")
        execute_values(cursor, "INSERT INTO branches (branch_id, name, address, phone, is_active, created_at) VALUES %s ON CONFLICT DO NOTHING", branches_data)
        execute_values(cursor, "INSERT INTO grocery_categories (grocery_category_id, name, description, is_active) VALUES %s ON CONFLICT DO NOTHING", grocery_categories_data)
        execute_values(cursor, "INSERT INTO expense_categories (expense_category_id, name, description, is_active) VALUES %s ON CONFLICT DO NOTHING", expense_categories_data)
        
        print("Executing Identity & Access Management (IAM) Data...")
        execute_values(cursor, "INSERT INTO employees (employee_id, first_name, last_name, email, phone, position, monthly_salary, join_date, is_active, branch_id, created_at, updated_at) VALUES %s ON CONFLICT DO NOTHING", employees_data)
        execute_values(cursor, "INSERT INTO users (user_id, username, email, password_hash, role, branch_id, is_active, created_at, updated_at) VALUES %s ON CONFLICT DO NOTHING", users_data)
        execute_values(cursor, "INSERT INTO salary_payments (salary_payment_id, employee_id, payment_month, payment_year, base_salary, bonus, deductions, net_salary, payment_date, payment_status, payment_mode, processed_by, branch_id, created_at) VALUES %s ON CONFLICT DO NOTHING", salary_payments_data)

        print("Executing Catalogs and Spatial Assets...")
        execute_values(cursor, "INSERT INTO restaurant_tables (table_id, capacity, status, branch_id, is_active) VALUES %s ON CONFLICT DO NOTHING", tables_data)
        execute_values(cursor, "INSERT INTO grocery_items (grocery_item_id, product_name, category_id, unit, is_active, created_at) VALUES %s ON CONFLICT DO NOTHING", grocery_items_data)
        
        print("Executing Culinary Master Data & Bill of Materials...")
        execute_values(cursor, "INSERT INTO menu_items (menu_item_id, name, description, category, price, is_vegetarian, is_available, image_url, branch_id, created_at, updated_at) VALUES %s ON CONFLICT DO NOTHING", menu_items_data)
        execute_values(cursor, "INSERT INTO recipe_ingredients (recipe_ingredient_id, menu_item_id, grocery_item_id, quantity_required, created_at) VALUES %s ON CONFLICT DO NOTHING", recipe_ingredients_data)
        
        print(f"Executing High-Velocity Transactions: {len(orders_data)} Orders...")
        execute_values(cursor, "INSERT INTO orders (order_id, table_id, status, created_by, branch_id, created_at, updated_at) VALUES %s ON CONFLICT DO NOTHING", orders_data)
        execute_values(cursor, "INSERT INTO order_items (order_item_id, order_id, menu_item_id, quantity, unit_price, total_price, notes, created_at) VALUES %s ON CONFLICT DO NOTHING", order_items_data)
        execute_values(cursor, "INSERT INTO bills (bill_id, order_id, table_id, subtotal, tax_amount, discount_amount, total_amount, payment_mode, payment_status, billed_by, branch_id, bill_date, bill_time, created_at, notes, tip_amount, cash_amount, upi_amount, card_amount) VALUES %s ON CONFLICT DO NOTHING", bills_data)
        
        print("Executing Financial Ledger Data (Procurement & Overheads)...")
        execute_values(cursor, "INSERT INTO grocery_purchases (grocery_purchase_id, purchase_date, purchase_time, grocery_item_id, quantity, unit_price, total_price, vendor_name, notes, recorded_by, branch_id, created_at) VALUES %s ON CONFLICT DO NOTHING", grocery_purchases_data)
        execute_values(cursor, "INSERT INTO expenses (expense_id, expense_date, expense_time, category_id, description, amount, payment_mode, vendor_name, receipt_number, notes, recorded_by, branch_id, created_at) VALUES %s ON CONFLICT DO NOTHING", expenses_data)
        
        print("Persisting Perpetual Inventory State...")
        execute_values(cursor, "INSERT INTO inventory_stock (inventory_id, grocery_item_id, current_stock, last_updated) VALUES %s ON CONFLICT DO NOTHING", inventory_stock_data)

        conn.commit()
        cursor.close()
        conn.close()
        print("Database seeding completed successfully. Referential integrity maintained.")
        
    except Exception as e:
        print(f"FATAL: Database error occurred: {e}")

if __name__ == "__main__":
    seed_database()
