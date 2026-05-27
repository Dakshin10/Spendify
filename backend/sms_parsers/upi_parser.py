import re
from datetime import datetime

def parse_date(date_str: str) -> str | None:
    for fmt in ('%d-%b-%Y', '%d-%b-%y', '%d/%m/%Y', '%d/%m/%y', '%Y-%m-%d'):
        try:
            return datetime.strptime(date_str, fmt).strftime('%Y-%m-%d')
        except ValueError:
            pass
    return None

def parse_upi(body: str, sender: str) -> dict | None:
    body_lower = body.lower()
    
    # Check if this matches a UPI app transaction
    is_upi_app = any(app in sender.lower() for app in ["gpay", "phonep", "paytm", "amazon", "cred", "mobikw"]) or "upi" in body_lower
    if not is_upi_app:
        return None
        
    is_debit = any(k in body_lower for k in ['spent', 'paid', 'sent', 'debited', 'transfer'])
    is_credit = any(k in body_lower for k in ['credited', 'received', 'added', 'refunded'])
    
    if not is_debit and not is_credit:
        return None
        
    # Amount Extraction
    amt_match = re.search(r'(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)', body, re.IGNORE_CASE)
    if not amt_match:
        return None
    try:
        amount = float(amt_match.group(1).replace(',', ''))
    except ValueError:
        return None
        
    txn_type = "DEBIT" if is_debit else "CREDIT"
    
    # Identify bank/app source
    app_source = "UPI"
    sender_upper = sender.upper()
    if "GPAY" in sender_upper:
        app_source = "Google Pay"
    elif "PHONEP" in sender_upper:
        app_source = "PhonePe"
    elif "PAYTM" in sender_upper:
        app_source = "Paytm"
    elif "CRED" in sender_upper:
        app_source = "CRED"
    elif "AMAZON" in sender_upper:
        app_source = "Amazon Pay"
        
    # Merchant Extraction
    merchant = f"{app_source} Transaction"
    if is_debit:
        # e.g., "Paid Rs 320 to Zomato via PhonePe"
        m1 = re.search(r'paid\s+(?:Rs\.?|INR|₹)?\s*[\d,.]+\s+to\s+([A-Za-z0-9\s&._*-]+?)\s+via', body, re.IGNORE_CASE)
        # e.g., "sent Rs 100 to Starbucks"
        m2 = re.search(r'sent\s+(?:Rs\.?|INR|₹)?\s*[\d,.]+\s+to\s+([A-Za-z0-9\s&._*-]+)', body, re.IGNORE_CASE)
        # e.g., "spent on Google Pay at Swiggy"
        m3 = re.search(r'at\s+([A-Za-z0-9\s&._*-]+?)(?:\s+via|\.|\n|$)', body, re.IGNORE_CASE)
        # fallback "to [Merchant]"
        m4 = re.search(r'to\s+([A-Za-z0-9\s&._*-]+?)(?:\s+from|\.|\n|$)', body, re.IGNORE_CASE)
        
        for m in [m1, m2, m3, m4]:
            if m:
                candidate = m.group(1).strip()
                if candidate and len(candidate) < 40 and not any(w in candidate.lower() for w in ['account', 'a/c', 'card', 'upi']):
                    merchant = candidate
                    break
    else:
        m_credit = re.search(r'received\s+from\s+([A-Za-z0-9\s&._*-]+?)(?:\s+via|\.|\n|$)', body, re.IGNORE_CASE)
        if m_credit:
            candidate = m_credit.group(1).strip()
            if candidate and len(candidate) < 40:
                merchant = candidate
        else:
            merchant = "UPI Credit / Refund"
            
    # Reference ID
    ref_id = None
    ref_match = re.search(r'(?:Ref|Txn|UPI|reference|ref\s*no)\.?\s*([A-Za-z0-9]+)', body, re.IGNORE_CASE)
    if ref_match:
        ref_id = ref_match.group(1).strip()
        
    # Account hint
    account_hint = None
    acc_match = re.search(r'(?:A/c|Acct|ending|no\.?)\s*([X\d]+)', body, re.IGNORE_CASE)
    if acc_match:
        account_hint = acc_match.group(1).strip()
        account_hint = re.sub(r'[^X\d]', '', account_hint)
        if len(account_hint) > 4:
            account_hint = account_hint[-4:]
            
    # Date extraction
    txn_date = None
    date_match = re.search(r'on\s+(\d{1,2}-[A-Za-z]+-\d{4}|\d{1,2}-[A-Za-z]+-\d{2}|\d{1,2}/\d{1,2}/\d{2,4})', body, re.IGNORE_CASE)
    if date_match:
        txn_date = parse_date(date_match.group(1).strip())
        
    return {
        "amount": amount,
        "transaction_type": txn_type,
        "merchant": merchant,
        "bank_source": app_source,
        "reference_id": ref_id,
        "account_hint": account_hint,
        "date": txn_date
    }
