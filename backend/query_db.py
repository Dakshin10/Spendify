import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "spendify_backend.db")

def query_all():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT id, fingerprint, amount, merchant, created_at FROM transactions")
    rows = cursor.fetchall()
    print(f"Total transactions in backend DB: {len(rows)}")
    for row in rows[:10]:
        print(dict(row))
    conn.close()

if __name__ == "__main__":
    query_all()
