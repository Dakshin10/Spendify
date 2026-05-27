import re
import pandas as pd
from datetime import datetime

def normalize_amount(val) -> float:
    """
    Sanitizes and converts a value to a float.
    Removes commas, whitespace, currency symbols, and handles NaN/empty.
    Returns float (0.0 if invalid).
    """
    if pd.isna(val) or val == "":
        return 0.0
    val_str = str(val).strip().lower()
    
    # Remove common currency symbols
    for sym in ["rs", "rs.", "₹", "inr"]:
        val_str = val_str.replace(sym, "")
        
    # Remove commas and clean whitespace
    val_str = val_str.replace(",", "").strip()
    
    if not val_str:
        return 0.0
        
    num = pd.to_numeric(val_str, errors='coerce')
    if pd.notna(num):
        return float(num)
    return 0.0

def normalize_date(val) -> str:
    """
    Converts date values safely to YYYY-MM-DD format.
    Returns string or current date string if unparseable.
    """
    if pd.isna(val) or val == "":
        return datetime.utcnow().strftime('%Y-%m-%d')
    val_str = str(val).strip()
    if not val_str:
        return datetime.utcnow().strftime('%Y-%m-%d')
        
    try:
        parsed_dt = pd.to_datetime(val_str, errors='coerce')
        if pd.notna(parsed_dt):
            return parsed_dt.strftime('%Y-%m-%d')
    except Exception:
        pass
    return datetime.utcnow().strftime('%Y-%m-%d')

def normalize_merchant(val) -> str:
    """
    Sanitizes raw narration/description text, converting to lowercase, 
    trimming, and removing extra spaces, commas, and special formatting noise.
    """
    if pd.isna(val) or val == "":
        return "unknown"
    val_str = str(val).lower().strip()
    # Remove commas
    val_str = val_str.replace(",", "")
    # Remove extra spaces and Excel artifacts
    val_str = " ".join(val_str.split())
    # Keep only alphanumeric characters, dashes, and basic spaces to remove special noise
    val_str = re.sub(r'[^a-z0-9\s\-]', '', val_str)
    # Re-normalize spacing after cleaning characters
    val_str = " ".join(val_str.split())
    return val_str or "unknown"
