from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from backend.csv_parser import parse_csv
from backend.pdf_parser import parse_pdf
from backend.pii_scrubber import clean_transactions
from backend.categorizer import categorize_transactions

router = APIRouter()

@router.post("/upload")
async def upload_statement(
    file: UploadFile = File(...), 
    bank_name: str = Form(...), 
    password: str = Form(None)
):
    try:
        if file.filename.endswith('.csv'):
            raw_txns = parse_csv(file.file, bank_name)
        elif file.filename.endswith('.pdf'):
            pdf_bytes = await file.read()
            raw_txns = parse_pdf(pdf_bytes, password, bank_name)
        else:
            raise HTTPException(status_code=400, detail="Unsupported file format. Please upload CSV or PDF.")

        # 2. Apply Machine Learning PII Scrubbing
        safe_txns = clean_transactions(raw_txns)

        # 3. AI Categorization via Llama-3
        categorized_txns = categorize_transactions(safe_txns)

        # TODO: Insert categorized_txns into SQLite database here
        
        return {
            "status": "success", 
            "transactions_processed": len(categorized_txns), 
            "data": categorized_txns
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))