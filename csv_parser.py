import pandas as pd
import uuid

def parse_csv(file_stream, bank_name):
    df = pd.read_csv(file_stream)
    df = df.fillna('')
    
    transactions = []
    
    for index, row in df.iterrows():
        debit_str = row.get('Debit', 0)
        credit_str = row.get('Credit', 0)
        
        debit = pd.to_numeric(debit_str, errors='coerce')
        credit = pd.to_numeric(credit_str, errors='coerce')

        if debit > 0:
            amount = debit
            txn_type = "debit"
        else:
            amount = credit
            txn_type = "credit"
            
        if pd.isna(amount) or amount == 0:
            continue
 
        raw_desc = str(row.get('Narration', '')).strip()
        
        txn_record = {
            "transaction_id": str(uuid.uuid4()),
            "date": pd.to_datetime(row.get('Date', '')).strftime('%Y-%m-%d'),
            "amount": float(amount),
            "transaction_type": txn_type,
            "raw_description": raw_desc,
            "bank_source": bank_name,
            "source": "csv"
        }
        transactions.append(txn_record)
        
    return transactions