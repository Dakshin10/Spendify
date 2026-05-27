import sqlite3
import os
import hashlib
import uuid
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(__file__), "spendify_backend.db")

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    # NOTE: Do NOT drop the table — that erases all data on every server restart
    # and breaks duplicate detection. Use CREATE TABLE IF NOT EXISTS for safe idempotent init.
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            fingerprint TEXT UNIQUE,
            amount REAL,
            merchant TEXT,
            category TEXT,
            transaction_type TEXT,
            bank_source TEXT,
            source_type TEXT,
            raw_description TEXT,
            reference_id TEXT,
            confidence_score INTEGER,
            auto_added INTEGER,
            created_at TEXT
        )
    ''')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_transactions_fingerprint ON transactions(fingerprint)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(created_at)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)')
    conn.commit()
    conn.close()

from backend.services.fingerprint_service import generate_fingerprint

def calculate_fingerprint(amount: float, merchant: str, date_str: str, txn_type: str, reference_id: str = None) -> str:
    """
    Delegates to fingerprint_service for unified normalization and hashing.
    """
    return generate_fingerprint(amount, date_str, merchant, txn_type, reference_id)

def calculate_confidence_score(txn: dict) -> int:
    """
    Calculates confidence score (0 to 100) based on transaction fields.
    - High Confidence: >= 70
    - Medium Confidence: 40 - 69
    - Low Confidence: < 40
    """
    score = 100
    
    desc = txn.get("raw_description", "").lower()
    merchant = txn.get("merchant", "").lower()
    amount = float(txn.get("amount", 0.0))
    ref_id = txn.get("reference_id")
    account_hint = txn.get("account_hint")
    
    # Deduct if no valid amount
    if not amount or amount <= 0:
        score -= 50
        
    # Deduct if unknown merchant
    if not merchant or "unknown" in merchant:
        score -= 30
        
    # Deduct if missing transaction references
    if not ref_id:
        score -= 15
    if not account_hint:
        score -= 15
        
    # Check for non-transactional triggers (OTP, promo)
    if any(w in desc for w in ["otp", "one-time", "one time", "verification"]):
        score -= 60
    if any(w in desc for w in ["cashback", "reward", "coupon", "voucher", "win", "discount"]):
        score -= 40
        
    return max(0, min(100, score))

def check_near_matches(conn, amount: float, date_str: str, txn_type: str, merchant: str) -> list:
    """
    Looks for transactions with same amount, date, and type, with word overlap in merchant name.
    """
    cursor = conn.cursor()
    cursor.execute(
        "SELECT id, merchant, created_at, amount, transaction_type FROM transactions WHERE amount = ? AND transaction_type = ?",
        (amount, txn_type)
    )
    rows = cursor.fetchall()
    near_matches = []
    
    new_words = set(merchant.lower().split())
    for row in rows:
        existing_words = set(row['merchant'].lower().split())
        if new_words.intersection(existing_words) or (row['merchant'].lower() in merchant.lower()) or (merchant.lower() in row['merchant'].lower()):
            near_matches.append({
                "id": row["id"],
                "merchant": row["merchant"],
                "date": row["created_at"][:10],
                "amount": row["amount"],
                "transaction_type": row["transaction_type"]
            })
            
    return near_matches

def insert_transaction(conn, txn: dict) -> tuple:
    """
    Inserts a transaction after running deduplication checks.
    Returns a tuple of (status, details):
      - ("inserted", None)
      - ("skipped", None)  -- exact duplicate (matching fingerprint)
      - ("inserted_warning", [near_matches]) -- inserted but near-match duplicate warning
    """
    amount = float(txn.get("amount", 0.0))
    merchant = txn.get("merchant", "Unknown")
    date_str = txn.get("date", "")
    txn_type = txn.get("transaction_type", "DEBIT").upper()
    ref_id = txn.get("reference_id")
    
    fingerprint = calculate_fingerprint(amount, merchant, date_str, txn_type, ref_id)
    
    cursor = conn.cursor()
    
    # 1. Exact Duplicate Check
    cursor.execute("SELECT id FROM transactions WHERE fingerprint = ?", (fingerprint,))
    existing = cursor.fetchone()
    if existing:
        print(f"[EXACT DUPLICATE SKIPPED] Fingerprint {fingerprint} already exists for merchant: {merchant}")
        return "skipped", None
        
    # 2. Near-Duplicate Check
    near_matches = check_near_matches(conn, amount, date_str, txn_type, merchant)
    if near_matches:
        print(f"[NEAR DUPLICATE DETECTED] Merchant: {merchant}, Amount: {amount}")
    
    # 3. Insertion
    txn_id = txn.get("id") or str(uuid.uuid4())
    created_at = txn.get("created_at") or datetime.utcnow().isoformat()
    
    # Calculate confidence score
    confidence_score = calculate_confidence_score(txn)
    auto_added = int(txn.get("auto_added", 1))
    
    cursor.execute('''
        INSERT OR IGNORE INTO transactions (
            id, fingerprint, amount, merchant, category, transaction_type, bank_source, 
            source_type, raw_description, reference_id, confidence_score, auto_added, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (
        txn_id,
        fingerprint,
        amount,
        merchant,
        txn.get("category", "Other"),
        txn_type,
        txn.get("bank_source", "Unknown"),
        txn.get("source_type", "manual"),
        txn.get("raw_description", ""),
        ref_id,
        confidence_score,
        auto_added,
        created_at
    ))
    
    print(f"[NEW TRANSACTION] Inserted successfully. ID: {txn_id}, Merchant: {merchant}, Amount: {amount}")
    
    if near_matches:
        return "inserted_warning", near_matches
        
    return "inserted", None
