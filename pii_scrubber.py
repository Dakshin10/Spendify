from presidio_analyzer import AnalyzerEngine, PatternRecognizer, Pattern
from presidio_anonymizer import AnonymizerEngine

analyzer = AnalyzerEngine()

imps_pattern = Pattern(name="imps_name", regex=r"(?<=IMPS-TRANSFER-\d{10}-)[A-Z\s]+", score=0.9)
custom_recognizer = PatternRecognizer(supported_entity="PERSON", patterns=[imps_pattern])
analyzer.registry.add_recognizer(custom_recognizer)


upi_pattern = Pattern(name="upi_pattern", regex=r"[\w.\-_]+@[a-zA-Z]+", score=0.95)
upi_recognizer = PatternRecognizer(supported_entity="UPI_ID", patterns=[upi_pattern])
analyzer.registry.add_recognizer(upi_recognizer)

account_pattern = Pattern(name="bank_account", regex=r"\b\d{14}\b", score=0.9)
account_recognizer = PatternRecognizer(supported_entity="BANK_ACCOUNT", patterns=[account_pattern])
analyzer.registry.add_recognizer(account_recognizer)

anonymizer = AnonymizerEngine()

def scrub_text(text: str) -> str:
    """
    Uses ML-based Named Entity Recognition (NER) to detect and redact PII.
    """
    if not text or not isinstance(text, str):
        return text
        
    # Analyze text for common PII (Names, Phones, Emails, Crypto, etc.)
    
    results = analyzer.analyze(
        text=text, 
        entities=["PERSON", "EMAIL_ADDRESS", "PHONE_NUMBER", "CRYPTO", "CREDIT_CARD","UPI_ID","BANK_ACCOUNT"], 
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
