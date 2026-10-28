"""
IOR 360 — Production-Grade Local SQLite Multi-Tenant Database Seeder
===================================================================
Seeds realistic, internally consistent operational and financial data for
3 independent Telangana restaurant organizations, 3 branches each (9 total),
with 10 employees per branch (90 total), comprehensive category catalogs,
branch-exclusive menus, inventory, procurement, expenses, payroll, and 3 months
of detailed orders and billing data (August 1, 2026 to October 31, 2026).
"""

import os
import sys
import sqlite3
import shutil
import datetime
import random
import argparse
from pathlib import Path
from decimal import Decimal

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# Ensure backend directory is in path
backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

import security

def get_db_path():
    db_path = backend_dir / "local.db"
    return db_path

# =============================================================================
# TELANGANA DEMO DATA DEFINITIONS
# =============================================================================

RESTAURANTS_DATA = [
    {
        "restaurant_id": 1,
        "name": "Deccan Spice Kitchen",
        "slug": "deccan-spice-kitchen",
        "contact_email": "info@deccanspicekitchen.example.com",
        "contact_phone": "+91 40 2311 8890",
        "currency_code": "INR",
        "currency_symbol": "₹",
        "tax_rate": 0.0500,
        "receipt_header": "Deccan Spice Kitchen - Flavours of Telangana\nGSTIN: 36AAACD1234F1Z5",
        "receipt_footer": "Thank you for dining with us! Visit again.",
        "is_active": 1,
        "branches": [
            {
                "branch_id": 1,
                "name": "Madhapur Flagship",
                "address": "Plot 45, Hitech City Main Road, Madhapur, Hyderabad, Telangana 500081",
                "phone": "+91 40 6622 1001"
            },
            {
                "branch_id": 2,
                "name": "Kukatpally Outlet",
                "address": "Road No. 1, KPHB Colony, Kukatpally, Hyderabad, Telangana 500072",
                "phone": "+91 40 6622 1002"
            },
            {
                "branch_id": 3,
                "name": "Warangal Heritage",
                "address": "Nakkalagutta Main Road, Hanamkonda, Warangal, Telangana 506001",
                "phone": "+91 870 245 1003"
            }
        ]
    },
    {
        "restaurant_id": 2,
        "name": "Mana Telangana Bhojanam",
        "slug": "mana-telangana-bhojanam",
        "contact_email": "namaste@manatelanganabhojanam.example.com",
        "contact_phone": "+91 40 2335 4410",
        "currency_code": "INR",
        "currency_symbol": "₹",
        "tax_rate": 0.0500,
        "receipt_header": "Mana Telangana Bhojanam - Authentic Telugu Ruchulu\nGSTIN: 36BBBMT5678K2Z1",
        "receipt_footer": "Malli Randi! Dhanyavadhamulu.",
        "is_active": 1,
        "branches": [
            {
                "branch_id": 4,
                "name": "Gachibowli Express",
                "address": "ISB Road, Financial District, Gachibowli, Hyderabad, Telangana 500032",
                "phone": "+91 40 6633 2001"
            },
            {
                "branch_id": 5,
                "name": "Secunderabad Central",
                "address": "MG Road, Paradise Circle, Secunderabad, Telangana 500003",
                "phone": "+91 40 6633 2002"
            },
            {
                "branch_id": 6,
                "name": "Karimnagar Grand",
                "address": "Collectorate Road, Mukarampura, Karimnagar, Telangana 505001",
                "phone": "+91 878 224 2003"
            }
        ]
    },
    {
        "restaurant_id": 3,
        "name": "Nizam's Urban Table",
        "slug": "nizams-urban-table",
        "contact_email": "hello@nizamsurbantable.example.com",
        "contact_phone": "+91 40 2355 9920",
        "currency_code": "INR",
        "currency_symbol": "₹",
        "tax_rate": 0.0500,
        "receipt_header": "Nizam's Urban Table - Contemporary Hyderabadi Fare\nGSTIN: 36CCCNU9012L3Z9",
        "receipt_footer": "Experience the Royal Heritage. Have a great day!",
        "is_active": 1,
        "branches": [
            {
                "branch_id": 7,
                "name": "Jubilee Hills Luxe",
                "address": "Road No. 36, Jubilee Hills, Hyderabad, Telangana 500033",
                "phone": "+91 40 6644 3001"
            },
            {
                "branch_id": 8,
                "name": "LB Nagar Square",
                "address": "Ring Road, Near Metro Station, LB Nagar, Hyderabad, Telangana 500074",
                "phone": "+91 40 6644 3002"
            },
            {
                "branch_id": 9,
                "name": "Nizamabad Royal",
                "address": "Khaleelwadi Commercial Area, Nizamabad, Telangana 503001",
                "phone": "+91 8462 231 3003"
            }
        ]
    }
]

EXPENSE_CATEGORIES_TEMPLATE = [
    ("Vegetables & Produce", "Fresh regional vegetables, greens, and fresh kitchen produce"),
    ("Meat & Poultry", "Fresh chicken, goat mutton, and eggs procurement"),
    ("Fish & Seafood", "Freshwater fish, prawns, and seasonal seafood"),
    ("Dairy Products", "Milk, curd, fresh butter, ghee, and malai paneer"),
    ("Rice & Grains", "Sona Masoori, Basmati, and regional grains"),
    ("Spices & Masalas", "Whole spices, red chilies, turmeric, and proprietary spice blends"),
    ("Cooking Oils & Ghee", "Refined sunflower oil, groundnut oil, and pure cow ghee"),
    ("LPG & Kitchen Fuel", "Commercial 19kg LPG cylinder refills and kitchen gas"),
    ("Electricity & Utilities", "Commercial power bills and generator backup fuel"),
    ("Water Supply & Sanitation", "Commercial municipal and RO purified water supply"),
    ("Cleaning & Hygiene", "Kitchen degreasers, dishwashing chemicals, housekeeping supplies"),
    ("Equipment Maintenance", "Tandoor, exhaust chimney, burner, and refrigerator servicing"),
    ("Rent & Premises", "Monthly branch premise lease and common area maintenance"),
    ("Packaging & Disposables", "Food-grade containers, carry bags, meal trays, foil rolls"),
    ("Staff Welfare & Meals", "Staff tea, staff dining provisions, uniforms, first aid"),
    ("Marketing & Promotions", "Local newspaper flyers, social media ads, festival banners"),
    ("Software & POS Terminal", "IOR 360 cloud subscription and card swipe terminal rental"),
    ("Licenses & Statutory", "FSSAI compliance, trade license renewals, GST professional fees")
]

GROCERY_CATEGORIES_TEMPLATE = [
    ("Fresh Vegetables", "Onions, tomatoes, potatoes, ginger, garlic, green chilies"),
    ("Leafy Greens & Herbs", "Gongura, curry leaves, coriander, mint, palak"),
    ("Rice & Millets", "Sona Masoori raw rice, aged Biryani Basmati, Jowar, Ragi"),
    ("Pulses & Dals", "Guntur Toor dal, Urad dal, Chana dal, Moong dal"),
    ("Whole & Ground Spices", "Guntur dry red chilies, turmeric, cumin, coriander, cloves, cardamom"),
    ("Cooking Oils & Fats", "Cold-pressed groundnut oil, sunflower oil, pure desi ghee"),
    ("Dairy & Cheeses", "Full-cream buffalo milk, fresh set curd, malai paneer"),
    ("Poultry & Eggs", "Farm broiler chicken, country chicken (natu kodi), eggs"),
    ("Mutton & Meats", "Fresh tender goat meat, mutton bones, kheema"),
    ("Fish & Seafood", "Korameenu (Murrel), Rohu fish, Godavari tiger prawns"),
    ("Condiments & Pickles", "Gongura pickle, avakaya mango pickle, tamarind pulp"),
    ("Flours & Batter Ingredients", "Maida, Besan, Rice flour, Idli rava"),
    ("Nuts & Dry Fruits", "Whole cashews, raisins, almonds, fried onions (birista)"),
    ("Bakery & Breads", "Pav, burger buns, kulcha breads, breadcrumbs"),
    ("Beverages & Syrups", "Assam tea dust, South Indian filter coffee powder, rose syrup"),
    ("Packaging Supplies", "Aluminium foil containers, meal boxes, paper napkins")
]

GROCERY_ITEMS_MASTER = [
    ("Sona Masoori Rice (Premium)", 3, "kg", 54.0),
    ("Aged Basmati Rice (Royal)", 3, "kg", 110.0),
    ("Guntur Toor Dal", 4, "kg", 165.0),
    ("Urad Dal (Gota)", 4, "kg", 140.0),
    ("Gongura Leaves (Fresh)", 2, "kg", 35.0),
    ("Curry Leaves", 2, "kg", 60.0),
    ("Guntur Red Dry Chilies", 5, "kg", 240.0),
    ("Telangana Garam Masala Blend", 5, "kg", 380.0),
    ("Biryani Spices Potli", 5, "kg", 520.0),
    ("Pure Desi Cow Ghee", 6, "liter", 650.0),
    ("Refined Sunflower Oil", 6, "liter", 125.0),
    ("Fresh Buffalo Milk", 7, "liter", 72.0),
    ("Fresh Malai Paneer", 7, "kg", 340.0),
    ("Farm Chicken (Curry Cut)", 8, "kg", 190.0),
    ("Natu Kodi (Country Chicken)", 8, "kg", 380.0),
    ("Fresh Goat Mutton (Curry Cut)", 9, "kg", 780.0),
    ("Farm Fresh Eggs (Crate 30)", 8, "packet", 180.0),
    ("Onions (Nasik Grade A)", 1, "kg", 38.0),
    ("Country Tomatoes", 1, "kg", 28.0),
    ("Ginger-Garlic Paste (Fresh)", 1, "kg", 120.0),
    ("Whole Cashew Nuts (W320)", 13, "kg", 750.0),
    ("Godavari Fresh Prawns", 10, "kg", 450.0),
    ("Tamarind (Pachadi Grade)", 11, "kg", 140.0),
    ("Idli Rawa / Rice Flour", 12, "kg", 45.0),
    ("Premium Tea Dust", 15, "kg", 280.0)
]

BRANCH_MENUS = {
    # ---------------- Deccan Spice Kitchen ----------------
    1: [ # Madhapur Flagship
        ("Natu Kodi Pulusu (Country Chicken)", "Rich spicy country chicken curry simmered in earthen pot", "Main Course", 399.00, False),
        ("Telangana Mutton Sukka", "Slow-roasted tender goat meat with crushed peppercorns and curry leaves", "Starters", 450.00, False),
        ("Hyderabadi Chicken Dum Biryani", "Fragrant long-grain basmati rice layered with marinated chicken & saffron", "Biryani", 340.00, False),
        ("Gongura Mamsam", "Traditional Telangana delicacy of succulent mutton slow-cooked with sour sorrel leaves", "Main Course", 460.00, False),
        ("Royyala Vepudu (Prawn Fry)", "Fresh Godavari prawns wok-tossed with shallots, garlic, and fiery green chilies", "Starters", 420.00, False),
        ("Bagara Rice with Dalcha", "Cumin-scented tempered basmati rice served with tangy lentil-mutton gravy", "Main Course", 280.00, False),
        ("Pappu Charu with Steamed Rice", "Authentic Telangana spiced dal soup paired with piping hot Sona Masoori rice", "Main Course", 199.00, True),
        ("Ghee Podi Dosa", "Crispy golden crepe smeared with homemade spiced lentil powder and pure desi ghee", "Tiffins", 140.00, True),
        ("Miriyala Paneer Vepudu", "Paneer cubes tossed in freshly crushed Tellicherry black pepper and curry leaves", "Starters", 290.00, True),
        ("Gutthi Vankaya Kura", "Tender baby brinjals stuffed with roasted peanut, sesame, and coconut masala", "Main Course", 240.00, True),
        ("Double Ka Meetha", "Fried bread steeped in saffron-cardamom rabri, topped with slivered almonds", "Desserts", 130.00, True),
        ("Irani Chai with Osmania Biscuits", "Strong milky brewed Hyderabadi tea served with sweet & salty tea biscuits", "Beverages", 50.00, True),
    ],
    2: [ # Kukatpally Outlet
        ("KPHB Kodi Kura (Homestyle Chicken)", "Telangana home-style chicken curry with roasted coriander and shallots", "Main Course", 320.00, False),
        ("Telangana Mutton Fry", "Pan-fried diced mutton seasoned with garlic, dry coconut, and red chilies", "Starters", 430.00, False),
        ("Special Chicken 65 Biryani", "Spicy boneless chicken 65 pieces layered over aromatic dum biryani rice", "Biryani", 320.00, False),
        ("Gongura Kodi Kura", "Tender chicken morsels cooked in tangy gongura paste and rustic spices", "Main Course", 340.00, False),
        ("Chepala Vepudu (Fish Fry)", "Crispy spiced freshwater fish steaks pan-seared with turmeric and curry leaf", "Starters", 350.00, False),
        ("Bhendi Peanut Fry", "Crispy diced okra tossed with crunchy roasted peanuts and mild spices", "Main Course", 180.00, True),
        ("Tomato Pappu with Ghee Rice", "Tangy tomato-infused toor dal tempered with mustard and dried red chilies", "Main Course", 190.00, True),
        ("Ghee Rava Dosa", "Crispy semolina crepe studded with chopped green chilies, ginger, and cashews", "Tiffins", 130.00, True),
        ("Paneer Butter Masala", "Cottage cheese cubes simmered in creamy tomato-cashew gravy with fenugreek", "Main Course", 270.00, True),
        ("Kaju Kothimeera Kodi", "Rich chicken curry enriched with ground cashew paste and fresh coriander", "Main Course", 360.00, False),
        ("Gulab Jamun with Ice Cream", "Warm khoya dumplings served with cold vanilla bean ice cream", "Desserts", 120.00, True),
        ("Fresh Lemon Soda", "Refreshing salted and sweetened sparkling fresh lime soda", "Beverages", 60.00, True),
    ],
    3: [ # Warangal Heritage
        ("Kakatiya Natu Kodi Biryani", "Warangal special spicy country chicken biryani cooked over firewood embers", "Biryani", 380.00, False),
        ("Warangal Mutton Chops", "Marinated ribs and chops charred with rustic Telangana spices", "Starters", 460.00, False),
        ("Pachi Pulusu with Steamed Rice", "Raw roasted tamarind-shallot-chili cold stew served with hot steamed rice", "Main Course", 180.00, True),
        ("Gongura Royyalu (Prawns)", "Juicy prawns braised in tangy red sorrel leaf paste with green chilies", "Main Course", 440.00, False),
        ("Boti Masala Fry", "Traditional lamb tripe seasoned with ginger, turmeric, and black pepper", "Starters", 320.00, False),
        ("Palak Pappu with Jowar Roti", "Tempered spinach lentil curry served with freshly roasted jowar flatbreads", "Main Course", 210.00, True),
        ("Dosa with Allam Pachadi", "Fermented rice crepe paired with sweet-and-spicy ginger-tamarind chutney", "Tiffins", 120.00, True),
        ("Kaju Paneer Curry", "Plump cashews and soft paneer simmered in a mildly spiced onion gravy", "Main Course", 290.00, True),
        ("Alugadda Masala Fry", "Baby potatoes roasted with coarse red chili-coriander podi", "Starters", 190.00, True),
        ("Semiyya Payasam", "Vermicelli pudding simmered in sweetened milk with ghee-roasted cashews", "Desserts", 110.00, True),
        ("Filter Coffee (South Indian)", "Traditional brass-decoction brewed coffee with frothy buffalo milk", "Beverages", 45.00, True),
    ],

    # ---------------- Mana Telangana Bhojanam ----------------
    4: [ # Gachibowli Express
        ("Telangana Bhojanam Thali (Full Meals)", "Unlimited royal thali: rice, sambar, rasam, 2 curries, gongura, curd, sweet", "Thali", 250.00, True),
        ("Potlam Biryani (Kheema & Chicken)", "Fragrant biryani wrapped in a paper-thin omelette parcel with spiced kheema", "Biryani", 380.00, False),
        ("Golichina Mamsam", "Traditional Telangana dry-pan mutton roast infused with garlic and crushed coriander", "Starters", 450.00, False),
        ("Gongura Mutton Curry", "Spicy mutton braised with red sorrel leaves and whole spices", "Main Course", 460.00, False),
        ("Natu Kodi Vepudu", "Country chicken dry-fried with shallots, green chilies, and black pepper", "Starters", 390.00, False),
        ("Miriyala Royyalu", "Prawns tossed with crushed black peppercorns and fried curry leaves", "Starters", 430.00, False),
        ("Dosakaya Pappu with Rice", "Yellow cucumber cooked with yellow lentils, cumin, and dry red chilies", "Main Course", 190.00, True),
        ("Jonnalu Rotte (Jowar Roti - 2 pcs)", "Gluten-free traditional sorghum flatbread baked on cast iron tawa", "Breads", 60.00, True),
        ("Gutti Vankaya Biryani", "Long grain basmati dum rice cooked with peanut-stuffed tender brinjals", "Biryani", 260.00, True),
        ("Bellam Jalebi (Pure Ghee)", "Crispy golden spirals soaked in unrefined jaggery syrup", "Desserts", 120.00, True),
        ("Majjiga (Spiced Buttermilk)", "Churned yogurt drink seasoned with ginger, green chilies, and curry leaves", "Beverages", 40.00, True),
    ],
    5: [ # Secunderabad Central
        ("Secunderabad Special Mutton Biryani", "Classic layered basmati dum biryani with marinated baby goat meat", "Biryani", 370.00, False),
        ("Chicken Fry Piece Biryani", "Flavorful bagara rice topped with spicy pan-fried chicken chunks", "Biryani", 310.00, False),
        ("Mutton Dalcha with Bagara Rice", "Lentil stew cooked with tender mutton bones, paired with spiced rice", "Main Course", 340.00, False),
        ("Kothimeera Kodi Vepudu", "Chicken dry roast tossed in fresh green coriander and green chili paste", "Starters", 330.00, False),
        ("Chepala Pulusu (Nellore Style)", "Tender river fish simmered in tangy tamarind and fenugreek seed sauce", "Main Course", 360.00, False),
        ("Methi Chaman Paneer", "Fresh fenugreek greens and paneer cubes cooked in a mild Kashmiri onion gravy", "Main Course", 280.00, True),
        ("Ghee Sambar Rice", "Short grain rice and toor dal simmered with vegetables, topped with pure ghee", "Main Course", 180.00, True),
        ("Masala Vada (4 pcs)", "Crunchy Bengal gram lentil fritters spiced with chopped onions and fennel", "Starters", 90.00, True),
        ("Pachi Mirchi Kodi", "Spicy chicken preparation with green chilies, yogurt, and aromatic herbs", "Main Course", 340.00, False),
        ("Qubani Ka Meetha with Custard", "Stewed Turkish dried apricots flavored with rosewater, served with custard", "Desserts", 140.00, True),
        ("Badam Milk (Hot / Chilled)", "Rich whole milk simmered with crushed almonds, cardamom, and saffron strands", "Beverages", 70.00, True),
    ],
    6: [ # Karimnagar Grand
        ("Karimnagar Mutton Curry", "Fiery countryside mutton gravy prepared with home-pounded chili powder", "Main Course", 440.00, False),
        ("Gongura Kodi Biryani", "Fragrant basmati rice layered with tangy gongura chicken masala", "Biryani", 330.00, False),
        ("Boti Fry (Country Style)", "Thoroughly cleansed goat tripe slow-roasted with black pepper and ginger", "Starters", 310.00, False),
        ("Endu Chepala Vepudu (Dry Fish)", "Sun-dried fish pan-fried with onions, garlic, and crushed red chilies", "Starters", 260.00, False),
        ("Munakkaya Mamsam (Drumstick Mutton)", "Tender drumsticks and mutton pieces stewed in rich onion-tomato sauce", "Main Course", 450.00, False),
        ("Pesara Dosa with Upma (MLA Pesarattu)", "Green gram crepe stuffed with savoury semolina upma, served with ginger dip", "Tiffins", 150.00, True),
        ("Chikkudukaya Vepudu", "Country broad beans sautéed with grated dry coconut and mild spices", "Main Course", 170.00, True),
        ("Tomato Charu with Annam", "Thin tangy spiced tomato broth poured over piping hot steamed rice", "Main Course", 150.00, True),
        ("Kaju Paneer Biryani", "Aromatic basmati rice layered with golden fried cashews and malai paneer", "Biryani", 280.00, True),
        ("Pootharekulu (Paper Sweet - 2 pcs)", "Rice paper roll layered with powdered jaggery, pure ghee, and dry fruits", "Desserts", 120.00, True),
        ("Nannari Sharbat", "Refreshing herbal sarsaparilla root cooler infused with fresh lime", "Beverages", 50.00, True),
    ],

    # ---------------- Nizam's Urban Table ----------------
    7: [ # Jubilee Hills Luxe
        ("Zafrani Mutton Dum Biryani", "Royal Hyderabadi mutton biryani infused with pure Kashmiri saffron and ghee", "Biryani", 460.00, False),
        ("Shikampuri Kebab (4 pcs)", "Mutton patties with a creamy hung curd, mint, and green chili filling", "Grills", 420.00, False),
        ("Pathar Ka Gosht", "Tender slivers of mutton seared on a red-hot granite slab with spices", "Grills", 480.00, False),
        ("Nizami Murgh Tikka", "Boneless chicken thighs marinated in cream, saffron, and aromatic spices", "Grills", 390.00, False),
        ("Dum Ka Murgh", "Chicken slow-cooked in a sealed clay pot with almond, cashew, and poppy seed paste", "Main Course", 410.00, False),
        ("Subz Hyderabadi Handi", "Assorted seasonal garden vegetables tossed in spinach and mint gravy", "Main Course", 290.00, True),
        ("Paneer Khurchan Tacos (Fusion)", "Shredded spiced paneer and bell peppers served in soft roomali mini tacos", "Fusion", 310.00, True),
        ("Bhatti Ka Paneer Tikka", "Thick cottage cheese cubes marinated in smoked tandoori spices and char-grilled", "Grills", 340.00, True),
        ("Garlic Butter Naan", "Tandoor-baked leavened flatbread brushed with roasted garlic and melted butter", "Breads", 80.00, True),
        ("Truffle Dal Makhani", "Black lentils slow-simmered for 24 hours, finished with butter and truffle oil", "Main Course", 320.00, True),
        ("Anjeer Halwa with Vanilla Mousse", "Warm Turkish fig pudding paired with airy vanilla mascarpone mousse", "Desserts", 180.00, True),
        ("Royal Rose Sharbat", "Chilled organic Damask rose cordial infused with sweet basil seeds", "Beverages", 90.00, True),
    ],
    8: [ # LB Nagar Square
        ("Nizam's Chicken Dum Biryani", "Signature aromatic basmati rice with tender spice-infused chicken cuts", "Biryani", 330.00, False),
        ("Tangdi Kebab (3 pcs)", "Plump chicken drumsticks marinated in spiced yogurt and grilled in tandoor", "Grills", 360.00, False),
        ("Mutton Rogan Josh", "Kashmiri-influenced slow-cooked lamb shanks with aromatic mace and saffron", "Main Course", 440.00, False),
        ("Murgh Malai Tikka", "Melt-in-mouth chicken tenders marinated in cardamom cream and cheese", "Grills", 380.00, False),
        ("Hyderabadi Haleem (Special)", "Slow-stewed wheat, lentils, and tender shredded meat with desi ghee", "Main Course", 350.00, False),
        ("Paneer Lababdar", "Cottage cheese simmered in spiced tomato gravy with grated paneer and cream", "Main Course", 290.00, True),
        ("Veg Seekh Kebab", "Minced vegetable and cottage cheese skewers grilled with tandoori spices", "Grills", 260.00, True),
        ("Butter Roti (2 pcs)", "Stone-ground whole wheat flatbread brushed with fresh butter", "Breads", 50.00, True),
        ("Jeera Rice with Dal Tadka", "Fragrant cumin-tempered basmati rice served with yellow garlic dal", "Main Course", 190.00, True),
        ("Shahi Tukda", "Crisp ghee-fried brioche steeped in saffron rabri and topped with silver leaf", "Desserts", 140.00, True),
        ("Mango Lassi (Alphonso)", "Chilled thick yogurt smoothie blended with Alphonso mango pulp", "Beverages", 80.00, True),
    ],
    9: [ # Nizamabad Royal
        ("Royal Nizamabad Mutton Biryani", "Traditional pot-dum biryani with tender baby goat meat and roasted spices", "Biryani", 390.00, False),
        ("Reshmi Murgh Kebab", "Silky smooth boneless chicken breast marinated with egg white, cream, and mace", "Grills", 350.00, False),
        ("Mutton Korma (Hyderabadi)", "Rich braised mutton curry enriched with fried onion and cashew paste", "Main Course", 430.00, False),
        ("Achari Chicken Tikka", "Chicken morsels marinated with pickling spices and char-grilled in tandoor", "Grills", 340.00, False),
        ("Tala Hua Gosht", "Crispy pan-fried boneless beef/mutton morsels with fried green chilies", "Starters", 390.00, False),
        ("Paneer Tikka Masala", "Char-grilled cottage cheese cubes simmered in zesty tandoori gravy", "Main Course", 290.00, True),
        ("Mushroom Pepper Roast", "Fresh button mushrooms wok-tossed with crushed black peppercorns and curry leaf", "Starters", 260.00, True),
        ("Laccha Paratha", "Flaky multi-layered whole wheat bread baked in clay tandoor", "Breads", 60.00, True),
        ("Sambar Rice Bowl", "Comforting bowl of vegetable sambar and rice with papad and pickle", "Main Course", 160.00, True),
        ("Matka Kulfi", "Traditional dense saffron and pistachio ice cream set in miniature earthen pots", "Desserts", 120.00, True),
        ("Pista Badam Milkshake", "Rich milk blended with pistachio and almond paste, served chilled", "Beverages", 85.00, True),
    ]
}

TELANGANA_NAMES = [
    ("Kavitha", "Reddy"), ("Suresh", "Rao"), ("Madhusudhan", "Chary"), ("Anil", "Kumar"),
    ("Rajesh", "Goud"), ("Venkatesh", "Mudhiraj"), ("Srikanth", "Yadav"), ("Prashanth", "Varma"),
    ("Swapna", "Rani"), ("Srinivas", "Sharma"), ("Mahesh", "Babu"), ("Santosh", "Nayudu"),
    ("Divya", "Teja"), ("Kishore", "Reddy"), ("Ramesh", "Kolluru"), ("Naresh", "Palle"),
    ("Sunil", "Dharavath"), ("Bhavani", "Prasad"), ("Ravinder", "Goud"), ("Kalyan", "Chowdary"),
    ("Harish", "Rao"), ("Praveen", "Kumar"), ("Manasa", "Vemula"), ("Padma", "Latha"),
    ("Sandhya", "Rani"), ("Karthik", "Sunkari"), ("Sai", "Charan"), ("Rohit", "Guptha"),
    ("Thirupathi", "Reddy"), ("Chandra", "Sekhar"), ("Shiva", "Shankar"), ("Naveen", "Goud"),
    ("Murali", "Krishna"), ("Sumanth", "Katta"), ("Vijay", "Kumar"), ("Laxman", "Rao")
]

EMPLOYEE_ROLES = [
    ("Branch Manager", 45000.00),
    ("Executive Chef", 38000.00),
    ("Sous Chef", 34000.00),
    ("Line Cook (Curry)", 22000.00),
    ("Line Cook (Tandoor/Tiffins)", 21000.00),
    ("Senior Waiter", 18000.00),
    ("Service Waiter", 16500.00),
    ("Cashier / Billing Exec", 20000.00),
    ("Kitchen Cleaner / Steward", 14500.00),
    ("Storekeeper / Inventory", 18500.00),
]

def generate_phone(branch_idx, emp_idx):
    return f"+91 98480 {branch_idx:02d}{emp_idx:03d}"

# =============================================================================
# MAIN SEEDING ENGINE
# =============================================================================

class IOR360Seeder:
    def __init__(self, db_path: Path, dry_run: bool = False):
        self.db_path = db_path
        self.dry_run = dry_run
        random.seed(42)  # Deterministic seed for reproducible data

    def run(self):
        print("=" * 80)
        print("IOR 360 LOCAL SQLITE MULTI-TENANT DATABASE SEEDER")
        print(f"Target Database: {self.db_path}")
        print(f"Mode: {'DRY RUN (No changes)' if self.dry_run else 'EXECUTE (Transactional reset & seed)'}")
        print("=" * 80)

        assert self.db_path.exists(), f"Database does not exist at {self.db_path}"

        # 1. Create safety backup
        backup_dir = self.db_path.parent / "backups"
        backup_dir.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = backup_dir / f"local_backup_pre_seed_{timestamp}.db"
        shutil.copy2(self.db_path, backup_path)
        print(f"✓ Safety backup verified at: {backup_path}")

        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()

        # Capture initial row counts
        table_names = [
            "restaurants", "branches", "grocery_categories", "expense_categories",
            "users", "grocery_items", "menu_items", "restaurant_tables", "employees",
            "inventory_stock", "recipe_ingredients", "orders", "order_items", "bills",
            "grocery_purchases", "expenses", "salary_payments"
        ]
        initial_counts = {}
        for t in table_names:
            initial_counts[t] = c.execute(f"SELECT COUNT(*) FROM \"{t}\"").fetchone()[0]

        if self.dry_run:
            print("\n[DRY RUN] Initial row counts:")
            for t, count in initial_counts.items():
                print(f"  {t}: {count} rows")
            conn.close()
            print("\n[DRY RUN] Complete. No modifications made.")
            return

        print("\nStarting Transactional Reset & Seeding...")
        try:
            # 2. Reset existing data in dependency-safe order
            print("Step 1: Clearing existing records in dependency-safe order...")
            delete_order = [
                "bills", "order_items", "orders", "salary_payments", "expenses",
                "grocery_purchases", "recipe_ingredients", "inventory_stock",
                "employees", "restaurant_tables", "menu_items", "grocery_items",
                "users", "expense_categories", "grocery_categories", "branches", "restaurants"
            ]
            for t in delete_order:
                c.execute(f"DELETE FROM \"{t}\"")
            
            # Reset autoincrement sequence
            c.execute("DELETE FROM sqlite_sequence")
            print("  ✓ All existing application records cleared and sequences reset.")

            # 3. Seed Restaurants
            print("\nStep 2: Seeding 3 Telangana Restaurant Organizations...")
            for r in RESTAURANTS_DATA:
                c.execute("""
                    INSERT INTO restaurants (
                        restaurant_id, name, slug, contact_email, contact_phone,
                        currency_code, currency_symbol, tax_rate, receipt_header,
                        receipt_footer, is_active, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, (
                    r["restaurant_id"], r["name"], r["slug"], r["contact_email"],
                    r["contact_phone"], r["currency_code"], r["currency_symbol"],
                    r["tax_rate"], r["receipt_header"], r["receipt_footer"], r["is_active"]
                ))
            print("  ✓ 3 Restaurants inserted.")

            # 4. Seed Branches
            print("Step 3: Seeding 9 Branches (3 per Restaurant)...")
            all_branches = []
            for r in RESTAURANTS_DATA:
                for b in r["branches"]:
                    c.execute("""
                        INSERT INTO branches (
                            branch_id, restaurant_id, name, address, phone, is_active, created_at
                        ) VALUES (?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP)
                    """, (b["branch_id"], r["restaurant_id"], b["name"], b["address"], b["phone"]))
                    all_branches.append((b["branch_id"], r["restaurant_id"], b["name"]))
            print(f"  ✓ {len(all_branches)} Branches inserted.")

            # 5. Seed Categories
            print("Step 4: Seeding Expense & Grocery Categories for all 3 Organizations...")
            exp_cat_map = {} # (restaurant_id, name) -> id
            groc_cat_map = {} # (restaurant_id, name) -> id
            exp_cat_id = 1
            groc_cat_id = 1

            for r in RESTAURANTS_DATA:
                r_id = r["restaurant_id"]
                for name, desc in EXPENSE_CATEGORIES_TEMPLATE:
                    c.execute("""
                        INSERT INTO expense_categories (
                            expense_category_id, restaurant_id, name, description, is_active
                        ) VALUES (?, ?, ?, ?, 1)
                    """, (exp_cat_id, r_id, name, desc))
                    exp_cat_map[(r_id, name)] = exp_cat_id
                    exp_cat_id += 1

                for name, desc in GROCERY_CATEGORIES_TEMPLATE:
                    c.execute("""
                        INSERT INTO grocery_categories (
                            grocery_category_id, restaurant_id, name, description, is_active
                        ) VALUES (?, ?, ?, ?, 1)
                    """, (groc_cat_id, r_id, name, desc))
                    groc_cat_map[(r_id, name)] = groc_cat_id
                    groc_cat_id += 1
            print(f"  ✓ {exp_cat_id - 1} Expense Categories and {groc_cat_id - 1} Grocery Categories inserted.")

            # 6. Seed Users
            print("Step 5: Seeding Multi-Tenant User Roles (Super Admin, Restaurant Admins, Managers, Cashiers, Staff)...")
            user_id = 1
            admin_hash = security.get_password_hash("admin123")
            pw_hash = security.get_password_hash("password123")

            # 1 Platform Super Admin
            c.execute("""
                INSERT INTO users (
                    user_id, username, email, password_hash, role, restaurant_id,
                    branch_id, is_active, access_level, allowed_tabs, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, NULL, NULL, 1, 'FULL', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """, (user_id, "super_admin", "superadmin@ior360.example.com", admin_hash, "SUPER_ADMIN"))
            user_id += 1

            # 3 Restaurant Admins
            r_admin_usernames = {
                1: "admin_deccan",
                2: "admin_mana",
                3: "admin_nizam"
            }
            for r in RESTAURANTS_DATA:
                r_id = r["restaurant_id"]
                u_name = r_admin_usernames[r_id]
                c.execute("""
                    INSERT INTO users (
                        user_id, username, email, password_hash, role, restaurant_id,
                        branch_id, is_active, access_level, allowed_tabs, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, NULL, 1, 'FULL', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, (user_id, u_name, f"{u_name}@ior360.example.com", admin_hash, "RESTAURANT_ADMIN", r_id))
                user_id += 1

            # Branch Managers, Cashiers & Staff
            branch_users = {} # branch_id -> {"manager": uid, "cashiers": [uid1, uid2], "staff": uid}
            for b_id, r_id, b_name in all_branches:
                b_slug = b_name.lower().split()[0]
                branch_users[b_id] = {"cashiers": []}

                # 1 Branch Manager
                mgr_uname = f"mgr_{b_slug}_{b_id}"
                c.execute("""
                    INSERT INTO users (
                        user_id, username, email, password_hash, role, restaurant_id,
                        branch_id, is_active, access_level, allowed_tabs, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 'FULL', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, (user_id, mgr_uname, f"{mgr_uname}@ior360.example.com", pw_hash, "BRANCH_MANAGER", r_id, b_id))
                branch_users[b_id]["manager"] = user_id
                user_id += 1

                # 2 Cashiers
                for c_idx in (1, 2):
                    csh_uname = f"csh_{b_slug}_{b_id}_{c_idx}"
                    c.execute("""
                        INSERT INTO users (
                            user_id, username, email, password_hash, role, restaurant_id,
                            branch_id, is_active, access_level, allowed_tabs, created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 'FULL', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """, (user_id, csh_uname, f"{csh_uname}@ior360.example.com", pw_hash, "CASHIER", r_id, b_id))
                    branch_users[b_id]["cashiers"].append(user_id)
                    user_id += 1

                # 1 Staff
                stf_uname = f"staff_{b_slug}_{b_id}"
                c.execute("""
                    INSERT INTO users (
                        user_id, username, email, password_hash, role, restaurant_id,
                        branch_id, is_active, access_level, allowed_tabs, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 'FULL', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, (user_id, stf_uname, f"{stf_uname}@ior360.example.com", pw_hash, "STAFF", r_id, b_id))
                branch_users[b_id]["staff"] = user_id
                user_id += 1

            print(f"  ✓ {user_id - 1} Authenticated User Accounts created with bcrypt hashing.")

            # 7. Seed Grocery Items
            print("Step 6: Seeding Master Grocery Ingredients Catalog...")
            grocery_items_by_rest = {} # r_id -> list of (item_id, name, unit, price)
            for r in RESTAURANTS_DATA:
                r_id = r["restaurant_id"]
                grocery_items_by_rest[r_id] = []
                for idx, (p_name, cat_offset, unit, def_price) in enumerate(GROCERY_ITEMS_MASTER, 1):
                    item_id = f"GROC-R{r_id}-{idx:03d}"
                    cat_id = (r_id - 1) * len(GROCERY_CATEGORIES_TEMPLATE) + cat_offset
                    c.execute("""
                        INSERT INTO grocery_items (
                            grocery_item_id, restaurant_id, product_name, category_id,
                            unit, is_active, created_at
                        ) VALUES (?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP)
                    """, (item_id, r_id, p_name, cat_id, unit))
                    grocery_items_by_rest[r_id].append((item_id, p_name, unit, def_price))
            print(f"  ✓ Master grocery catalog seeded ({len(GROCERY_ITEMS_MASTER) * 3} items total).")

            # 8. Seed Branch-Exclusive Menus
            print("Step 7: Seeding Branch-Exclusive Menu Catalog...")
            menu_item_id = 1
            branch_menu_items = {} # b_id -> list of (menu_item_id, name, price)
            for b_id, r_id, b_name in all_branches:
                branch_menu_items[b_id] = []
                menu_list = BRANCH_MENUS.get(b_id, BRANCH_MENUS[1])
                for m_name, m_desc, m_cat, m_price, is_veg in menu_list:
                    c.execute("""
                        INSERT INTO menu_items (
                            menu_item_id, restaurant_id, branch_id, name, description,
                            category, price, is_vegetarian, is_available, image_url,
                            created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """, (menu_item_id, r_id, b_id, m_name, m_desc, m_cat, m_price, 1 if is_veg else 0))
                    branch_menu_items[b_id].append((menu_item_id, m_name, m_price))
                    menu_item_id += 1
            print(f"  ✓ {menu_item_id - 1} Branch-Exclusive Menu Items seeded.")

            # 9. Seed Recipe Ingredients
            print("Step 8: Seeding Recipe Ingredient Links...")
            recipe_id = 1
            for b_id, r_id, _ in all_branches:
                groc_pool = grocery_items_by_rest[r_id]
                for m_id, m_name, _ in branch_menu_items[b_id]:
                    # Pick 2-3 grocery items to form recipe
                    sample_groceries = random.sample(groc_pool, 3)
                    for g_item_id, _, g_unit, _ in sample_groceries:
                        qty = 0.150 if g_unit == "kg" else (0.100 if g_unit == "liter" else 1.0)
                        c.execute("""
                            INSERT INTO recipe_ingredients (
                                recipe_ingredient_id, menu_item_id, grocery_item_id,
                                quantity_required, created_at
                            ) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
                        """, (recipe_id, m_id, g_item_id, qty))
                        recipe_id += 1
            print(f"  ✓ {recipe_id - 1} Recipe Ingredient links created.")

            # 10. Seed Restaurant Tables
            print("Step 9: Seeding Branch Dining Tables...")
            table_id_count = 0
            branch_tables = {} # b_id -> list of table_ids
            for b_id, r_id, _ in all_branches:
                branch_tables[b_id] = []
                for t_num in range(1, 11): # 10 tables per branch (T01 - T10)
                    t_id = f"BR{b_id}-T{t_num:02d}"
                    cap = 2 if t_num <= 3 else (4 if t_num <= 8 else 6)
                    c.execute("""
                        INSERT INTO restaurant_tables (
                            table_id, restaurant_id, branch_id, capacity, status, is_active
                        ) VALUES (?, ?, ?, ?, 'available', 1)
                    """, (t_id, r_id, b_id, cap))
                    branch_tables[b_id].append(t_id)
                    table_id_count += 1
            print(f"  ✓ {table_id_count} Tables seeded across 9 branches.")

            # 11. Seed Employees (Exactly 10 per Branch = 90 Total)
            print("Step 10: Seeding Exactly 10 Employees per Branch (90 Employees Total)...")
            emp_index = 1
            branch_employees = {} # b_id -> list of (emp_id, monthly_salary)
            for b_id, r_id, b_name in all_branches:
                branch_employees[b_id] = []
                for e_num, (pos, salary) in enumerate(EMPLOYEE_ROLES, 1):
                    first_name, last_name = TELANGANA_NAMES[(emp_index - 1) % len(TELANGANA_NAMES)]
                    emp_id = f"EMP-B{b_id:02d}-{e_num:02d}"
                    phone = generate_phone(b_id, e_num)
                    email = f"{first_name.lower()}.{last_name.lower()}{b_id}@ior360.example.com"
                    join_date = "2026-01-15"

                    c.execute("""
                        INSERT INTO employees (
                            employee_id, restaurant_id, branch_id, first_name, last_name,
                            email, phone, position, monthly_salary, join_date, is_active,
                            created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """, (emp_id, r_id, b_id, first_name, last_name, email, phone, pos, salary, join_date))
                    branch_employees[b_id].append((emp_id, salary))
                    emp_index += 1
            print(f"  ✓ Exactly {emp_index - 1} Employee records created.")

            # 12. Seed Salary Payments (August, September, October 2026 for all 90 Employees)
            print("Step 11: Seeding 3 Months of Payroll Records (Aug, Sep, Oct 2026)...")
            sal_pay_id = 1
            pay_months = [
                (8, 2026, "2026-08-31"),
                (9, 2026, "2026-09-30"),
                (10, 2026, "2026-10-31")
            ]
            for b_id, r_id, _ in all_branches:
                manager_uid = branch_users[b_id]["manager"]
                for emp_id, base_sal in branch_employees[b_id]:
                    for m, yr, p_date in pay_months:
                        bonus = 1000.00 if (m == 10 and "Chef" in emp_id) else 0.00
                        ded = 200.00 if random.random() < 0.2 else 0.00
                        net = float(base_sal) + bonus - ded

                        c.execute("""
                            INSERT INTO salary_payments (
                                salary_payment_id, restaurant_id, branch_id, employee_id,
                                payment_month, payment_year, base_salary, bonus, deductions,
                                net_salary, payment_date, payment_status, payment_mode,
                                processed_by, created_at
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PAID', 'BANK_TRANSFER', ?, CURRENT_TIMESTAMP)
                        """, (sal_pay_id, r_id, b_id, emp_id, m, yr, base_sal, bonus, ded, net, p_date, manager_uid))
                        sal_pay_id += 1
            print(f"  ✓ {sal_pay_id - 1} Salary Payment records seeded (90 employees x 3 months).")

            # 13. Seed Branch Inventory Stock
            print("Step 12: Seeding Initial Branch Inventory Stock...")
            inv_id = 1
            for b_id, r_id, _ in all_branches:
                groc_pool = grocery_items_by_rest[r_id]
                for g_id, _, _, _ in groc_pool:
                    stock_qty = round(random.uniform(25.0, 150.0), 3)
                    c.execute("""
                        INSERT INTO inventory_stock (
                            inventory_id, restaurant_id, branch_id, grocery_item_id,
                            current_stock, last_updated
                        ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                    """, (inv_id, r_id, b_id, g_id, stock_qty))
                    inv_id += 1
            print(f"  ✓ {inv_id - 1} Inventory Stock records initialized.")

            # 14. Seed Grocery Purchases (August - October 2026)
            print("Step 13: Seeding 3 Months of Grocery Purchases (COGS)...")
            groc_pur_id = 1
            vendors = [
                "Telangana Agro Supply Co.", "Guntur Spice Exporters", "Hyderabad Dairy Cooperative",
                "Kakatiya Wholesale Grains", "Deccan Fresh Farms", "Krishna Valley Poultry"
            ]
            start_date = datetime.date(2026, 8, 1)
            end_date = datetime.date(2026, 10, 31)
            delta_days = (end_date - start_date).days + 1

            for day_offset in range(delta_days):
                curr_date = start_date + datetime.timedelta(days=day_offset)
                date_str = curr_date.strftime("%Y-%m-%d")

                # Every 2-3 days per branch
                for b_id, r_id, _ in all_branches:
                    if (day_offset + b_id) % 3 == 0:
                        manager_uid = branch_users[b_id]["manager"]
                        sample_groceries = random.sample(grocery_items_by_rest[r_id], 2)
                        for g_id, _, unit, unit_price in sample_groceries:
                            qty = round(random.uniform(15.0, 50.0), 2) if unit in ("kg", "liter") else float(random.randint(5, 15))
                            tot_price = round(qty * unit_price, 2)
                            vendor = vendors[(b_id + day_offset) % len(vendors)]
                            p_time = f"{random.randint(8, 11):02d}:{random.randint(10, 55):02d}:00"

                            c.execute("""
                                INSERT INTO grocery_purchases (
                                    grocery_purchase_id, restaurant_id, branch_id,
                                    purchase_date, purchase_time, grocery_item_id,
                                    quantity, unit_price, total_price, vendor_name,
                                    notes, recorded_by, created_at
                                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                            """, (groc_pur_id, r_id, b_id, date_str, p_time, g_id, qty, unit_price, tot_price, vendor, "Regular stock replenishment", manager_uid))
                            groc_pur_id += 1
            print(f"  ✓ {groc_pur_id - 1} Grocery Purchases seeded across Aug, Sep, Oct 2026.")

            # 15. Seed Expenses (August - October 2026)
            print("Step 14: Seeding 3 Months of Operational Expenses (OPEX)...")
            expense_id = 1
            for b_id, r_id, b_name in all_branches:
                manager_uid = branch_users[b_id]["manager"]
                # Monthly Rent on 1st of Aug, Sep, Oct
                rent_amounts = {
                    1: 85000.0, 2: 65000.0, 3: 45000.0,
                    4: 90000.0, 5: 75000.0, 6: 40000.0,
                    7: 120000.0, 8: 60000.0, 9: 45000.0
                }
                rent_amt = rent_amounts.get(b_id, 60000.0)

                for m_idx, (m_num, m_yr, _) in enumerate(pay_months):
                    r_date = f"{m_yr}-{m_num:02d}-01"
                    c.execute("""
                        INSERT INTO expenses (
                            expense_id, restaurant_id, branch_id, expense_date, expense_time,
                            category_id, description, amount, payment_mode, vendor_name,
                            receipt_number, notes, recorded_by, created_at
                        ) VALUES (?, ?, ?, ?, '10:00:00', ?, ?, ?, 'BANK_TRANSFER', 'Commercial Realty Corp', ?, 'Monthly Branch Lease', ?, CURRENT_TIMESTAMP)
                    """, (expense_id, r_id, b_id, r_date, exp_cat_map[(r_id, "Rent & Premises")], f"Monthly Premise Rent - {b_name}", rent_amt, f"RENT-{m_yr}{m_num:02d}-B{b_id}", manager_uid))
                    expense_id += 1

                    # Electricity bill on 10th
                    e_date = f"{m_yr}-{m_num:02d}-10"
                    elec_amt = round(random.uniform(22000.0, 38000.0), 2)
                    c.execute("""
                        INSERT INTO expenses (
                            expense_id, restaurant_id, branch_id, expense_date, expense_time,
                            category_id, description, amount, payment_mode, vendor_name,
                            receipt_number, notes, recorded_by, created_at
                        ) VALUES (?, ?, ?, ?, '11:30:00', ?, ?, ?, 'ONLINE', 'TSSPDCL Commercial Power', ?, 'Monthly Electricity Bill', ?, CURRENT_TIMESTAMP)
                    """, (expense_id, r_id, b_id, e_date, exp_cat_map[(r_id, "Electricity & Utilities")], f"TSSPDCL Commercial Power - {b_name}", elec_amt, f"POW-{m_yr}{m_num:02d}-B{b_id}", manager_uid))
                    expense_id += 1

                    # LPG Gas cylinder refills on 15th
                    l_date = f"{m_yr}-{m_num:02d}-15"
                    lpg_amt = round(random.uniform(12000.0, 18000.0), 2)
                    c.execute("""
                        INSERT INTO expenses (
                            expense_id, restaurant_id, branch_id, expense_date, expense_time,
                            category_id, description, amount, payment_mode, vendor_name,
                            receipt_number, notes, recorded_by, created_at
                        ) VALUES (?, ?, ?, ?, '14:00:00', ?, ?, ?, 'UPI', 'Indane Commercial LPG Gas', ?, 'Commercial 19kg Gas Refills', ?, CURRENT_TIMESTAMP)
                    """, (expense_id, r_id, b_id, l_date, exp_cat_map[(r_id, "LPG & Kitchen Fuel")], f"Commercial LPG Cylinders - {b_name}", lpg_amt, f"LPG-{m_yr}{m_num:02d}-B{b_id}", manager_uid))
                    expense_id += 1

                    # Cleaning & Maintenance on 22nd
                    m_date = f"{m_yr}-{m_num:02d}-22"
                    maint_amt = round(random.uniform(6000.0, 14000.0), 2)
                    c.execute("""
                        INSERT INTO expenses (
                            expense_id, restaurant_id, branch_id, expense_date, expense_time,
                            category_id, description, amount, payment_mode, vendor_name,
                            receipt_number, notes, recorded_by, created_at
                        ) VALUES (?, ?, ?, ?, '16:00:00', ?, ?, ?, 'CARD', 'Deccan Facility Services', ?, 'Kitchen Chimney & Deep Clean', ?, CURRENT_TIMESTAMP)
                    """, (expense_id, r_id, b_id, m_date, exp_cat_map[(r_id, "Equipment Maintenance")], f"Kitchen Degreasing & Exhaust Servicing - {b_name}", maint_amt, f"MNT-{m_yr}{m_num:02d}-B{b_id}", manager_uid))
                    expense_id += 1
            print(f"  ✓ {expense_id - 1} Operational Expense records seeded.")

            # 16. Seed Orders, Order Items, and Bills (Daily Aug 1 - Oct 31, 2026)
            print("Step 15: Seeding 3 Months of Realistic Orders, Order Items, and Bills...")
            order_count = 0
            order_item_count = 0
            bill_count = 0

            # Pre-compute payment modes distribution: 55% UPI, 30% CARD, 15% CASH
            pay_modes = ["UPI"] * 11 + ["CARD"] * 6 + ["CASH"] * 3

            for day_offset in range(delta_days):
                curr_date = start_date + datetime.timedelta(days=day_offset)
                date_str = curr_date.strftime("%Y-%m-%d")
                is_weekend = curr_date.weekday() in (4, 5, 6) # Fri, Sat, Sun

                # Batch orders and items per day
                for b_id, r_id, _ in all_branches:
                    menu_pool = branch_menu_items[b_id]
                    table_pool = branch_tables[b_id]
                    cashier_uids = branch_users[b_id]["cashiers"]

                    # Base order volume: weekdays 10-14, weekends 16-22
                    base_volume = random.randint(16, 22) if is_weekend else random.randint(10, 14)
                    # Flagship branches (1, 4, 7) have slightly higher footfall
                    if b_id in (1, 4, 7):
                        base_volume += random.randint(2, 4)

                    for o_idx in range(base_volume):
                        order_count += 1
                        order_id = f"ORD-{curr_date.strftime('%Y%m%d')}-{b_id:02d}-{o_idx+1:04d}"
                        bill_id = f"BIL-{curr_date.strftime('%Y%m%d')}-{b_id:02d}-{o_idx+1:04d}"
                        table_id = random.choice(table_pool)
                        cashier_uid = random.choice(cashier_uids)

                        # Timing: Lunch (12:30 - 15:30) vs Dinner (19:00 - 22:30)
                        if random.random() < 0.45:
                            hour = random.randint(12, 15)
                            minute = random.randint(0, 59)
                        else:
                            hour = random.randint(19, 22)
                            minute = random.randint(0, 59)
                        
                        created_time_str = f"{hour:02d}:{minute:02d}:00"
                        created_timestamp = f"{date_str} {created_time_str}"

                        # Insert Order
                        c.execute("""
                            INSERT INTO orders (
                                order_id, restaurant_id, branch_id, table_id,
                                status, created_by, created_at, updated_at
                            ) VALUES (?, ?, ?, ?, 'COMPLETED', ?, ?, ?)
                        """, (order_id, r_id, b_id, table_id, cashier_uid, created_timestamp, created_timestamp))

                        # Select 2 to 4 items from branch menu
                        num_items = random.randint(2, 4)
                        chosen_items = random.sample(menu_pool, num_items)
                        subtotal = Decimal("0.00")

                        for m_id, m_name, m_price in chosen_items:
                            order_item_count += 1
                            qty = random.randint(1, 3)
                            price_dec = Decimal(str(m_price))
                            item_total = price_dec * Decimal(qty)
                            subtotal += item_total

                            c.execute("""
                                INSERT INTO order_items (
                                    order_item_id, restaurant_id, order_id, menu_item_id,
                                    quantity, unit_price, total_price, notes, created_at
                                ) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?)
                            """, (order_item_count, r_id, order_id, m_id, qty, float(price_dec), float(item_total), created_timestamp))

                        # Calculate Bill
                        tax_amount = round(subtotal * Decimal("0.0500"), 2)
                        discount_amount = Decimal("0.00")
                        if random.random() < 0.15: # 15% chance of promotional discount
                            discount_amount = round(subtotal * Decimal("0.05"), 2)
                        
                        tip_amount = Decimal("0.00")
                        if random.random() < 0.20: # 20% chance of tip
                            tip_amount = Decimal(random.choice([20.0, 50.0, 100.0]))

                        total_amount = subtotal + tax_amount - discount_amount + tip_amount

                        # Payment mode & amounts
                        pay_mode = random.choice(pay_modes)
                        cash_amt = float(total_amount) if pay_mode == "CASH" else 0.0
                        upi_amt = float(total_amount) if pay_mode == "UPI" else 0.0
                        card_amt = float(total_amount) if pay_mode == "CARD" else 0.0

                        bill_count += 1
                        c.execute("""
                            INSERT INTO bills (
                                bill_id, restaurant_id, branch_id, order_id, table_id,
                                subtotal, tax_amount, discount_amount, total_amount,
                                payment_mode, payment_status, billed_by, bill_date,
                                bill_time, created_at, notes, tip_amount, cash_amount,
                                upi_amount, card_amount
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PAID', ?, ?, ?, ?, NULL, ?, ?, ?, ?)
                        """, (
                            bill_id, r_id, b_id, order_id, table_id,
                            float(subtotal), float(tax_amount), float(discount_amount),
                            float(total_amount), pay_mode, cashier_uid, date_str,
                            created_time_str, created_timestamp, float(tip_amount),
                            cash_amt, upi_amt, card_amt
                        ))

            print(f"  ✓ Seeded {order_count:,} Orders, {order_item_count:,} Order Items, and {bill_count:,} Bills across 9 branches!")

            # Commit all changes atomically
            conn.commit()
            print("\n✓ Transaction committed successfully!")

        except Exception as e:
            conn.rollback()
            conn.close()
            print(f"\n[ERROR] Seeding failed with error: {e}")
            print(f"Restoring original database from backup: {backup_path}")
            shutil.copy2(backup_path, self.db_path)
            raise e

        # 17. Final Post-Seed Validation
        print("\nStep 16: Executing Post-Seed Integrity & Consistency Audits...")
        integrity = c.execute("PRAGMA integrity_check").fetchall()
        assert integrity and integrity[0][0] == "ok", f"Integrity check failed: {integrity}"
        print(f"  ✓ PRAGMA integrity_check: {integrity[0][0]}")

        fk_check = c.execute("PRAGMA foreign_key_check").fetchall()
        assert len(fk_check) == 0, f"Foreign key violations found: {fk_check}"
        print(f"  ✓ PRAGMA foreign_key_check: 0 violations")

        # Verify final row counts
        final_counts = {}
        for t in table_names:
            final_counts[t] = c.execute(f"SELECT COUNT(*) FROM \"{t}\"").fetchone()[0]

        print("\n" + "=" * 80)
        print("FINAL DATABASE ROW COUNTS:")
        print("=" * 80)
        for t in table_names:
            print(f"  {t:20s}: {final_counts[t]:>8,d} rows (was {initial_counts[t]:>8,d})")
        print("=" * 80)

        conn.close()
        print("\nDATABASE RESET AND DEMO DATA SEEDING COMPLETED SUCCESSFULLY!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="IOR 360 Local SQLite Database Seeder")
    parser.add_argument("--dry-run", action="store_true", help="Report planned changes without modifying database")
    args = parser.parse_args()

    db_file = get_db_path()
    seeder = IOR360Seeder(db_file, dry_run=args.dry_run)
    seeder.run()
