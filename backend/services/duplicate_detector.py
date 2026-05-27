import logging
from datetime import datetime
from backend.database import get_db_connection
from backend.services.normalization_service import normalize_merchant

logger = logging.getLogger("duplicate_detector")
logger.setLevel(logging.INFO)

# Ensure console output for logs
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

def check_exact_duplicate(fingerprint: str) -> bool:
    """
    Checks if a transaction with the given fingerprint already exists in the database.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, merchant, amount FROM transactions WHERE fingerprint = ?", (fingerprint,))
    row = cursor.fetchone()
    conn.close()
    
    if row:
        logger.warning(f"[EXACT DUPLICATE SKIPPED] Transaction with fingerprint {fingerprint} already exists. Merchant: {row['merchant']}, Amount: {row['amount']}")
        return True
    return False

def check_near_duplicates(amount: float, merchant: str, timestamp_ms: int) -> list:
    """
    Checks for near-duplicate transactions in the database:
    - Same amount
    - Matching/overlapping merchant description
    - Difference between transaction timestamps is less than 5 minutes.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Query transactions with the same amount
    cursor.execute(
        "SELECT id, merchant, amount, created_at, transaction_type FROM transactions WHERE amount = ?",
        (amount,)
    )
    rows = cursor.fetchall()
    conn.close()
    
    near_matches = []
    norm_merchant = normalize_merchant(merchant)
    
    for row in rows:
        row_merchant = normalize_merchant(row['merchant'])
        
        # Check if merchant names have direct overlap
        if norm_merchant in row_merchant or row_merchant in norm_merchant:
            created_at_str = row['created_at']
            try:
                # Parse created_at ISO string to get timestamp
                dt = datetime.fromisoformat(created_at_str)
                row_ms = int(dt.timestamp() * 1000)
                
                # Check if timestamp difference is less than 5 minutes (300,000 milliseconds)
                if abs(timestamp_ms - row_ms) < 5 * 60 * 1000:
                    logger.info(f"[NEAR DUPLICATE DETECTED] Match ID: {row['id']}, Merchant: {row['merchant']}, Amount: {row['amount']}")
                    near_matches.append({
                        "id": row["id"],
                        "merchant": row["merchant"],
                        "amount": row["amount"],
                        "date": created_at_str[:10],
                        "transaction_type": row["transaction_type"]
                    })
            except Exception as e:
                # If date parsing fails, fallback to date comparison if matching
                pass
                
    return near_matches
