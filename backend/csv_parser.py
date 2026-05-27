import pandas as pd
import numpy as np
import uuid
import logging

# Setup logger for parsing errors/warnings
logger = logging.getLogger("csv_parser")
logger.setLevel(logging.DEBUG)

def normalize_amount(val) -> float:
    """
    Sanitizes and converts a value to a float.
    Removes commas, whitespace, currency symbols, and handles NaN/empty.
    Returns float or None if invalid.
    """
    if pd.isna(val) or val == "":
        return None
    val_str = str(val).strip().lower()
    
    # Remove common currency symbols
    for sym in ["rs", "rs.", "₹", "inr"]:
        val_str = val_str.replace(sym, "")
        
    # Remove commas and clean whitespace
    val_str = val_str.replace(",", "").strip()
    
    if not val_str:
        return None
        
    # Use pd.to_numeric for conversion with errors='coerce'
    num = pd.to_numeric(val_str, errors='coerce')
    if pd.notna(num):
        return float(num)
    return None

def normalize_date(val) -> str:
    """
    Converts date values safely to YYYY-MM-DD format using pandas.
    Returns string or None if unparseable.
    """
    if pd.isna(val) or val == "":
        return None
    val_str = str(val).strip()
    if not val_str:
        return None
        
    try:
        # Parse using pandas to_datetime
        parsed_dt = pd.to_datetime(val_str, errors='coerce')
        if pd.notna(parsed_dt):
            return parsed_dt.strftime('%Y-%m-%d')
        return None
    except Exception as e:
        logger.warning(f"Error parsing date {val}: {e}")
        return None

def normalize_description(val) -> str:
    """
    Sanitizes raw narration/description text, removing excessive whitespace or Excel artifacts.
    """
    if pd.isna(val) or val == "":
        return "Statement Transaction"
    val_str = str(val).replace('\n', ' ').replace('\r', ' ').strip()
    # Replace multiple spaces with a single space
    val_str = " ".join(val_str.split())
    return val_str or "Statement Transaction"

def map_headers(columns):
    """
    Dynamically maps CSV columns to standard fields.
    Returns a dict of standard_field -> csv_column_name.
    """
    mapping = {
        "date": None,
        "description": None,
        "debit": None,
        "credit": None
    }
    
    cols_lower = [str(c).lower().strip() for c in columns]
    
    # 1. Map Date
    for i, col in enumerate(cols_lower):
        if any(kw in col for kw in ["txn date", "transaction date", "booking date", "post date"]):
            mapping["date"] = columns[i]
            break
    if not mapping["date"]:
        for i, col in enumerate(cols_lower):
            if "date" in col:
                mapping["date"] = columns[i]
                break
                
    # 2. Map Description
    for i, col in enumerate(cols_lower):
        if any(kw in col for kw in ["description", "narration", "particulars", "remarks", "memo", "details"]):
            mapping["description"] = columns[i]
            break
            
    # 3. Map Debit
    for i, col in enumerate(cols_lower):
        if any(kw in col for kw in ["debit amount", "withdrawal", "paid out", "debit"]):
            mapping["debit"] = columns[i]
            break
            
    # 4. Map Credit
    for i, col in enumerate(cols_lower):
        if any(kw in col for kw in ["credit amount", "deposit", "received", "credit"]):
            mapping["credit"] = columns[i]
            break
            
    return mapping

def parse_csv(file_stream, bank_name):
    # Read CSV
    try:
        df = pd.read_csv(file_stream)
    except Exception as e:
        logger.error(f"Failed to read CSV: {e}")
        return []
        
    # Map headers dynamically
    header_map = map_headers(df.columns)
    
    date_col = header_map["date"]
    desc_col = header_map["description"]
    debit_col = header_map["debit"]
    credit_col = header_map["credit"]
    
    # If we still lack critical columns (date and description), log error and return empty
    if not date_col or not desc_col:
        logger.error(f"Failed to map critical columns: date_col={date_col}, desc_col={desc_col}")
        # Try case-insensitive matching fallback for first two columns if missing
        if len(df.columns) >= 2:
            date_col = df.columns[0]
            desc_col = df.columns[1]
        else:
            return []
            
    transactions = []
    
    for index, row in df.iterrows():
        try:
            # 1. Parse date
            raw_date = row.get(date_col)
            normalized_date = normalize_date(raw_date)
            if not normalized_date:
                logger.warning(f"Row {index}: Skipped due to invalid date value: {raw_date}")
                continue
                
            # 2. Parse description
            raw_desc = row.get(desc_col)
            normalized_desc = normalize_description(raw_desc)
            
            # 3. Parse amounts
            raw_debit = row.get(debit_col) if debit_col else None
            raw_credit = row.get(credit_col) if credit_col else None
            
            debit_amt = normalize_amount(raw_debit)
            credit_amt = normalize_amount(raw_credit)
            
            # Determine transaction type and amount
            amount = 0.0
            txn_type = "debit"
            
            debit_valid = debit_amt is not None and debit_amt > 0
            credit_valid = credit_amt is not None and credit_amt > 0
            
            if debit_valid and credit_valid:
                amount = float(debit_amt)
                txn_type = "debit"
                logger.warning(f"Row {index}: Both debit ({debit_amt}) and credit ({credit_amt}) are valid. Defaulting to debit.")
            elif debit_valid:
                amount = float(debit_amt)
                txn_type = "debit"
            elif credit_valid:
                amount = float(credit_amt)
                txn_type = "credit"
            else:
                logger.warning(f"Row {index}: Skipped due to invalid amount values: debit={raw_debit}, credit={raw_credit}")
                continue
                
            txn_record = {
                "transaction_id": str(uuid.uuid4()),
                "date": normalized_date,
                "amount": amount,
                "transaction_type": txn_type,
                "raw_description": normalized_desc,
                "bank_source": bank_name,
                "source": "csv"
            }
            transactions.append(txn_record)
            
        except Exception as e:
            logger.error(f"Row {index}: Unexpected error during parsing: {e}")
            continue
            
    return transactions