import re
from datetime import datetime

def parse_date(date_str: str) -> str | None:
    for fmt in ('%d-%b-%Y', '%d-%b-%y', '%d/%m/%Y', '%d/%m/%y', '%Y-%m-%d'):
        try:
            return datetime.strptime(date_str, fmt).strftime('%Y-%m-%d')
        except ValueError:
            pass
    return None

def parse_icici(body: str, sender: str) -> dict | None:
    body_lower = body.lower()
    
    if "icici" not in body_lower and "icici" not in sender.lower():
        return None
        
    is_debit = any(k in body_lower for k in ['debited', 'spent', 'paid', 'charged', 'withdrawn', 'sent'])
    is_credit = any(k in body_lower for k in ['credited', 'received', 'deposited', 'refunded'])
    
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
    
    # Merchant Extraction
    merchant = "ICICI Transaction"
    if is_debit:
        # e.g., "for BigBasket order using Credit Card"
        m1 = re.search(r'for\s+([A-Za-z0-9\s&._*-]+?)\s+(?:order|using|using|at|\.|\n|$)', body, re.IGNORE_CASE)
        # e.g., "spent at Amazon using ICICI"
        m2 = re.search(r'spent\s+(?:at|on)\s+([A-Za-z0-9\s&._*-]+?)\s+(?:using|\.|\n|$)', body, re.IGNORE_CASE)
        # general fallback
        m3 = re.search(r'at\s+([A-Za-z0-9\s&._*-]+?)(?:\s+using|\.|\n|$)', body, re.IGNORE_CASE)
        
        for m in [m1, m2, m3]:
            if m:
                candidate = m.group(1).strip()
                if candidate and len(candidate) < 40 and not any(w in candidate.lower() for w in ['account', 'a/c', 'card', 'icici']):
                    merchant = candidate
                    break
    else:
        m_credit = re.search(r'for\s+([A-Za-z0-9\s&._*-]+?)(?:\s+on|\.|\n|$)', body, re.IGNORE_CASE)
        if m_credit:
            candidate = m_credit.group(1).strip()
            if candidate and len(candidate) < 40:
                merchant = candidate
        else:
            merchant = "Deposit / Salary"
            
    # Reference ID
    ref_id = None
    ref_match = re.search(r'(?:Ref|Txn|UPI|reference|ref\s*no)\.?\s*([A-Za-z0-9]+)', body, re.IGNORE_CASE)
    if ref_match:
        ref_id = ref_match.group(1).strip()
        
    # Account hint
    account_hint = None
    acc_match = re.search(r'(?:A/c|Acct|ending|card|account)\s*([X\d]+)', body, re.IGNORE_CASE)
    if acc_match:
        account_hint = acc_match.group(1).strip()
        account_hint = re.sub(r'[^X\d]', '', account_hint)
        if len(account_hint) > 4:
            account_hint = account_hint[-4:]
            
    # Date extraction
    txn_date = None
    date_match = re.search(r'(?:on|at)\s+(\d{1,2}-[A-Za-z]+-\d{4}|\d{1,2}-[A-Za-z]+-\d{2}|\d{1,2}/\d{1,2}/\d{2,4}|\d{1,2}-\d{1,2}-\d{2,4})', body, re.IGNORE_CASE)
    if date_match:
        txn_date = parse_date(date_match.group(1).strip())
        
    return {
        "amount": amount,
        "transaction_type": txn_type,
        "merchant": merchant,
        "bank_source": "ICICI Bank",
        "reference_id": ref_id,
        "account_hint": account_hint,
        "date": txn_date
    }
