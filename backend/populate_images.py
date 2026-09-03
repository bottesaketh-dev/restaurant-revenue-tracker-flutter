import os
import urllib.parse
from database import SessionLocal
import models

# Keyword mapping
IMAGE_MAPPING = {
    "chicken dum biryani": "chicken,biryani",
    "mutton dum biryani": "mutton,biryani",
    "veg dum biryani": "vegetable,biryani",
    "paneer biryani": "paneer,biryani",
    "egg biryani": "egg,biryani",
    "chicken 65": "fried,chicken",
    "chilli chicken": "spicy,chicken",
    "apollo fish": "fried,fish",
    "paneer": "paneer",
    "mutton marag": "mutton,soup",
    "rogan josh": "mutton,curry",
    "dum ka chicken": "chicken,curry",
    "dal makhani": "dal,curry",
    "roti": "roti,bread",
    "naan": "naan,bread",
    "meetha": "indian,dessert",
    "chai": "indian,tea",
    "biryani": "biryani",
}

DEFAULT_IMAGE = "food,restaurant"

db = SessionLocal()
try:
    items = db.query(models.MenuItem).all()
    updated_count = 0
    for i, item in enumerate(items):
        name_lower = item.name.lower()
        matched_kw = DEFAULT_IMAGE
        
        for kw, search_tag in IMAGE_MAPPING.items():
            if kw in name_lower:
                matched_kw = search_tag
                break
                
        # Generate a stable loremflickr URL using lock
        lock_id = item.menu_item_id
        item.image_url = f"https://loremflickr.com/600/400/{matched_kw}?lock={lock_id}"
        updated_count += 1
        
    db.commit()
    print(f"Successfully updated {updated_count} menu items with images.")
finally:
    db.close()
