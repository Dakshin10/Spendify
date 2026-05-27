import json
import os
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

client = None

def get_groq_client():
    global client
    if client is None:
        api_key = os.environ.get("GROQ_API_KEY")
        if api_key:
            try:
                client = Groq(api_key=api_key)
            except Exception as e:
                print(f"Error initializing Groq client: {e}")
    return client

def check_rule_based_category(desc: str) -> str:
    desc_lower = desc.lower()
    if any(w in desc_lower for w in ["salary", "payroll", "credited salary", "salary-tcs", "salary transfer"]):
        return "Income"
    return None

def categorize_transactions(transactions: list) -> list:
    """Uses Llama-3 to assign one of 11 budget categories to a list of transactions, checking rules first."""
    if not transactions:
        return []

    # 1. Apply rule-based overrides
    uncategorized = []
    for txn in transactions:
        rule_cat = check_rule_based_category(txn.get('raw_description', ''))
        if rule_cat:
            txn['category'] = rule_cat
        else:
            uncategorized.append(txn)

    # 2. Use AI for remaining uncategorized transactions
    if uncategorized:
        groq_client = get_groq_client()
        if not groq_client:
            print("Groq API key not set or initialization failed. Defaulting to 'Other'.")
            for txn in uncategorized:
                txn['category'] = 'Other'
            return transactions

        # Prepare a lightweight version of the data for the prompt to save tokens
        prompt_data = [
            {"id": t['transaction_id'], "desc": t['raw_description'], "amount": t['amount']} 
            for t in uncategorized
        ]

        prompt = f"""
        You are a financial categorizer. Assign each transaction to ONE of these 11 categories:
        Food, Transport, Utilities, Entertainment, Shopping, Health, Education, Rent, Subscriptions, Income, Other.
        
        Return ONLY a valid JSON object with a 'results' array. Each item must have 'id' and 'category'.
        Transactions: {json.dumps(prompt_data)}
        """
        
        try:
            response = groq_client.chat.completions.create(
                model="llama-3.3-70b-versatile",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.0,
                response_format={"type": "json_object"}
            )
            
            # Parse the JSON response
            result_content = json.loads(response.choices[0].message.content)
            categories_map = {item['id']: item['category'] for item in result_content.get('results', [])}
            
            # Merge the AI categories back into our main transaction list
            for txn in uncategorized:
                txn['category'] = categories_map.get(txn['transaction_id'], 'Other')
                
        except Exception as e:
            print(f"AI Categorization failed: {e}")
            for txn in uncategorized:
                txn['category'] = 'Other'
                
    return transactions