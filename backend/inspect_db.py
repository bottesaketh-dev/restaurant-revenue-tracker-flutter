import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv(override=True)
DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)

def inspect_and_sync():
    with engine.connect() as conn:
        # Get all tables
        tables_query = text("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
        """)
        tables = [row[0] for row in conn.execute(tables_query).fetchall()]
        
        for table in tables:
            print(f"\n--- Table: {table} ---")
            try:
                # Get Primary Key column
                pk_query = text(f"""
                    SELECT a.attname
                    FROM   pg_index i
                    JOIN   pg_attribute a ON a.attrelid = i.indrelid
                                         AND a.attnum = ANY(i.indkey)
                    WHERE  i.indrelid = '{table}'::regclass
                    AND    i.indisprimary;
                """)
                pk_result = conn.execute(pk_query).fetchone()
                
                if pk_result:
                    pk = pk_result[0]
                    print(f"Primary Key: {pk}")
                    
                    # Check if column is a serial/sequence
                    seq_query = text(f"""
                        SELECT pg_get_serial_sequence('{table}', '{pk}')
                    """)
                    seq_result = conn.execute(seq_query).fetchone()
                    
                    if seq_result and seq_result[0]:
                        seq_name = seq_result[0]
                        print(f"Sequence: {seq_name}")
                        
                        # Sync sequence
                        sync_query = text(f"""
                            SELECT setval('{seq_name}', COALESCE((SELECT MAX({pk})+1 FROM {table}), 1), false);
                        """)
                        conn.execute(sync_query)
                        conn.commit()
                        print("Sequence successfully synced!")
                    else:
                        print("No sequence associated with this primary key.")
                else:
                    print("No primary key found.")
                
                # Fetch a few rows
                rows_query = text(f"SELECT * FROM {table} LIMIT 2;")
                rows = conn.execute(rows_query).fetchall()
                print("Sample Data:")
                for row in rows:
                    # Convert row tuple to dict-like string for easier reading
                    print(dict(row._mapping))
                    
            except Exception as e:
                conn.rollback()
                print(f"Error inspecting {table}: {e}")

if __name__ == "__main__":
    inspect_and_sync()
