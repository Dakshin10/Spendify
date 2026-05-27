import json
import os
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

client = Groq(api_key=os.environ.get("GROQ_API_KEY"))

def categorize_transactions(transactions: list) -> list:
    """Uses Llama-3 to assign one of 11 budget categories to a list of transactions."""
    if not transactions:
        return []

    # Prepare a lightweight version of the data for the prompt to save tokens
    prompt_data = [
        {"id": t['transaction_id'], "desc": t['raw_description'], "amount": t['amount']} 
        for t in transactions
    ]

    prompt = f"""
    You are a financial categorizer. Assign each transaction to ONE of these 11 categories:
    Food, Transport, Utilities, Entertainment, Shopping, Health, Education, Rent, Subscriptions, Income, Other.
    
    Return ONLY a valid JSON object with a 'results' array. Each item must have 'id' and 'category'.
    Transactions: {json.dumps(prompt_data)}
    """
    
    try:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.0,
            response_format={"type": "json_object"}
        )
        
        # Parse the JSON response
        result_content = json.loads(response.choices[0].message.content)
        categories_map = {item['id']: item['category'] for item in result_content.get('results', [])}
        
        # Merge the AI categories back into our main transaction list
        for txn in transactions:
            txn['category'] = categories_map.get(txn['transaction_id'], 'Other')
            
    except Exception as e:
        print(f"AI Categorization failed: {e}")
        for txn in transactions:
            txn['category'] = 'Other'
            
    return transactions