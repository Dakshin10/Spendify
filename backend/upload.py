from fastapi import APIRouter, UploadFile, File, Form, HTTPException
import uuid
from datetime import datetime
from backend.csv_parser import parse_csv
from backend.pdf_parser import parse_pdf
from backend.pii_scrubber import clean_transactions
from backend.categorizer import categorize_transactions
from backend.database import get_db_connection, insert_transaction, calculate_confidence_score
from backend.services.fingerprint_service import generate_fingerprint
from backend.services.duplicate_detector import check_exact_duplicate, check_near_duplicates

router = APIRouter()

def detect_payment_mode_from_desc(desc: str) -> str:
    desc_lower = desc.lower()
    if "upi" in desc_lower:
        return "UPI"
    if "card" in desc_lower or "credit" in desc_lower or "debit card" in desc_lower:
        return "Card"
    if "netbanking" in desc_lower or "imps" in desc_lower or "neft" in desc_lower:
        return "Bank Transfer"
    return "Cash"

def get_timestamp_from_date(date_str: str) -> int:
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
        return int(dt.timestamp() * 1000)
    except Exception:
        return int(datetime.utcnow().timestamp() * 1000)

@router.post("/upload")
async def upload_statement(
    file: UploadFile = File(...), 
    bank_name: str = Form(...), 
    password: str = Form(None),
    existing_fingerprints: str = Form(None)
):
    try:
        if file.filename.endswith('.csv'):
            raw_txns = parse_csv(file.file, bank_name)
        elif file.filename.endswith('.pdf'):
            pdf_bytes = await file.read()
            raw_txns = parse_pdf(pdf_bytes, password, bank_name)
        else:
            raise HTTPException(status_code=400, detail="Unsupported file format. Please upload CSV or PDF.")

        if not raw_txns:
            return {
                "status": "success",
                "total_transactions": 0,
                "new_transactions": 0,
                "duplicates_skipped": 0,
                "data": []
            }

        # Parse existing fingerprints from frontend
        import json
        frontend_fingerprints = set()
        if existing_fingerprints:
            try:
                frontend_fingerprints = set(json.loads(existing_fingerprints))
            except Exception as json_err:
                print(f"[BACKEND WARNING] Failed to parse existing_fingerprints: {json_err}")

        # 1. Identify exact duplicates and filter new transactions
        new_txns = []
        restored_txns = []
        skipped_count = 0
        
        conn = get_db_connection()
        try:
            for txn in raw_txns:
                amount = float(txn["amount"])
                desc = txn.get("raw_description") or "Statement Transaction"
                txn_type = txn.get("transaction_type", "debit").lower()
                ref_id = txn.get("reference_id")
                
                fingerprint = generate_fingerprint(amount, txn["date"], desc, txn_type, ref_id)
                txn["fingerprint"] = fingerprint
                
                # Check if it exists in the frontend's local database
                if fingerprint in frontend_fingerprints:
                    skipped_count += 1
                else:
                    # Check if it exists in the backend DB (was already parsed)
                    cursor = conn.cursor()
                    cursor.execute("SELECT * FROM transactions WHERE fingerprint = ?", (fingerprint,))
                    row = cursor.fetchone()
                    if row:
                        db_txn = dict(row)
                        confidence = db_txn.get("confidence_score", 95)
                        formatted_txn = {
                            "id": db_txn["id"],
                            "amount": float(db_txn["amount"]),
                            "merchant": db_txn.get("merchant") or "Statement Transaction",
                            "type": db_txn["transaction_type"].lower(),
                            "transaction_type": db_txn["transaction_type"].lower(),
                            "paymentMode": detect_payment_mode_from_desc(db_txn.get("merchant", "")),
                            "bank": bank_name,
                            "sender": "CSV" if file.filename.endswith('.csv') else "PDF",
                            "confidence": confidence,
                            "timestamp": get_timestamp_from_date(db_txn["created_at"][:10]),
                            "message": db_txn.get("raw_description") or "",
                            "category": db_txn.get("category", "Other"),
                            "auto_added": db_txn.get("auto_added", 1),
                            "fingerprint": fingerprint
                        }
                        restored_txns.append(formatted_txn)
                    else:
                        new_txns.append(txn)
        finally:
            conn.close()
                
        # If all transactions are duplicates, return duplicate_upload status
        if not new_txns and not restored_txns:
            return {
                "status": "duplicate_upload",
                "message": "All transactions already imported.",
                "total_transactions": len(raw_txns),
                "new_transactions": 0,
                "duplicates_skipped": skipped_count,
                "near_duplicates_warned": 0,
                "near_duplicates": [],
                "data": []
            }

        # 1b. Near-duplicate detection on new transactions
        near_duplicate_warnings = []
        for txn in new_txns:
            amount = float(txn["amount"])
            desc = txn.get("raw_description") or "Statement Transaction"
            timestamp_ms = get_timestamp_from_date(txn["date"])
            near_matches = check_near_duplicates(amount, desc, timestamp_ms)
            if near_matches:
                near_duplicate_warnings.append({
                    "incoming": {
                        "description": desc,
                        "amount": amount,
                        "date": txn["date"],
                        "type": txn.get("transaction_type", "debit"),
                    },
                    "matches": near_matches
                })

        # 2. Apply Machine Learning PII Scrubbing on NEW transactions only
        safe_txns = clean_transactions(new_txns)

        # 3. AI Categorization via Llama-3 on NEW transactions only
        categorized_txns = categorize_transactions(safe_txns)

        # Insert categorized_txns into SQLite database
        conn = get_db_connection()
        inserted_txns = []
        
        try:
            for txn in categorized_txns:
                txn["source_type"] = "csv" if file.filename.endswith('.csv') else "pdf"
                txn["amount"] = float(txn["amount"])
                
                # Check for standard fields
                if not txn.get("transaction_type"):
                    txn["transaction_type"] = "debit"
                if not txn.get("bank_source"):
                    txn["bank_source"] = bank_name
                if not txn.get("reference_id"):
                    txn["reference_id"] = None
                
                # Statements uploaded are always auto-approved (auto_added = 1)
                txn["auto_added"] = 1
                    
                status, _ = insert_transaction(conn, txn)
                if status == "skipped":
                    skipped_count += 1
                else:
                    confidence = calculate_confidence_score(txn)
                    formatted_txn = {
                        "id": txn["transaction_id"],
                        "amount": float(txn["amount"]),
                        "merchant": txn.get("raw_description") or "Statement Transaction",
                        "type": txn["transaction_type"].lower(),
                        "transaction_type": txn["transaction_type"].lower(),
                        "paymentMode": detect_payment_mode_from_desc(txn.get("raw_description", "")),
                        "bank": bank_name,
                        "sender": "CSV" if file.filename.endswith('.csv') else "PDF",
                        "confidence": confidence,
                        "timestamp": get_timestamp_from_date(txn["date"]),
                        "message": txn.get("raw_description") or "",
                        "category": txn.get("category", "Other"),
                        "auto_added": 1,
                        "fingerprint": txn["fingerprint"]
                    }
                    inserted_txns.append(formatted_txn)
            conn.commit()
        except Exception as db_err:
            conn.rollback()
            raise HTTPException(status_code=500, detail=f"Database write failed: {db_err}")
        finally:
            conn.close()
        
        all_txns = restored_txns + inserted_txns
        return {
            "status": "success", 
            "total_transactions": len(raw_txns),
            "new_transactions": len(all_txns),
            "duplicates_skipped": skipped_count,
            "near_duplicates_warned": len(near_duplicate_warnings),
            "near_duplicates": near_duplicate_warnings,
            "data": all_txns
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sync-sms")
async def sync_sms(payload: dict):
    from backend.sms_parsers import parse_sms
    messages = payload.get("messages", [])
    auto_add_enabled = payload.get("auto_add_enabled", True)
    
    parsed_txns = []
    skipped_count = 0
    
    for msg in messages:
        sender = msg.get("sender", "Unknown")
        body = msg.get("body", "")
        timestamp = msg.get("timestamp", 0)
        
        parsed = parse_sms(body, sender)
        if parsed:
            temp_id = str(uuid.uuid4())
            parsed["transaction_id"] = temp_id
            
            if not parsed.get("date"):
                parsed["date"] = datetime.utcfromtimestamp(timestamp / 1000).strftime('%Y-%m-%d')
                
            parsed["raw_description"] = body
            parsed["source_type"] = "sms"
            parsed["created_at"] = datetime.utcfromtimestamp(timestamp / 1000).isoformat()
            
            # Generate fingerprint
            amount = float(parsed["amount"])
            txn_type = parsed.get("type") or parsed.get("transaction_type") or "debit"
            ref_id = parsed.get("reference_id")
            
            fingerprint = generate_fingerprint(amount, parsed["date"], body, txn_type, ref_id)
            parsed["fingerprint"] = fingerprint
            
            if check_exact_duplicate(fingerprint):
                skipped_count += 1
            else:
                parsed_txns.append(parsed)
            
    if not parsed_txns:
        return {
            "status": "success",
            "processed": len(messages),
            "inserted": 0,
            "skipped": skipped_count,
            "near_duplicates": [],
            "data": []
        }
        
    # 2. PII Scrubbing
    safe_txns = clean_transactions(parsed_txns)
    
    # 3. AI Categorization (Groq Llama-3)
    categorized_txns = categorize_transactions(safe_txns)
    
    # 4. SQLite Insertion & Deduplication
    conn = get_db_connection()
    inserted_txns = []
    near_duplicates = []
    
    try:
        for txn in categorized_txns:
            # Score confidence
            confidence = calculate_confidence_score(txn)
            
            # Filter low confidence
            if confidence < 40:
                skipped_count += 1
                continue
                
            # Mode processing:
            # Auto-Add = 1 if (Auto Mode is enabled AND score >= 70) else 0 (Manual Confirmation Required)
            if auto_add_enabled and confidence >= 70:
                auto_added = 1
            else:
                auto_added = 0
                
            txn["auto_added"] = auto_added
            
            # Map extra keys
            if not txn.get("transaction_type"):
                txn["transaction_type"] = "debit"
            if not txn.get("reference_id"):
                txn["reference_id"] = None
                
            status, details = insert_transaction(conn, txn)
            if status == "skipped":
                skipped_count += 1
            else:
                formatted_txn = {
                    "id": txn["transaction_id"],
                    "amount": float(txn["amount"]),
                    "merchant": txn["merchant"],
                    "type": txn["transaction_type"].lower(),
                    "transaction_type": txn["transaction_type"].lower(),
                    "paymentMode": txn.get("paymentMode") or detect_payment_mode_from_desc(txn["raw_description"]),
                    "bank": txn["bank_source"],
                    "sender": txn.get("sender") or "SMS",
                    "confidence": confidence,
                    "timestamp": get_timestamp_from_date(txn["date"]),
                    "message": txn["raw_description"],
                    "category": txn["category"],
                    "auto_added": auto_added
                }
                inserted_txns.append(formatted_txn)
                if status == "inserted_warning" and details:
                    near_duplicates.extend(details)

                    
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Database sync failed: {e}")
    finally:
        conn.close()
        
    return {
        "status": "success",
        "processed": len(messages),
        "inserted": len(inserted_txns),
        "skipped": skipped_count,
        "near_duplicates": near_duplicates,
        "data": inserted_txns
    }

@router.post("/approve-transaction")
async def approve_transaction(payload: dict):
    txn_id = payload.get("transaction_id")
    if not txn_id:
        raise HTTPException(status_code=400, detail="Missing transaction_id")
        
    conn = get_db_connection()
    try:
        conn.execute("UPDATE transactions SET auto_added = 1 WHERE id = ?", (txn_id,))
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Database update failed: {e}")
    finally:
        conn.close()
        
    return {"status": "success", "message": "Transaction approved"}

@router.post("/ignore-transaction")
async def ignore_transaction(payload: dict):
    txn_id = payload.get("transaction_id")
    if not txn_id:
        raise HTTPException(status_code=400, detail="Missing transaction_id")
        
    conn = get_db_connection()
    try:
        conn.execute("DELETE FROM transactions WHERE id = ?", (txn_id,))
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Database deletion failed: {e}")
    finally:
        conn.close()
        
    return {"status": "success", "message": "Transaction ignored"}

@router.post("/clear-transactions")
async def clear_backend_transactions():
    conn = get_db_connection()
    try:
        conn.execute("DELETE FROM transactions")
        conn.commit()
        print("[DATABASE SUCCESS] Cleared all transactions in backend DB.")
        return {"status": "success", "message": "All backend transactions cleared."}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to clear backend transactions: {e}")
    finally:
        conn.close()