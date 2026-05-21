from presidio_analyzer import AnalyzerEngine
from presidio_anonymizer import AnonymizerEngine

# Initialize engines once at module load to prevent latency on every API call
analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()

def scrub_text(text: str) -> str:
    """
    Uses ML-based Named Entity Recognition (NER) to detect and redact PII.
    """
    if not text or not isinstance(text, str):
        return text
        
    # Analyze text for common PII (Names, Phones, Emails, Crypto, etc.)
    # Note: You can easily add custom pattern recognizers here for Indian PAN/Aadhaar later
    results = analyzer.analyze(
        text=text, 
        entities=["PERSON", "EMAIL_ADDRESS", "PHONE_NUMBER", "CRYPTO", "CREDIT_CARD"], 
        language='en'
    )
    
    # Replace detected entities with placeholders (e.g., <PERSON>, <PHONE_NUMBER>)
    anonymized_text = anonymizer.anonymize(text=text, analyzer_results=results)
    
    return anonymized_text.text

def clean_transactions(transactions: list) -> list:
    """
    Iterates through transactions and scrubs sensitive text fields.
    """
    scrubbed_transactions = []
    
    for txn in transactions:
        clean_txn = txn.copy()
        
        clean_txn['raw_description'] = scrub_text(clean_txn.get('raw_description', ''))
        clean_txn['merchant_name'] = scrub_text(clean_txn.get('merchant_name', ''))
        
        scrubbed_transactions.append(clean_txn)
        
    return scrubbed_transactions