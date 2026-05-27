import hashlib
from backend.services.normalization_service import normalize_amount, normalize_date, normalize_merchant

def generate_fingerprint(amount: float, date_str: str, merchant: str, transaction_type: str, reference_id: str = None) -> str:
    """
    Generates a unique SHA-256 fingerprint from transaction parameters.
    Ensures input parameters are normalized prior to hash calculation.
    """
    norm_amount = f"{normalize_amount(amount):.2f}"
    norm_date = normalize_date(date_str)
    norm_merchant = normalize_merchant(merchant)
    norm_type = str(transaction_type).strip().lower()
    norm_ref = str(reference_id).strip().lower() if reference_id else ""
    
    raw_str = f"{norm_amount}|{norm_date}|{norm_merchant}|{norm_type}"
    if norm_ref:
        raw_str += f"|{norm_ref}"
        
    return hashlib.sha256(raw_str.encode('utf-8')).hexdigest()
