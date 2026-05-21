import pdfplumber
import pikepdf
import io
import pandas as pd
import uuid

def parse_pdf(file_bytes, password, bank_name):
    decrypted_pdf = io.BytesIO()

    try:
        with pikepdf.open(io.BytesIO(file_bytes), password=password) as pdf:
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
            
            headers = table[0]
            data_rows = table[1:]
            df = pd.DataFrame(data_rows, columns=headers)
            
            for index, row in df.iterrows():
                try:
                    txn_date = pd.to_datetime(row.iloc[0], errors='coerce')
                    
                    txn_record = {
                        "transaction_id": str(uuid.uuid4()),
                        "date": txn_date.strftime('%Y-%m-%d') if pd.notnull(txn_date) else "",
                        "amount": 0.0, 
                        "transaction_type": "debit", 
                        "raw_description": str(row.iloc[1]).strip(),
                        "bank_source": bank_name,
                        "source": "pdf"
                    }
                    transactions.append(txn_record)
                except Exception as row_error:
                    continue
                    
    return transactions