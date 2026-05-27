from .hdfc_parser import parse_hdfc
from .sbi_parser import parse_sbi
from .icici_parser import parse_icici
from .upi_parser import parse_upi
from .generic_parser import parse_generic

def parse_sms(body: str, sender: str) -> dict | None:
    sender_upper = sender.upper()
    body_lower = body.lower()
    
    parsed = None
    
    # 1. Route based on Sender Header
    if "HDFC" in sender_upper:
        parsed = parse_hdfc(body, sender)
    elif "SBI" in sender_upper:
        parsed = parse_sbi(body, sender)
    elif "ICICI" in sender_upper:
        parsed = parse_icici(body, sender)
    elif any(app in sender_upper for app in ["GPAY", "PHONEP", "PAYTM", "AMAZON", "CRED"]):
        parsed = parse_upi(body, sender)
        
    # 2. Route based on body contents if Sender was generic (e.g. AD-123456)
    if not parsed:
        if "hdfc" in body_lower:
            parsed = parse_hdfc(body, sender)
        elif "sbi" in body_lower or "state bank" in body_lower:
            parsed = parse_sbi(body, sender)
        elif "icici" in body_lower:
            parsed = parse_icici(body, sender)
        elif "upi" in body_lower or any(app in body_lower for app in ["gpay", "phonepe", "paytm", "amazon pay", "cred"]):
            parsed = parse_upi(body, sender)
            
    # 3. Fallback to Generic Parser
    if not parsed:
        parsed = parse_generic(body, sender)
        
    return parsed
