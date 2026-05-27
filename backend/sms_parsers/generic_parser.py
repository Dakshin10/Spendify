import re

def parse_generic(body: str, sender: str) -> dict | None:
    body_lower = body.lower()
    
    # 1. Check if it looks like a financial transaction
    is_debit = any(k in body_lower for k in ['spent', 'debited', 'charged', 'withdrawn', 'sent', 'paid', 'debit'])
    is_credit = any(k in body_lower for k in ['credited', 'received', 'deposited', 'added', 'credit', 'refunded'])
    
    if not is_debit and not is_credit:
        return None
        
    # 2. Extract Amount
    # Matches: Rs. 500, Rs 500.00, INR 250, ₹100, Rs.1,200.50
    amt_match = re.search(r'(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)', body, re.IGNORE_CASE)
    if not amt_match:
        return None
    try:
        amount = float(amt_match.group(1).replace(',', ''))
    except ValueError:
        return None
        
    # 3. Transaction Type
    txn_type = "DEBIT" if is_debit else "CREDIT"
    
    # 4. Extract Merchant
    merchant = "Unknown Merchant"
    # Try common patterns
    patterns = [
        r'(?:paid|sent)\s+to\s+([A-Za-z0-9\s&._*-]+?)(?:\s+from|\s+via|\s+ref|\.|\n|$)',
        r'spent\s+(?:at|on)\s+([A-Za-z0-9\s&._*-]+?)(?:\s+via|\s+from|\.|\n|$)',
        r'(?:at|to)\s+([A-Za-z0-9\s&._*-]+?)(?:\s+from|\s+using|\s+via|\s+on|\s+ref|\s+txn|\.|\n|$)'
    ]
    for pat in patterns:
        m = re.search(pat, body, re.IGNORE_CASE)
        if m:
            candidate = m.group(1).strip()
            # Clean up words like "your", "HDFC", etc.
            if candidate and len(candidate) < 40 and not any(w in candidate.lower() for w in ['account', 'a/c', 'card']):
                merchant = candidate
                break
                
    # 5. Extract Reference ID
    ref_id = None
    ref_match = re.search(r'(?:Ref|Txn|UPI|reference|ref\s*no)\.?\s*([A-Za-z0-9]+)', body, re.IGNORE_CASE)
    if ref_match:
        ref_id = ref_match.group(1).strip()
        
    # 6. Extract Account Hint
    account_hint = None
    acc_match = re.search(r'(?:A/c|Acct|account|ending|card)\s*(?:no\.?)?\s*([X\d]+)', body, re.IGNORE_CASE)
    if acc_match:
        account_hint = acc_match.group(1).strip()
        # Clean account hint to keep digits/X only
        account_hint = re.sub(r'[^X\d]', '', account_hint)
        if len(account_hint) > 8:
            account_hint = account_hint[-4:]
            
    # Normalize bank name from sender
    bank_source = "Bank"
    sender_upper = sender.upper()
    for bank in ["HDFC", "SBI", "ICICI", "AXIS", "KOTAK", "PNB", "BOB"]:
        if bank in sender_upper:
            bank_source = bank + " Bank" if bank != "SBI" else "SBI"
            break
            
    return {
        "amount": amount,
        "transaction_type": txn_type,
        "merchant": merchant,
        "bank_source": bank_source,
        "reference_id": ref_id,
        "account_hint": account_hint,
        "date": None # Caller defaults to message date/timestamp
    }
