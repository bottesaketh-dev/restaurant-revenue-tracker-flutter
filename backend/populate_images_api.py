import requests

IMAGE_MAPPING = {
    "chicken dum biryani": "https://images.unsplash.com/photo-1589302168068-964664d93cb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "mutton dum biryani": "https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "veg dum biryani": "https://images.unsplash.com/photo-1633383718081-22ac93e3db65?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "paneer biryani": "https://images.unsplash.com/photo-1596797038530-2c107229654b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "egg biryani": "https://images.unsplash.com/photo-1606491956689-2ea866880c84?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "chicken 65": "https://images.unsplash.com/photo-1610057099431-d73a1c9d2f2f?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "chilli chicken": "https://images.unsplash.com/photo-1610057099431-d73a1c9d2f2f?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "apollo fish": "https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "paneer": "https://images.unsplash.com/photo-1631452180519-c014fe946bc0?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "mutton marag": "https://images.unsplash.com/photo-1544025162-841f3e792fb1?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "rogan josh": "https://images.unsplash.com/photo-1544025162-841f3e792fb1?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "dum ka chicken": "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "dal makhani": "https://images.unsplash.com/photo-1546833999-b9f581a1996d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "roti": "https://images.unsplash.com/photo-1601050690597-df0568f70950?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "naan": "https://images.unsplash.com/photo-1601050690597-df0568f70950?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "meetha": "https://images.unsplash.com/photo-1551024601-bec78aea704b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "chai": "https://images.unsplash.com/photo-1576092768241-dec231879fc3?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    "biryani": "https://images.unsplash.com/photo-1589302168068-964664d93cb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
}

DEFAULT_IMAGE = "https://images.unsplash.com/photo-1504674900247-0877df9cc836?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"

# Assuming admin login to get token
login_data = {"email": "admin@hydrest.com", "password": "admin123"}
resp = requests.post("http://localhost:8000/api/v1/auth/login", json=login_data)
token = resp.json()["token"]
headers = {"Authorization": f"Bearer {token}"}

items = requests.get("http://localhost:8000/api/v1/menu/items", headers=headers).json()

updated = 0
for item in items:
    name_lower = item['name'].lower()
    matched_url = DEFAULT_IMAGE
    
    for kw, url in IMAGE_MAPPING.items():
        if kw in name_lower:
            matched_url = url
            break
            
    payload = {
        "name": item['name'],
        "description": item.get('description'),
        "category": item['category'],
        "price": item['price'],
        "is_vegetarian": item['is_vegetarian'],
        "is_available": item['is_available'],
        "image_url": matched_url
    }
    
    # We update it via API
    # the endpoint requires branch_id to be implicitly handled by token (admin handles all or specific)
    requests.put(f"http://localhost:8000/api/v1/menu/items/{item['menu_item_id']}", json=payload, headers=headers)
    updated += 1
    
print(f"Updated {updated} items via API!")
