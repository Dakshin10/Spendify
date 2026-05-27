import pdfplumber
import pikepdf
import io
import pandas as pd
import uuid

def parse_pdf(file_bytes, password, bank_name):
    decrypted_pdf = io.BytesIO()

    try:
        # pikepdf requires a string or bytes password, so fallback to empty string if None
        with pikepdf.open(io.BytesIO(file_bytes), password=password or "") as pdf:
            pdf.save(decrypted_pdf)
    except Exception as e:
        print(f"Failed to decrypt PDF: {e}")
        return [] 
        
    transactions = []
    
    with pdfplumber.open(decrypted_pdf) as pdf_reader:
        for page_num, page in enumerate(pdf_reader.pages):
            table = page.extract_table()
  
            if table is None or len(table) < 2:
                continue 
            
            headers = [str(h).lower().strip() if h else "" for h in table[0]]
            data_rows = table[1:]
            
            # Default fallback indices
            date_idx = 0
            desc_idx = 1
            debit_idx = 2
            credit_idx = 3
            
            # Dynamically map indices based on keywords in headers
            for i, h in enumerate(headers):
                if any(kw in h for kw in ["txn date", "transaction date", "value date"]):
                    # Keep value date or txn date if found, but prefer txn date
                    if "value" not in h or date_idx == 0:
                        date_idx = i
                elif h == "date":
                    date_idx = i
                elif any(kw in h for kw in ["description", "narration", "particulars", "remarks", "details"]):
                    desc_idx = i
                elif any(kw in h for kw in ["debit", "withdrawal", "dr", "withdraw"]):
                    debit_idx = i
                elif any(kw in h for kw in ["credit", "deposit", "cr"]):
                    credit_idx = i
            
            df = pd.DataFrame(data_rows)
            
            for index, row in df.iterrows():
                try:
                    if len(row) <= max(date_idx, desc_idx):
                        continue
                        
                    date_str = str(row.iloc[date_idx]).replace('\n', '').replace('\r', '').strip() if row.iloc[date_idx] else ""
                    if not date_str or date_str.lower() == "none" or date_str.lower() == "date":
                        continue
                        
                    txn_date = pd.to_datetime(date_str, errors='coerce')
                    
                    # Extract debit and credit values, replacing newlines and commas
                    debit_val = ""
                    if debit_idx < len(row) and row.iloc[debit_idx]:
                        debit_val = str(row.iloc[debit_idx]).replace('\n', '').replace('\r', '').replace(',', '').strip()
                        
                    credit_val = ""
                    if credit_idx < len(row) and row.iloc[credit_idx]:
                        credit_val = str(row.iloc[credit_idx]).replace('\n', '').replace('\r', '').replace(',', '').strip()
                    
                    # Remove currency symbols
                    for sym in ["rs", "rs.", "₹", "inr"]:
                        debit_val = debit_val.lower().replace(sym, "").strip()
                        credit_val = credit_val.lower().replace(sym, "").strip()
                        
                    debit = pd.to_numeric(debit_val, errors='coerce')
                    credit = pd.to_numeric(credit_val, errors='coerce')
                    
                    if pd.notna(debit) and debit > 0:
                        amount = float(debit)
                        txn_type = "debit"
                    elif pd.notna(credit) and credit > 0:
                        amount = float(credit)
                        txn_type = "credit"
                    else:
                        continue # Skip rows without valid amounts
                    
                    raw_desc = str(row.iloc[desc_idx]).replace('\n', ' ').replace('\r', ' ').strip() if row.iloc[desc_idx] else "Transaction"
                    
                    txn_record = {
                        "transaction_id": str(uuid.uuid4()),
                        "date": txn_date.strftime('%Y-%m-%d') if pd.notnull(txn_date) else "",
                        "amount": amount, 
                        "transaction_type": txn_type, 
                        "raw_description": raw_desc,
                        "bank_source": bank_name,
                        "source": "pdf"
                    }
                    transactions.append(txn_record)
                except Exception as row_error:
                    print(f"Error parsing PDF row: {row_error}")
                    continue
                    
    return transactions