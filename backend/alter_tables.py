import os
import sys
from sqlalchemy import create_engine
from dotenv import load_dotenv

# Load environment variables
load_dotenv()
database_url = os.environ.get("DATABASE_URL")
if not database_url:
    print("DATABASE_URL not found in environment.")
    sys.exit(1)

# Ensure the dialect uses psycopg2
if database_url.startswith("postgres://"):
    database_url = database_url.replace("postgres://", "postgresql+psycopg2://", 1)
elif database_url.startswith("postgresql://"):
    database_url = database_url.replace("postgresql://", "postgresql+psycopg2://", 1)

print(f"Connecting to database: {database_url}")
engine = create_engine(database_url)

from models import Base
Base.metadata.create_all(bind=engine)
print("Tables created successfully!")
